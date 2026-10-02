import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import 'cccd_scanner_screen.dart';

/// Màn hình Xác thực CCCD (eKYC) với 3 mục bắt buộc:
/// 1. Ảnh mặt trước CCCD
/// 2. Ảnh mặt sau CCCD
/// 3. Quét lấy thông tin từ mã QR CCCD
/// Nút xác thực chỉ được kích hoạt khi đã hoàn thành đủ cả 3 mục.
class CccdVerificationScreen extends ConsumerStatefulWidget {
  const CccdVerificationScreen({super.key});

  @override
  ConsumerState<CccdVerificationScreen> createState() => _CccdVerificationScreenState();
}

class _CccdVerificationScreenState extends ConsumerState<CccdVerificationScreen> {
  final ImagePicker _picker = ImagePicker();

  XFile? _frontImage;
  XFile? _backImage;
  CccdData? _cccdData;
  bool _isSubmitting = false;

  bool get _isComplete => _frontImage != null && _backImage != null && _cccdData != null;

  int get _completedCount {
    int count = 0;
    if (_frontImage != null) count++;
    if (_backImage != null) count++;
    if (_cccdData != null) count++;
    return count;
  }

  List<String> get _missingItems {
    final list = <String>[];
    if (_frontImage == null) list.add('Ảnh mặt trước');
    if (_backImage == null) list.add('Ảnh mặt sau');
    if (_cccdData == null) list.add('Quét mã QR');
    return list;
  }

  /// Chọn hoặc chụp ảnh mặt trước/sau
  Future<void> _pickImage(bool isFront, ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked != null) {
        setState(() {
          if (isFront) {
            _frontImage = picked;
          } else {
            _backImage = picked;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể truy cập camera hoặc thư viện: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  /// Dùng ảnh mẫu demo thử nghiệm khi không có thẻ cứng
  void _useDemoImage(bool isFront) {
    // Tạo XFile tạm thời để mô phỏng ảnh CCCD demo
    setState(() {
      if (isFront) {
        _frontImage = XFile(
          'demo_cccd_front.jpg',
          name: 'demo_cccd_front.jpg',
        );
      } else {
        _backImage = XFile(
          'demo_cccd_back.jpg',
          name: 'demo_cccd_back.jpg',
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isFront
              ? 'Đã tải ảnh mẫu CCCD mặt trước (Dành cho thử nghiệm)'
              : 'Đã tải ảnh mẫu CCCD mặt sau (Dành cho thử nghiệm)',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Hiển thị BottomSheet chọn nguồn ảnh
  void _showImagePickerModal(bool isFront) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                isFront ? 'CHỤP / CHỌN ẢNH MẶT TRƯỚC CCCD' : 'CHỤP / CHỌN ẢNH MẶT SAU CCCD',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isFront
                    ? 'Yêu cầu: Rõ nét họ tên, số CCCD, chân dung, không bị lóa'
                    : 'Yêu cầu: Rõ nét chip điện tử, mã MRZ và đặc điểm nhận dạng',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryContainer,
                  child: Icon(Icons.camera_alt, color: AppColors.primary),
                ),
                title: const Text('Chụp ảnh trực tiếp từ Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Mở máy ảnh để chụp thẻ thật'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(isFront, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryContainer,
                  child: Icon(Icons.photo_library, color: AppColors.primary),
                ),
                title: const Text('Chọn ảnh từ Thư viện (Bộ sưu tập)', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Chọn ảnh đã chụp sẵn trong máy'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(isFront, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.amber.shade100,
                  child: const Icon(Icons.science_outlined, color: Colors.amber),
                ),
                title: const Text('Dùng ảnh mẫu thử nghiệm (Demo)', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Tiện lợi để kiểm thử chức năng khi không có thẻ bên cạnh'),
                onTap: () {
                  Navigator.pop(ctx);
                  _useDemoImage(isFront);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Mở màn hình quét mã QR thẻ CCCD
  Future<void> _scanCccdQr() async {
    final result = await Navigator.push<CccdData>(
      context,
      MaterialPageRoute(
        builder: (_) => const CccdScannerScreen(returnDataOnly: true),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _cccdData = result;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã trích xuất thông tin: ${result.fullName} (${result.idNumber}) ✓'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  /// Nhấn nút Xác thực và lưu toàn bộ thông tin
  Future<void> _submitVerification() async {
    if (!_isComplete || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final user = ref.read(currentUserProvider);
      final uid = user?.uid ?? 'guest_uid';

      DateTime? parsedBirth;
      try {
        final parts = _cccdData!.birthDate.split('/');
        if (parts.length == 3) {
          parsedBirth = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      } catch (_) {}

      await saveCccdVerificationToBackend(
        uid: uid,
        cccdNumber: _cccdData!.idNumber,
        cccdFullName: _cccdData!.fullName,
        cccdIssueDate: _cccdData!.issueDate,
        cccdHometown: _cccdData!.address,
        gender: _cccdData!.gender,
        birthDate: parsedBirth,
        cccdFrontImageUrl: _frontImage!.path,
        cccdBackImageUrl: _backImage!.path,
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.verified, color: AppColors.primary, size: 28),
                SizedBox(width: 8),
                Text('Xác Thực Thành Công!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tài khoản của bạn đã hoàn tất quy trình eKYC định danh điện tử với đầy đủ:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 10),
                const Text('✓ Ảnh mặt trước thẻ CCCD', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                const Text('✓ Ảnh mặt sau thẻ CCCD (gắn chip)', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                Text('✓ Dữ liệu QR: ${_cccdData!.fullName} - ${_cccdData!.idNumber}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(ctx); // Đóng dialog
                  Navigator.pop(context, true); // Trở về màn hình trước
                },
                child: const Text('Hoàn Tất'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Có lỗi xảy ra khi lưu xác thực: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Xác thực CCCD (eKYC)'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thanh tiến độ 3 mục
            _buildProgressCard(),

            const SizedBox(height: 16),

            // Mục 1: Ảnh mặt trước CCCD
            _buildImageUploadCard(
              title: 'Mục 1: Lưu ảnh mặt trước CCCD',
              subtitle: 'Chụp rõ nét mặt trước (ảnh chân dung, số CCCD, họ tên)',
              image: _frontImage,
              isFront: true,
            ),

            const SizedBox(height: 16),

            // Mục 2: Ảnh mặt sau CCCD
            _buildImageUploadCard(
              title: 'Mục 2: Lưu ảnh mặt sau CCCD',
              subtitle: 'Chụp rõ nét mặt sau (chip điện tử, mã MRZ)',
              image: _backImage,
              isFront: false,
            ),

            const SizedBox(height: 16),

            // Mục 3: Quét lấy thông tin mã CCCD
            _buildQrScanCard(),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActionBar(),
    );
  }

  /// Card tiến độ hoàn thành các bước
  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quy trình xác thực định danh',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _isComplete ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_completedCount/3 mục',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _isComplete ? AppColors.primary : const Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _completedCount / 3,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(_isComplete ? AppColors.primary : Colors.amber.shade700),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStepIndicator(1, 'Mặt trước', _frontImage != null),
              const SizedBox(width: 8),
              _buildStepIndicator(2, 'Mặt sau', _backImage != null),
              const SizedBox(width: 8),
              _buildStepIndicator(3, 'Quét mã QR', _cccdData != null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, bool isDone) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: isDone ? const Color(0xFFECFDF5) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDone ? const Color(0xFF6EE7B7) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isDone ? Icons.check_circle : Icons.circle_outlined,
              size: 14,
              color: isDone ? AppColors.primary : Colors.grey.shade500,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                  color: isDone ? AppColors.primary : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Khung tải ảnh mặt trước hoặc mặt sau
  Widget _buildImageUploadCard({
    required String title,
    required String subtitle,
    required XFile? image,
    required bool isFront,
  }) {
    final bool hasImage = image != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasImage ? const Color(0xFF86EFAC) : Colors.grey.shade300,
          width: hasImage ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasImage ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  hasImage ? 'Đã có ảnh ✓' : 'Bắt buộc',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: hasImage ? AppColors.primary : Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 12),

          // Khung hiển thị ảnh hoặc ô bấm chụp
          if (hasImage)
            _buildImagePreview(image, isFront)
          else
            _buildEmptyImagePlaceholder(isFront),
        ],
      ),
    );
  }

  /// Placeholder khi chưa có ảnh
  Widget _buildEmptyImagePlaceholder(bool isFront) {
    return InkWell(
      onTap: () => _showImagePickerModal(isFront),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primaryContainer,
                child: Icon(
                  isFront ? Icons.credit_card : Icons.flip_to_back,
                  size: 28,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isFront ? 'Chạm để chụp / tải ảnh mặt trước' : 'Chạm để chụp / tải ảnh mặt sau',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark),
              ),
              const SizedBox(height: 4),
              const Text(
                'Camera, Thư viện ảnh hoặc Ảnh mẫu thử nghiệm',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Preview khi đã có ảnh
  Widget _buildImagePreview(XFile image, bool isFront) {
    final isRealFile = File(image.path).existsSync();

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: isRealFile
                ? Image.file(
                    File(image.path),
                    fit: BoxFit.cover,
                  )
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isFront ? Icons.badge : Icons.memory,
                            size: 48,
                            color: const Color(0xFF0369A1),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isFront ? 'ẢNH MẪU CCCD MẶT TRƯỚC (DEMO)' : 'ẢNH MẪU CCCD MẶT SAU CHIP (DEMO)',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Color(0xFF0369A1),
                            ),
                          ),
                          const Text('✓ Tệp hợp lệ sẵn sàng xác thực', style: TextStyle(fontSize: 11, color: Color(0xFF075985))),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () => _showImagePickerModal(isFront),
              icon: const Icon(Icons.refresh, size: 16, color: AppColors.primary),
              label: const Text('Chụp lại / Đổi ảnh', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  if (isFront) {
                    _frontImage = null;
                  } else {
                    _backImage = null;
                  }
                });
              },
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
              label: const Text('Xóa', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ],
    );
  }

  /// Thẻ quét mã QR CCCD
  Widget _buildQrScanCard() {
    final bool hasQr = _cccdData != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasQr ? const Color(0xFF86EFAC) : Colors.grey.shade300,
          width: hasQr ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Mục 3: Quét lấy thông tin mã CCCD',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasQr ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  hasQr ? 'Đã trích xuất ✓' : 'Bắt buộc',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: hasQr ? AppColors.primary : Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Quét mã QR góc trên bên phải thẻ CCCD để lấy thông tin thật 100%',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),

          if (hasQr)
            _buildQrDataPreview(_cccdData!)
          else
            _buildEmptyQrPlaceholder(),
        ],
      ),
    );
  }

  /// Placeholder khi chưa quét QR
  Widget _buildEmptyQrPlaceholder() {
    return InkWell(
      onTap: _scanCccdQr,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.qr_code_scanner, size: 30, color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text(
              'Nhấn để Mở Camera Quét Mã QR CCCD',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Hệ thống tự động phân tích và giải mã số thẻ, họ tên, ngày sinh',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  /// Hiển thị thông tin trích xuất từ QR
  Widget _buildQrDataPreview(CccdData cccd) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'THÔNG TIN ĐÃ TRÍCH XUẤT TỪ QR',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green.shade900),
                ),
              ),
              InkWell(
                onTap: _scanCccdQr,
                child: const Text('Quét lại', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(height: 16),
          _buildInfoRow('Số CCCD:', cccd.idNumber, isHighlight: true),
          const SizedBox(height: 6),
          _buildInfoRow('Họ và tên:', cccd.fullName, isBold: true),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _buildInfoRow('Ngày sinh:', cccd.birthDate)),
              Expanded(child: _buildInfoRow('Giới tính:', cccd.gender)),
            ],
          ),
          if (cccd.provinceName != null) ...[
            const SizedBox(height: 6),
            _buildInfoRow('Nơi sinh:', cccd.provinceName!),
          ],
          const SizedBox(height: 6),
          _buildInfoRow('Thường trú:', cccd.address),
          const SizedBox(height: 6),
          _buildInfoRow('Ngày cấp:', cccd.issueDate),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlight = false, bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 85,
          child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: (isHighlight || isBold) ? FontWeight.bold : FontWeight.w500,
              color: isHighlight ? AppColors.primary : AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }

  /// Thanh hành động dưới cùng (Khóa nút nếu chưa đủ 3 mục)
  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thông báo điều kiện xác thực
            if (!_isComplete)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.red),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Thiếu: ${_missingItems.join(', ')}. Cần đủ cả 3 mục để mở nút xác thực.',
                        style: const TextStyle(fontSize: 11.5, color: Colors.red, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: AppColors.primary),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Đã đủ 3/3 mục! Bạn có thể nhấn nút xác thực bên dưới.',
                        style: TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

            // NÚT XÁC THỰC: Bị DISABLED (onPressed: null) nếu chưa đủ 3 mục
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isComplete ? AppColors.primary : Colors.grey.shade300,
                foregroundColor: _isComplete ? Colors.white : Colors.grey.shade500,
                elevation: _isComplete ? 2 : 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: (_isComplete && !_isSubmitting) ? _submitVerification : null,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isComplete ? Icons.verified_user : Icons.lock_outline,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isComplete ? 'XÁC NHẬN & HOÀN TẤT XÁC THỰC' : 'CHƯA ĐỦ ĐIỀU KIỆN XÁC THỰC (0/3)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _isComplete ? Colors.white : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
