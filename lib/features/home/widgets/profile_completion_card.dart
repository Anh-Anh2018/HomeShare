import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/user_provider.dart';
import '../models/profile_overview.dart';

/// Thẻ theo dõi tiến độ Hoàn thiện hồ sơ Người thuê
class ProfileCompletionCard extends StatelessWidget {
  final UserProfile? profile;
  final VoidCallback? onUpdateProfile;

  const ProfileCompletionCard({
    super.key,
    required this.profile,
    this.onUpdateProfile,
  });

  @override
  Widget build(BuildContext context) {
    final completionPercentage =
        ProfileOverviewHelper.calculateCompletionPercentage(profile);
    final completionRatio = ProfileOverviewHelper.calculateCompletionRatio(
      profile,
    );

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.assignment_turned_in_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Hoàn thiện hồ sơ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$completionPercentage%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: completionPercentage >= 100
                        ? AppColors.success
                        : AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: completionRatio,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(
                  completionPercentage >= 100
                      ? AppColors.success
                      : AppColors.primary,
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    completionPercentage >= 100
                        ? 'Hồ sơ đã đầy đủ 100%! Điểm tín nhiệm tối ưu.'
                        : 'Hồ sơ đầy đủ giúp duyệt thuê phòng và kết nối ở ghép nhanh hơn.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
                if (completionPercentage < 100) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: onUpdateProfile,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: const Size(44, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Cập nhật',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
