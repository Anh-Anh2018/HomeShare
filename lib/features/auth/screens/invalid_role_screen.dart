import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';

/// Màn hình thông báo lỗi vai trò không hợp lệ / tài khoản chưa phân quyền (Fail-closed).
/// Tuyệt đối không tự động fallback về vai trò Người thuê (Renter).
/// Cho phép người dùng kiểm tra trạng thái và chủ động Đăng xuất an toàn.
class InvalidRoleScreen extends ConsumerStatefulWidget {
  final String? role;

  const InvalidRoleScreen({super.key, this.role});

  @override
  ConsumerState<InvalidRoleScreen> createState() => _InvalidRoleScreenState();
}

class _InvalidRoleScreenState extends ConsumerState<InvalidRoleScreen> {
  bool _isSigningOut = false;

  Future<void> _handleSignOut() async {
    setState(() => _isSigningOut = true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
    } catch (e) {
      debugPrint('Invalid role screen sign out error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể đăng xuất. Vui lòng thử lại sau.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawRole = widget.role?.trim() ?? '';
    final roleDisplayText = rawRole.isEmpty ? 'Chưa được thiết lập' : rawRole;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Xác Thực Vai Trò',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.danger),
            tooltip: 'Đăng xuất',
            onPressed: _isSigningOut ? null : _handleSignOut,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 32.0,
            ),
            child: Container(
              padding: const EdgeInsets.all(28.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon cảnh báo bảo mật
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.dangerContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.gpp_bad_outlined,
                      size: 40,
                      color: AppColors.danger,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tiêu đề
                  const Text(
                    'Vai Trò Không Hợp Lệ',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Mô tả chi tiết chính sách Fail-Closed
                  const Text(
                    'Tài khoản của bạn chưa được cấp vai trò hợp lệ trên hệ thống HomeShare. Để bảo mật dữ liệu và quyền riêng tư, hệ thống không thể tự động chuyển vào giao diện người dùng.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Khối thông tin chi tiết vai trò nhận diện
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Vai trò ghi nhận:',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            roleDisplayText,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.danger,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Gợi ý giải pháp
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warningContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: AppColors.warning,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Vui lòng liên hệ Quản trị viên hệ thống để được cấp quyền hoặc đăng xuất để đăng nhập với tài khoản hợp lệ.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textDark,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Nút Đăng xuất
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isSigningOut ? null : _handleSignOut,
                      icon: _isSigningOut
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.logout, size: 20),
                      label: Text(
                        _isSigningOut
                            ? 'Đang đăng xuất...'
                            : 'Đăng xuất tài khoản',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
