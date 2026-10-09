import 'package:flutter/material.dart';
import '../../auth/providers/user_provider.dart';
import '../models/profile_overview.dart';
import 'profile_actions_card.dart';
import 'profile_completion_card.dart';
import 'profile_header_card.dart';
import 'profile_stats_card.dart';

/// Widget trình bày (Composition) Trang Cá Nhân cho Người thuê (Renter).
/// Kết hợp các thành phần con độc lập:
/// - ProfileHeaderCard: Avatar (kèm fallback), Tên, Badge vai trò, ID, Email, SĐT, eKYC
/// - ProfileCompletionCard: Tiến độ % hoàn thiện hồ sơ và nút Cập nhật
/// - ProfileStatsCard: Thống kê số lượng đơn thuê thực tế (Đơn & Lịch hẹn, Đang xử lý, Đang thuê)
/// - ProfileActionsCard: 4 chức năng quản lý tài khoản và Đăng xuất có xác nhận
class PersonalProfileContent extends StatelessWidget {
  final UserProfile? profile;
  final ProfileOverviewStats stats;
  final bool isBookingsLoading;
  final bool hasBookingsError;
  final VoidCallback? onOpenAccountSettings;
  final VoidCallback? onOpenCccdVerification;
  final VoidCallback? onOpenBookings;
  final VoidCallback? onSignOut;

  const PersonalProfileContent({
    super.key,
    required this.profile,
    this.stats = const ProfileOverviewStats(),
    this.isBookingsLoading = false,
    this.hasBookingsError = false,
    this.onOpenAccountSettings,
    this.onOpenCccdVerification,
    this.onOpenBookings,
    this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Thẻ thông tin tài khoản
          ProfileHeaderCard(
            profile: profile,
            onTap: onOpenAccountSettings,
            onOpenCccdVerification: onOpenCccdVerification,
          ),
          const SizedBox(height: 12),

          // 2. Thẻ hoàn thiện hồ sơ
          ProfileCompletionCard(
            profile: profile,
            onUpdateProfile: onOpenAccountSettings,
          ),
          const SizedBox(height: 12),

          // 3. Thẻ thống kê hoạt động thuê phòng (số liệu thật)
          ProfileStatsCard(
            stats: stats,
            isLoading: isBookingsLoading,
            hasError: hasBookingsError,
            onTap: onOpenBookings,
          ),
          const SizedBox(height: 16),

          // 4. Khu Quản lý tài khoản (4 hành động)
          ProfileActionsCard(
            isCccdVerified: profile?.isCccdVerified ?? false,
            onOpenBookings: onOpenBookings,
            onOpenCccdVerification: onOpenCccdVerification,
            onOpenAccountSettings: onOpenAccountSettings,
            onSignOut: onSignOut,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
