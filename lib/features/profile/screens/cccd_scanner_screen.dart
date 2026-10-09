import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/constants/app_colors.dart';
import '../models/cccd_data.dart';
import '../services/cccd_image_evidence_validator.dart';


/// Màn hình Camera quét mã CCCD (Chỉ hiển thị khung quét thẻ, che mờ hoàn toàn background)
class CccdScannerScreen extends ConsumerStatefulWidget {
  final bool returnDataOnly;

  const CccdScannerScreen({
    super.key,
    this.returnDataOnly = false,
  });

  @override
  ConsumerState<CccdScannerScreen> createState() => _CccdScannerScreenState();
}

class _CccdScannerScreenState extends ConsumerState<CccdScannerScreen> with SingleTickerProviderStateMixin {
  late final MobileScannerController _scannerController;
  late final AnimationController _laserAnimController;
  bool _isProcessing = false;
  bool _isFlashOn = false;
  double _currentZoom = 0.35; // Zoom 2.0x phần cứng để bắt mã QR nhỏ (~1cm) cực nét

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 200,
      formats: const [BarcodeFormat.qrCode],
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    // Kích hoạt Zoom phần cứng sau khi camera khởi tạo để quét QR nhỏ dễ dàng không bị out-focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          try {
            _scannerController.setZoomScale(_currentZoom);
          } catch (_) {}
        }
      });
    });

    // Hiệu ứng tia laser quét lên xuống
    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laserAnimController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_isProcessing) return;

    for (final barcode in capture.barcodes) {
      String rawValue = barcode.rawValue ?? '';

      // Đọc UTF-8 tiếng Việt từ rawBytes của ML Kit
      // ignore: deprecated_member_use
      final List<int>? rawBytes = barcode.rawBytes;
      if (rawBytes != null && rawBytes.isNotEmpty) {
        try {
          final decoded = utf8.decode(rawBytes, allowMalformed: true);
          if (decoded.trim().isNotEmpty) {
            rawValue = decoded;
          }
        } catch (_) {}
      } else if (rawValue.isNotEmpty) {
        // Fallback: sửa lỗi nếu chuỗi bị nhầm ISO-8859-1 sang UTF-8
        try {
          final bytes = latin1.encode(rawValue);
          final fixedUtf8 = utf8.decode(bytes);
          if (fixedUtf8.contains('|')) {
            rawValue = fixedUtf8;
          }
        } catch (_) {}
      }

      final trimmed = rawValue.trim().replaceAll('\uFEFF', '');
      if (trimmed.isEmpty) {
        continue;
      }

      final cccd = const CccdImageEvidenceValidator().validateStrictQr(trimmed);
      if (cccd == null) {
        setState(() => _isProcessing = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mã QR CCCD không hợp lệ hoặc thiếu dữ liệu.'),
              backgroundColor: Colors.amber,
              duration: Duration(seconds: 2),
            ),
          );
        }
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() => _isProcessing = false);
          }
        });
        break;
      }

      // Haptic feedback & âm thanh click báo đã quét dính thẻ thật
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.click);

      setState(() => _isProcessing = true);
      _showVerificationModal(cccd, isRealScan: true, rawQrText: trimmed);
      break;
    }
  }

  // Hộp thoại dán hoặc nhập chuỗi QR thật (phòng khi phòng tối hoặc đèn trần phản chiếu)
  void _pasteRawQrDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_2, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Nhập Chuỗi QR Thật', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nếu camera bị bóng đèn phản chiếu, bạn có thể dán chuỗi quét từ Zalo/Google Lens vào đây để trích xuất 100% dữ liệu thật:',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Ví dụ: 079201012345||HỌ TÊN|15082001|Nam|ĐỊA CHỈ|25122021',
                hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final text = textController.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx);
                final cccd = const CccdImageEvidenceValidator().validateStrictQr(text);
                if (cccd == null) {
                  setState(() => _isProcessing = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Mã QR CCCD không hợp lệ hoặc thiếu dữ liệu.'),
                        backgroundColor: Colors.amber,
                      ),
                    );
                  }
                  return;
                }
                HapticFeedback.heavyImpact();
                setState(() => _isProcessing = true);
                _showVerificationModal(cccd, isRealScan: true, rawQrText: text);
              }
            },
            child: const Text('Bóc Tách Thật'),
          ),
        ],
      ),
    );
  }

  // Quét mã QR CCCD từ ảnh trong Thư viện ảnh (Bộ sưu tập)
  Future<void> _scanFromGalleryImage() async {
    if (_isProcessing) return;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
      if (picked == null) return;

      setState(() => _isProcessing = true);
      HapticFeedback.mediumImpact();

      final capture = await _scannerController.analyzeImage(picked.path);
      if (capture != null && capture.barcodes.isNotEmpty) {
        bool foundValid = false;
        for (final barcode in capture.barcodes) {
          String rawValue = barcode.rawValue ?? '';
          // ignore: deprecated_member_use
          final List<int>? rawBytes = barcode.rawBytes;
          if (rawBytes != null && rawBytes.isNotEmpty) {
            try {
              final decoded = utf8.decode(rawBytes, allowMalformed: true);
              if (decoded.trim().isNotEmpty) {
                rawValue = decoded;
              }
            } catch (_) {}
          } else if (rawValue.isNotEmpty) {
            try {
              final bytes = latin1.encode(rawValue);
              final fixedUtf8 = utf8.decode(bytes);
              if (fixedUtf8.contains('|')) {
                rawValue = fixedUtf8;
              }
            } catch (_) {}
          }

          final trimmed = rawValue.trim().replaceAll('\uFEFF', '');
          if (trimmed.isEmpty) continue;

          final cccd = const CccdImageEvidenceValidator().validateStrictQr(trimmed);
          if (cccd != null) {
            foundValid = true;
            HapticFeedback.heavyImpact();
            SystemSound.play(SystemSoundType.click);
            _showVerificationModal(cccd, isRealScan: true, rawQrText: trimmed);
            break;
          }
        }

        if (!foundValid) {
          setState(() => _isProcessing = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Mã QR CCCD không hợp lệ hoặc thiếu dữ liệu.'),
                backgroundColor: Colors.amber,
              ),
            );
          }
        }
      } else {
        setState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không quét được mã QR từ ảnh đã chọn. Vui lòng chọn ảnh rõ nét hơn hoặc đưa camera lại gần thẻ.'),
              backgroundColor: Colors.amber,
            ),
          );
        }
      }
    } catch (_) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lỗi khi phân tích ảnh. Vui lòng thử lại.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  

  void _showVerificationModal(CccdData cccd, {bool isRealScan = false, String? rawQrText}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isRealScan ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                    child: Icon(
                      isRealScan ? Icons.verified_user : Icons.check,
                      color: isRealScan ? AppColors.primary : const Color(0xFFD97706),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isRealScan ? 'ĐÃ TRÍCH XUẤT 100% THÔNG TIN THẬT' : 'ĐÃ QUÉT THÀNH CÔNG CCCD',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                        ),
                        Text(
                          isRealScan
                              ? 'Dữ liệu được giải mã trực tiếp từ mã QR thẻ CCCD của bạn'
                              : 'Vui lòng kiểm tra lại thông tin trích xuất từ thẻ chip',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Thẻ CCCD mô phỏng
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.credit_card, color: AppColors.primary, size: 20),
                            const SizedBox(width: 6),
                            const Text('CĂN CƯỚC CÔNG DÂN GẮN CHIP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                            const SizedBox(width: 8),
                            
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                          child: const Text('Bộ Công An', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    _buildInfoRow('Số CCCD / ID:', cccd.idNumber, isHighlight: true),
                    if (cccd.oldCmnd.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildInfoRow('Số CMND 9 số cũ:', cccd.oldCmnd),
                    ],
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
                      _buildInfoRow('Nơi khai sinh (Mã ${cccd.provinceCode}):', cccd.provinceName!),
                    ],
                    if (cccd.analyzedBirthYear != null) ...[
                      const SizedBox(height: 6),
                      _buildInfoRow('Phân tích đối soát:', '${cccd.analyzedGender ?? cccd.gender} • Sinh năm ${cccd.analyzedBirthYear}'),
                    ],
                    const SizedBox(height: 6),
                    _buildInfoRow('Nơi thường trú:', cccd.address),
                    const SizedBox(height: 6),
                    _buildInfoRow('Ngày cấp:', cccd.issueDate),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() => _isProcessing = false);
                      },
                      child: const Text('Quét Lại'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _confirmVerification(cccd),
                      child: Text(
                        widget.returnDataOnly ? 'Dùng Thông Tin Này ✓' : 'Xác Nhận & Lưu eKYC',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      setState(() => _isProcessing = false);
    });
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlight = false, bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 95,
          child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: (isHighlight || isBold) ? FontWeight.bold : FontWeight.w500,
              color: isHighlight ? AppColors.primary : AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmVerification(CccdData cccd) async {
    if (mounted) {
      Navigator.pop(context); // Đóng modal bottom sheet
      Navigator.pop(context, cccd); // Trả đối tượng cccd về cho màn hình xác thực 3 mục
    }
  }

  Widget _buildGuidanceBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Lưu ý: Mã QR nằm ở MẶT TRƯỚC thẻ (cạnh Quốc huy). Đưa sát ống kính 10-15cm để nhận diện tức thì!',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF92400E),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildZoomItem('1.0x', 0.0),
          _buildZoomItem('2.0x', 0.35),
          _buildZoomItem('3.0x', 0.60),
        ],
      ),
    );
  }

  Widget _buildZoomItem(String label, double zoomScale) {
    final isCurrent = (_currentZoom - zoomScale).abs() < 0.12;
    return InkWell(
      onTap: () {
        setState(() => _currentZoom = zoomScale);
        try {
          _scannerController.setZoomScale(zoomScale);
        } catch (_) {}
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isCurrent ? Colors.amber.shade700 : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isCurrent ? Colors.white : Colors.white70,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
            fontSize: 11.5,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    // Khung ngắm hình vuông chuyên biệt để quét mã QR CCCD (kích thước ~1x1cm)
    final boxSize = (screenSize.width * 0.68).clamp(230.0, 270.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Viewfinder thực tế từ thiết bị
          Positioned.fill(
            child: MobileScanner(
              controller: _scannerController,
              onDetect: _onBarcodeDetected,
            ),
          ),

          // 2. Lớp phủ đen làm mờ background xung quanh - CHỈ CHỪA Ô VUÔNG MÃ QR
          Positioned.fill(
            child: CustomPaint(
              painter: _CardCutoutOverlayPainter(
                boxSize: boxSize,
              ),
            ),
          ),

          // 3. Khung viền dạ quang và tia laser quét mã QR
          Center(
            child: SizedBox(
              width: boxSize,
              height: boxSize,
              child: Stack(
                children: [
                  // 4 góc căn chỉnh
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CornerBracketsPainter(
                        color: AppColors.primary,
                        strokeWidth: 4,
                      ),
                    ),
                  ),

                  // Watermark hướng dẫn đặt mã QR ở giữa
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.qr_code_2_rounded,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Đặt mã QR vào giữa ô',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tia Laser quét chuyển động
                  AnimatedBuilder(
                    animation: _laserAnimController,
                    builder: (context, child) {
                      return Positioned(
                        top: _laserAnimController.value * (boxSize - 6),
                        left: 8,
                        right: 8,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.transparent, AppColors.primary, Colors.transparent],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.8),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // 4. Thanh Header điều khiển trên cùng
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.black45,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const Text(
                        'QUÉT MÃ QR TRÊN CCCD',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1),
                      ),
                      CircleAvatar(
                        backgroundColor: Colors.black45,
                        child: IconButton(
                          icon: Icon(
                            _isFlashOn ? Icons.flash_on : Icons.flash_off,
                            color: _isFlashOn ? Colors.yellow : Colors.white,
                          ),
                          onPressed: () {
                            _scannerController.toggleTorch();
                            setState(() => _isFlashOn = !_isFlashOn);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Banner nhắc nhở mặt trước CCCD
                _buildGuidanceBanner(),
              ],
            ),
          ),

          // 5. Thanh Hướng dẫn & Nút Thao tác dưới đáy
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Hàng điều khiển Zoom
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.zoom_in, color: Colors.white70, size: 16),
                        const SizedBox(width: 8),
                        _buildZoomControls(),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Hướng dẫn
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.center_focus_strong, color: AppColors.primary, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Đưa mã QR CCCD vào ô vuông (cách 10-15cm)',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Hàng nút hành động
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Đổi camera trước / sau
                        IconButton(
                          icon: const Icon(Icons.cameraswitch, color: Colors.white70, size: 24),
                          tooltip: 'Đổi camera',
                          onPressed: () => _scannerController.switchCamera(),
                        ),

                        // Nút Quét mã QR từ ảnh Thư viện
                        IconButton(
                          icon: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 24),
                          tooltip: 'Quét từ ảnh thư viện',
                          onPressed: _scanFromGalleryImage,
                        ),

                        // Nút Nhập / Dán Chuỗi QR Thật
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          icon: const Icon(Icons.paste_rounded, size: 16, color: Colors.amber),
                          label: const Text('Dán QR Thật', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          onPressed: _pasteRawQrDialog,
                        ),


                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter tạo lớp phủ tối che toàn bộ background, chỉ khoét lỗ trong suốt đúng kích thước ô vuông QR
class _CardCutoutOverlayPainter extends CustomPainter {
  final double boxSize;

  _CardCutoutOverlayPainter({required this.boxSize});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    final rect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: boxSize,
      height: boxSize,
    );

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));

    // Vẽ vùng phủ đen trừ đi ô vuông cutout
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, backgroundPaint);

    // Vẽ viền thanh mảnh quanh khung
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CardCutoutOverlayPainter oldDelegate) {
    return oldDelegate.boxSize != boxSize;
  }
}

/// CustomPainter vẽ 4 góc ngàm viền dạ quang (Corner Brackets)
class _CornerBracketsPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _CornerBracketsPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 24.0;

    // Góc trên bên trái
    canvas.drawLine(const Offset(0, 0), const Offset(cornerLength, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, cornerLength), paint);

    // Góc trên bên phải
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - cornerLength, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerLength), paint);

    // Góc dưới bên trái
    canvas.drawLine(Offset(0, size.height), Offset(cornerLength, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - cornerLength), paint);

    // Góc dưới bên phải
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - cornerLength, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketsPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
