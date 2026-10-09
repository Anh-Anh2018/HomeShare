import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/user_provider.dart';

/// Thẻ thông tin tài khoản Người thuê (Header Card)
/// Hỗ trợ fallback avatar qua initials khi URL lỗi hoặc rỗng.
/// Sử dụng LayoutBuilder và ConstrainedBox để chống overflow tuyệt đối trên màn hình 320px và text scale lớn.
class ProfileHeaderCard extends StatelessWidget {
  final UserProfile? profile;
  final VoidCallback? onTap;
  final VoidCallback? onOpenCccdVerification;

  const ProfileHeaderCard({
    super.key,
    required this.profile,
    this.onTap,
    this.onOpenCccdVerification,
  });

  Widget _buildAvatar(String initialLetter) {
    final avatarUrl = profile?.avatarUrl.trim() ?? '';
    final hasUrl = avatarUrl.isNotEmpty;

    final initialWidget = Center(
      child: Text(
        initialLetter,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );

    return ClipOval(
      child: Container(
        width: 54,
        height: 54,
        color: AppColors.primaryContainer,
        child: hasUrl
            ? Image.network(
                avatarUrl,
                width: 54,
                height: 54,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => initialWidget,
              )
            : initialWidget,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = (profile?.displayName.trim().isNotEmpty == true)
        ? profile!.displayName.trim()
        : 'Người dùng HomeShare';

    final emailText = (profile?.email.trim().isNotEmpty == true)
        ? profile!.email.trim()
        : 'Chưa cập nhật';

    final phoneText = (profile?.phoneNumber.trim().isNotEmpty == true)
        ? profile!.phoneNumber.trim()
        : 'Chưa cập nhật';

    final userCodeText = (profile?.userCode.trim().isNotEmpty == true)
        ? profile!.userCode.trim()
        : 'Chưa có mã';

    final isCccdVerified = profile?.isCccdVerified ?? false;

    // Vai trò hiển thị
    String roleBadgeText = 'Người thuê';
    if (profile?.role == 'host' ||
        profile?.role == 'chutro' ||
        profile?.role == 'landlord') {
      roleBadgeText = 'Chủ trọ';
    } else if (profile?.role == 'admin') {
      roleBadgeText = 'Quản trị viên';
    }

    final initialLetter =
        (displayName != 'Người dùng HomeShare' && displayName.isNotEmpty)
        ? displayName[0].toUpperCase()
        : 'HS';

    return Semantics(
      label: 'Thông tin tài khoản, nhấn để chỉnh sửa hồ sơ',
      button: true,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        elevation: 0,
        color: Colors.white,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildAvatar(initialLetter),
                const SizedBox(width: 10),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxContentWidth = constraints.maxWidth;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tên và Badge vai trò (ConstrainedBox chống tràn chuỗi dài trong Wrap)
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 3,
                            children: [
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: maxContentWidth,
                                ),
                                child: Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  roleBadgeText,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // ID & Email (ConstrainedBox chống tràn email dài trong Wrap)
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 3,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  'ID: $userCodeText',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: maxContentWidth,
                                ),
                                child: Text(
                                  emailText,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (phoneText != 'Chưa cập nhật') ...[
                            const SizedBox(height: 3),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: maxContentWidth,
                              ),
                              child: Text(
                                'SĐT: $phoneText',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          const SizedBox(height: 5),
                          // eKYC badge: Bọc ConstrainedBox giới hạn đúng maxContentWidth để Row + Flexible ép ellipsis thực sự
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: maxContentWidth,
                            ),
                            child: isCccdVerified
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.successContainer,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.verified,
                                          size: 12,
                                          color: AppColors.success,
                                        ),
                                        SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Đã xác thực CCCD (eKYC) ✓',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.success,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : InkWell(
                                    onTap: onOpenCccdVerification,
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.warningContainer
                                            .withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: AppColors.warning.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.gpp_maybe_outlined,
                                            size: 12,
                                            color: AppColors.warning,
                                          ),
                                          SizedBox(width: 3),
                                          Flexible(
                                            child: Text(
                                              'Chưa xác thực CCCD (Quét ngay)',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.warning,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          SizedBox(width: 2),
                                          Icon(
                                            Icons.chevron_right,
                                            size: 12,
                                            color: AppColors.warning,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
