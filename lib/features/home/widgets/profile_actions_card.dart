import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Khối Quản lý tài khoản và Đăng xuất (Chỉ giữ 4 hành động đang hoạt động)
/// Thiết kế an toàn chống overflow trên màn hình 320px
class ProfileActionsCard extends StatelessWidget {
  final bool isCccdVerified;
  final VoidCallback? onOpenBookings;
  final VoidCallback? onOpenCccdVerification;
  final VoidCallback? onOpenAccountSettings;
  final VoidCallback? onSignOut;

  const ProfileActionsCard({
    super.key,
    required this.isCccdVerified,
    this.onOpenBookings,
    this.onOpenCccdVerification,
    this.onOpenAccountSettings,
    this.onSignOut,
  });

  static void showSignOutDialog(BuildContext context, VoidCallback? onSignOut) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Xác nhận đăng xuất',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản HomeShare không?',
          style: TextStyle(fontSize: 14),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Hủy',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onSignOut?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    String? trailingBadge,
    bool isBadgeSuccess = false,
    bool isDestructive = false,
    required String semanticsLabel,
  }) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDestructive
                      ? AppColors.dangerContainer.withValues(alpha: 0.5)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isDestructive ? AppColors.danger : AppColors.textDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxColWidth = constraints.maxWidth;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 2,
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: maxColWidth,
                              ),
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDestructive
                                      ? AppColors.danger
                                      : AppColors.textDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (trailingBadge != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: isBadgeSuccess
                                      ? AppColors.successContainer
                                      : AppColors.warningContainer.withValues(
                                          alpha: 0.7,
                                        ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  trailingBadge,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: isBadgeSuccess
                                        ? AppColors.success
                                        : AppColors.warning,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxColWidth),
                          child: Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: isDestructive
                    ? AppColors.danger
                    : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 54,
      color: AppColors.border,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'QUẢN LÝ TÀI KHOẢN',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildActionRow(
                context: context,
                icon: Icons.calendar_month_outlined,
                title: 'Đơn thuê & Lịch hẹn',
                subtitle: 'Theo dõi yêu cầu xem phòng và thuê trọ',
                onTap: onOpenBookings,
                semanticsLabel: 'Mở danh sách đơn thuê và lịch hẹn',
              ),
              _buildDivider(),
              _buildActionRow(
                context: context,
                icon: Icons.badge_outlined,
                title: 'Xác thực danh tính (CCCD)',
                subtitle: isCccdVerified
                    ? 'Hồ sơ đã hoàn tất xác thực eKYC'
                    : 'Quét CCCD để tăng độ uy tín tài khoản',
                trailingBadge: isCccdVerified ? 'ĐÃ XÁC THỰC' : 'CHƯA XÁC THỰC',
                isBadgeSuccess: isCccdVerified,
                onTap: onOpenCccdVerification,
                semanticsLabel:
                    'Mở màn hình xác thực danh tính căn cước công dân',
              ),
              _buildDivider(),
              _buildActionRow(
                context: context,
                icon: Icons.manage_accounts_outlined,
                title: 'Cài đặt tài khoản',
                subtitle: 'Cập nhật thông tin cá nhân và bảo mật',
                onTap: onOpenAccountSettings,
                semanticsLabel: 'Mở màn hình cài đặt tài khoản',
              ),
              _buildDivider(),
              _buildActionRow(
                context: context,
                icon: Icons.logout,
                title: 'Đăng xuất',
                subtitle: 'Thoát phiên đăng nhập hiện tại',
                isDestructive: true,
                onTap: () => showSignOutDialog(context, onSignOut),
                semanticsLabel: 'Đăng xuất khỏi ứng dụng',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
