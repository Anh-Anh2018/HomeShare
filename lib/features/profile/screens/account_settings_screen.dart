import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import 'cccd_verification_screen.dart';

class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final shouldLogout = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Icon(
              Icons.logout_rounded,
              color: AppColors.danger,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'Đăng xuất khỏi tài khoản?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bạn sẽ cần đăng nhập lại để tiếp tục quản lý phòng hoặc liên hệ ở ghép.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Hủy',
                      style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Đăng xuất',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (shouldLogout == true) {
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
      if (context.mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    final isVerified = profile?.isCccdVerified == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt tài khoản'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Mục 1: TÀI KHOẢN & ĐỊNH DANH
          _buildSectionHeader('TÀI KHOẢN & ĐỊNH DANH'),
          _buildCardGroup([
            _buildSettingsItem(
              icon: Icons.person_outline,
              title: 'Thông tin cá nhân',
              subtitle: '${profile?.displayName ?? "Người dùng"} • Mã ID: ${profile?.userCode ?? "---"}',
              onTap: () {},
            ),
            _buildDivider(),
            _buildSettingsItem(
              icon: Icons.badge_outlined,
              title: 'Xác thực CCCD (eKYC)',
              subtitle: isVerified && profile?.cccdNumber.isNotEmpty == true
                  ? 'Số: ${profile!.cccdNumber.substring(0, 4)}****${profile.cccdNumber.substring(profile.cccdNumber.length - 2)}'
                  : 'Quét mã QR trên thẻ chip để định danh',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isVerified ? AppColors.primaryContainer : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                  border: isVerified ? null : Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Text(
                  isVerified ? 'Đã duyệt ✓' : 'Chưa xác thực >',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isVerified ? AppColors.primary : const Color(0xFFB45309),
                  ),
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CccdVerificationScreen(),
                  ),
                );
              },
            ),
          ]),

          const SizedBox(height: 20),

          // Mục 2: BẢO MẬT
          _buildSectionHeader('BẢO MẬT'),
          _buildCardGroup([
            _buildSettingsItem(
              icon: Icons.lock_outline,
              title: 'Đổi mật khẩu',
              onTap: () {},
            ),
            _buildDivider(),
            _buildSettingsItem(
              icon: Icons.security_outlined,
              title: 'Xác thực 2 bước (2FA)',
              onTap: () {},
            ),
          ]),

          const SizedBox(height: 20),

          // Mục 3: CÀI ĐẶT CHUNG & HỖ TRỢ
          _buildSectionHeader('CÀI ĐẶT CHUNG & HỖ TRỢ'),
          _buildCardGroup([
            _buildSettingsItem(
              icon: Icons.language_outlined,
              title: 'Ngôn ngữ',
              trailingText: 'Tiếng Việt',
              onTap: () {},
            ),
            _buildDivider(),
            _buildSettingsItem(
              icon: Icons.wb_sunny_outlined,
              title: 'Giao diện',
              trailingText: 'Sáng',
              onTap: () {},
            ),
            _buildDivider(),
            _buildSettingsItem(
              icon: Icons.help_outline,
              title: 'Trung tâm trợ giúp & FAQ',
              onTap: () {},
            ),
            _buildDivider(),
            _buildSettingsItem(
              icon: Icons.support_agent_outlined,
              title: 'Liên hệ hỗ trợ / Hotline',
              onTap: () {},
            ),
            _buildDivider(),
            _buildSettingsItem(
              icon: Icons.description_outlined,
              title: 'Điều khoản & Chính sách bảo mật',
              onTap: () {},
            ),
          ]),

          const SizedBox(height: 24),

          // Nút Đăng xuất theo Figma
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              onTap: () => _confirmLogout(context, ref),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.dangerContainer.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.danger,
                  size: 20,
                ),
              ),
              title: const Text(
                'Đăng xuất',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.danger,
                size: 20,
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Center(
            child: Text(
              'Phiên bản ứng dụng v3.8.2 • HomeShare',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildCardGroup(List<Widget> children) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 52,
      color: Color(0xFFF1F3F5),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    String? subtitle,
    String? trailingText,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: AppColors.textDark),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.textDark,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            )
          : null,
      trailing: trailing ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailingText != null)
                Text(
                  trailingText,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textMuted,
              ),
            ],
          ),
    );
  }
}
