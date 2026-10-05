import 'dart:convert';
import 'dart:io';
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
              onTap: () => _showProfileDetailsBottomSheet(context, profile),
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

  void _showProfileDetailsBottomSheet(BuildContext context, UserProfile? profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primaryContainer,
                backgroundImage: (profile?.avatarUrl.isNotEmpty == true)
                    ? NetworkImage(profile!.avatarUrl)
                    : null,
                child: (profile?.avatarUrl.isNotEmpty == true)
                    ? null
                    : Text(
                        (profile?.displayName.isNotEmpty == true)
                            ? profile!.displayName[0].toUpperCase()
                            : 'HS',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                profile?.displayName ?? 'Người dùng HomeShare',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  'Mã ID: ${profile?.userCode ?? "---"}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D4ED8),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 16),
              _buildProfileDetailRow(Icons.badge_outlined, 'Họ và tên', profile?.displayName ?? 'Chưa cập nhật'),
              _buildProfileDetailRow(Icons.email_outlined, 'Email', profile?.email ?? 'Chưa cập nhật'),
              _buildProfileDetailRow(Icons.phone_outlined, 'Số điện thoại', profile?.phoneNumber.isNotEmpty == true ? profile!.phoneNumber : 'Chưa cập nhật'),
              _buildProfileDetailRow(Icons.assignment_ind_outlined, 'Vai trò', (profile?.role == 'landlord' || profile?.role == 'chutro') ? 'Chủ trọ' : 'Người thuê phòng'),
              _buildProfileDetailRow(Icons.work_outline, 'Nghề nghiệp', profile?.occupation.isNotEmpty == true ? profile!.occupation : 'Sinh viên / Đã đi làm'),

              if (profile?.isCccdVerified == true) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                _buildProfileDetailRow(
                  Icons.verified,
                  'Số CCCD định danh',
                  profile!.cccdNumber.isNotEmpty
                      ? '${profile.cccdNumber.substring(0, 4)} **** ${profile.cccdNumber.substring(profile.cccdNumber.length - 4)}'
                      : 'Đã xác thực',
                ),
                if (profile.cccdFullName.isNotEmpty)
                  _buildProfileDetailRow(Icons.badge, 'Tên trên CCCD', profile.cccdFullName),
                if (profile.birthDate != null)
                  _buildProfileDetailRow(
                    Icons.cake_outlined,
                    'Ngày sinh (CCCD)',
                    '${profile.birthDate!.day.toString().padLeft(2, '0')}/${profile.birthDate!.month.toString().padLeft(2, '0')}/${profile.birthDate!.year}',
                  ),
                _buildProfileDetailRow(Icons.transgender, 'Giới tính', profile.gender),
                if (profile.cccdHometown.isNotEmpty || profile.hometown.isNotEmpty)
                  _buildProfileDetailRow(
                    Icons.home_outlined,
                    'Quê quán / Thường trú',
                    profile.cccdHometown.isNotEmpty ? profile.cccdHometown : profile.hometown,
                  ),
                _buildProfileDetailRow(Icons.check_circle_outline, 'Trạng thái eKYC', 'Đã lưu & đồng bộ Cloud ✓'),

                if (profile.cccdFrontImageUrl.isNotEmpty || profile.cccdBackImageUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.photo_library, color: AppColors.primary, size: 18),
                    label: const Text(
                      'Xem ảnh thẻ CCCD 2 mặt (Firebase Cloud)',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () => _showCccdImagesDialog(context, profile),
                  ),
                ],
              ] else
                _buildProfileDetailRow(Icons.verified_user_outlined, 'Định danh CCCD', 'Chưa định danh (eKYC)'),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Đóng', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showCccdImagesDialog(BuildContext context, UserProfile profile) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.verified, color: AppColors.primary, size: 22),
                        SizedBox(width: 8),
                        Text('Ảnh Thẻ CCCD Trên Cloud', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Mặt trước CCCD:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 140,
                    color: Colors.grey.shade100,
                    child: profile.cccdFrontImageUrl.isNotEmpty
                        ? _buildImageWidget(profile.cccdFrontImageUrl)
                        : const Center(child: Text('Chưa có ảnh mặt trước')),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Mặt sau CCCD:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 140,
                    color: Colors.grey.shade100,
                    child: profile.cccdBackImageUrl.isNotEmpty
                        ? _buildImageWidget(profile.cccdBackImageUrl)
                        : const Center(child: Text('Chưa có ảnh mặt sau')),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Đóng'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageWidget(String imageUrl) {
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
        ),
      );
    } else if (imageUrl.startsWith('data:image')) {
      try {
        final base64Data = imageUrl.split(',').last;
        return Image.memory(base64Decode(base64Data), fit: BoxFit.contain);
      } catch (_) {}
    } else if (File(imageUrl).existsSync()) {
      return Image.file(File(imageUrl), fit: BoxFit.contain);
    }
    return const Center(child: Icon(Icons.image_not_supported, color: Colors.grey, size: 40));
  }

  Widget _buildProfileDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
