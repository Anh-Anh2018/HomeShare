import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/user_provider.dart';
import '../../profile/screens/account_settings_screen.dart';
import '../../profile/screens/cccd_verification_screen.dart';
import '../../renter/screens/renter_bookings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trang cá nhân'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Cài đặt tài khoản',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AccountSettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // 1. Profile Header Card: Nhấn vào Avatar, Tên hoặc toàn bộ phần có Avatar để chuyển qua màn hình chi tiết
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AccountSettingsScreen(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: AppColors.primaryContainer,
                        backgroundImage: (profile?.avatarUrl.isNotEmpty == true)
                            ? NetworkImage(profile!.avatarUrl)
                            : null,
                        child: (profile?.avatarUrl.isNotEmpty == true)
                            ? null
                            : Text(
                                (profile?.displayName.isNotEmpty ?? false)
                                    ? profile!.displayName[0].toUpperCase()
                                    : 'HS',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    profile?.displayName ?? 'Người dùng HomeShare',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    (profile?.role == 'landlord' || profile?.role == 'chutro')
                                        ? 'Chủ trọ'
                                        : 'Người tìm phòng',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Text(
                                    'ID: ${profile?.userCode ?? "---"}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    profile?.email ?? 'user@homeshare.vn',
                                    style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (profile?.isCccdVerified == true)
                              Row(
                                children: [
                                  const Icon(Icons.verified, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      profile?.cccdNumber.isNotEmpty == true
                                          ? 'Đã xác thực CCCD (${profile!.cccdNumber.substring(0, 4)}****${profile.cccdNumber.substring(profile.cccdNumber.length - 2)}) ✓'
                                          : 'Đã xác thực CCCD (eKYC) ✓',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const CccdVerificationScreen(),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFF59E0B)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFD97706)),
                                      SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'Chưa xác thực CCCD (Quét ngay)',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFB45309),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 2),
                                      Icon(Icons.chevron_right, size: 13, color: Color(0xFFB45309)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Thống kê nhanh
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
                child: Row(
                  children: [
                    _buildStatItem('08', 'Phòng đã lưu'),
                    _buildVerticalDivider(),
                    _buildStatItem('02', 'Lịch hẹn'),
                    _buildVerticalDivider(),
                    _buildStatItem('01', 'Đang thuê'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Quản lý & Tiện ích
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'QUẢN LÝ & TIỆN ÍCH',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildMenuRow(
                    icon: Icons.calendar_month_outlined,
                    title: 'Lịch xem phòng & Đơn thuê',
                    subtitle: 'Theo dõi yêu cầu xem phòng của bạn',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RenterBookingsScreen()),
                      );
                    },
                  ),
                  _buildMenuDivider(),
                  _buildMenuRow(
                    icon: Icons.favorite_border,
                    title: 'Phòng trọ yêu thích',
                    subtitle: 'Danh sách phòng bạn quan tâm',
                    onTap: () {},
                  ),
                  _buildMenuDivider(),
                  _buildMenuRow(
                    icon: Icons.meeting_room_outlined,
                    title: 'Phòng đang thuê (Nhà của tôi)',
                    subtitle: '1 phòng đang hoạt động',
                    onTap: () {},
                  ),
                  _buildMenuDivider(),
                  _buildMenuRow(
                    icon: Icons.build_outlined,
                    title: 'Báo cáo sự cố phòng trọ',
                    subtitle: 'Máy lạnh, điện nước, wifi',
                    onTap: () {},
                  ),
                  _buildMenuDivider(),
                  _buildMenuRow(
                    icon: Icons.settings_outlined,
                    title: 'Cài đặt tài khoản & Đăng xuất',
                    subtitle: 'Bảo mật, thông báo và tùy chọn',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AccountSettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 4. Lối tắt Cài đặt & Đăng xuất
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AccountSettingsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.manage_accounts_outlined, color: AppColors.primary),
              label: const Text(
                'Mở Cài Đặt & Đăng Xuất',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String number, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            number,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 32,
      width: 1,
      color: const Color(0xFFE5E7EB),
    );
  }

  Widget _buildMenuRow({
    required IconData icon,
    required String title,
    required String subtitle,
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
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        size: 20,
        color: AppColors.textMuted,
      ),
    );
  }

  Widget _buildMenuDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 52,
      color: Color(0xFFF1F3F5),
    );
  }
}
