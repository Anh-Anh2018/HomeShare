import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/profile_overview.dart';

/// Thẻ thống kê hoạt động thuê phòng từ danh sách Đơn thuê thực tế
class ProfileStatsCard extends StatelessWidget {
  final ProfileOverviewStats stats;
  final bool isLoading;
  final bool hasError;
  final VoidCallback? onTap;

  const ProfileStatsCard({
    super.key,
    required this.stats,
    this.isLoading = false,
    this.hasError = false,
    this.onTap,
  });

  Widget _buildStatItem({
    required String value,
    required String label,
    required IconData icon,
    Color? color,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color ?? AppColors.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color ?? AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 36, width: 1, color: AppColors.border);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Thống kê hoạt động thuê phòng, nhấn để xem đơn thuê và lịch hẹn',
      button: true,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        color: Colors.white,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 14.0,
              horizontal: 12.0,
            ),
            child: hasError
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Không thể tải thống kê đơn thuê lúc này',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      _buildStatItem(
                        value: isLoading ? '...' : '${stats.totalBookings}',
                        label: 'Đơn & Lịch hẹn',
                        icon: Icons.calendar_today_outlined,
                      ),
                      _buildVerticalDivider(),
                      _buildStatItem(
                        value: isLoading ? '...' : '${stats.pendingCount}',
                        label: 'Đang xử lý',
                        icon: Icons.hourglass_top_outlined,
                        color: AppColors.warning,
                      ),
                      _buildVerticalDivider(),
                      _buildStatItem(
                        value: isLoading ? '...' : '${stats.activeCount}',
                        label: 'Đang thuê',
                        icon: Icons.home_work_outlined,
                        color: AppColors.success,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
