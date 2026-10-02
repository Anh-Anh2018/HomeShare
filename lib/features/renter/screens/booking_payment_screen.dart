import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/booking_service.dart';
import '../../../core/utils/vietqr_helper.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/room_model.dart';
import '../../auth/providers/user_provider.dart';
import 'renter_bookings_screen.dart';

/// Màn hình Thanh toán đặt phòng / cọc phòng chuẩn Figma
/// Tích hợp Mã QR chuyển khoản thật 100% đến STK 0382542737 MBBank - TRẦN THANH ANH TOÀN
class BookingPaymentScreen extends ConsumerStatefulWidget {
  final RoomModel room;
  final BookingRequestModel booking;
  final double paymentAmount;
  final String paymentType; // 'deposit' (tiền cọc) hoặc 'full' (tháng đầu + cọc)

  const BookingPaymentScreen({
    super.key,
    required this.room,
    required this.booking,
    required this.paymentAmount,
    this.paymentType = 'deposit',
  });

  @override
  ConsumerState<BookingPaymentScreen> createState() => _BookingPaymentScreenState();
}

class _BookingPaymentScreenState extends ConsumerState<BookingPaymentScreen> {
  late final String _transferContent;
  late final String _qrImageUrl;
  late final String _emvcoPayload;

  Timer? _countdownTimer;
  int _secondsRemaining = 15 * 60; // 15 phút đếm ngược giữ phòng
  bool _isConfirming = false;
  bool _useVectorQrFallback = false;

  @override
  void initState() {
    super.initState();
    // Nội dung chuyển khoản là mã người dùng 5 ký tự (3 số đầu + 2 chữ sau) để Admin dễ dàng tìm kiếm & đối soát
    final profile = ref.read(userProfileProvider).value;
    final userCode = (widget.booking.renterUserCode.isNotEmpty)
        ? widget.booking.renterUserCode
        : ((profile?.userCode.isNotEmpty == true)
            ? profile!.userCode
            : UserProfile.generateUserCode(seed: widget.booking.renterId));
    _transferContent = userCode;

    // Tạo link ảnh VietQR.io và chuỗi EMVCo Napas247 thật
    _qrImageUrl = VietQRHelper.buildVietQrImageUrl(
      amount: widget.paymentAmount,
      addInfo: _transferContent,
      accountNo: VietQRHelper.defaultAccountNo,
      accountName: VietQRHelper.defaultAccountName,
    );

    _emvcoPayload = VietQRHelper.generateNapasEmvcoPayload(
      amount: widget.paymentAmount,
      addInfo: _transferContent,
      accountNo: VietQRHelper.defaultAccountNo,
      bankBin: VietQRHelper.defaultBankBin,
    );

    // Kích hoạt đồng hồ đếm ngược
    _startTimer();
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) {
          setState(() => _secondsRemaining--);
        }
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép $label: $text ✓'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _onConfirmPayment() async {
    if (_secondsRemaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thời gian giữ phòng đã hết. Vui lòng tạo đơn đặt phòng mới!'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isConfirming = true);

    try {
      // Cập nhật trạng thái booking thành đã thanh toán trong Firestore
      if (widget.booking.id.isNotEmpty) {
        await ref.read(bookingServiceProvider).updateBookingStatus(widget.booking.id, 'paid');
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.primaryContainer,
                    child: Icon(Icons.check_circle, size: 48, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ĐÃ GỬI XÁC NHẬN THANH TOÁN!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Hệ thống đã ghi nhận giao dịch đặt cọc ${NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(widget.paymentAmount)} '
                    'cho phòng "${widget.room.title}".\nChủ trọ sẽ liên hệ bàn giao phòng cho bạn trong thời gian sớm nhất!',
                    style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textDark),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx); // Đóng dialog
                        // Điều hướng về danh sách đơn đặt phòng
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RenterBookingsScreen(),
                          ),
                        );
                      },
                      child: const Text('Xem Đơn Đặt Phòng Của Tôi', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConfirming = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Thanh Toán Đặt Phòng'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Thẻ đếm ngược thời gian giữ phòng
            _buildCountdownBanner(),

            const SizedBox(height: 16),

            // 2. Thẻ Mã QR Chuyển Khoản Thật (VietQR MBBank)
            _buildQrCard(),

            const SizedBox(height: 16),

            // 3. Thẻ Thông Tin Thụ Hưởng Chi Tiết (Có nút Copy)
            _buildBankDetailsCard(currencyFmt),

            const SizedBox(height: 16),

            // 4. Hướng dẫn các bước thanh toán
            _buildGuideCard(),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActionBar(),
    );
  }

  Widget _buildCountdownBanner() {
    final isExpiringSoon = _secondsRemaining < 300; // Dưới 5 phút

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isExpiringSoon ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpiringSoon ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time_filled,
            size: 20,
            color: isExpiringSoon ? Colors.red : AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Phòng đang được tạm giữ cho bạn',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark),
                ),
                Text(
                  'Vui lòng chuyển khoản trong thời gian để giữ phòng',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isExpiringSoon ? Colors.red : AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _formatDuration(_secondsRemaining),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'MBBANK',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'NAPAS 24/7',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'VIETQR THẬT',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Quét mã QR bằng App Ngân Hàng để chuyển khoản',
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 14),

          // Khung hiển thị mã QR thật
          Semantics(
            image: true,
            label: 'Mã QR thanh toán chuyển khoản ngân hàng MBBank, số tài khoản ${VietQRHelper.defaultAccountNo}, chủ tài khoản ${VietQRHelper.defaultAccountDisplayName}, số tiền ${NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(widget.paymentAmount)}, nội dung: $_transferContent',
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
              ),
              child: _useVectorQrFallback
                  ? QrImageView(
                      data: _emvcoPayload,
                      version: QrVersions.auto,
                      size: 240.0,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.primary),
                      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                    )
                  : CachedNetworkImage(
                      imageUrl: _qrImageUrl,
                      height: 260,
                      width: 260,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => SizedBox(
                        height: 240,
                        width: 240,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              const SizedBox(height: 10),
                              Text('Đang tạo mã VietQR thật...', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) {
                        // Tự động chuyển sang fallback QrImageView offline
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _useVectorQrFallback = true);
                        });
                        return QrImageView(
                          data: _emvcoPayload,
                          version: QrVersions.auto,
                          size: 240.0,
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Quét mã sẽ TỰ ĐỘNG ĐIỀN đúng số tài khoản, tên chủ thẻ và số tiền',
            style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBankDetailsCard(NumberFormat currencyFmt) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
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
          const Row(
            children: [
              Icon(Icons.account_balance, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'THÔNG TIN CHUYỂN KHOẢN THỦ CÔNG',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
              ),
            ],
          ),
          const Divider(height: 20),

          // Ngân hàng
          _buildInfoTile(
            label: 'Ngân hàng thụ hưởng',
            value: VietQRHelper.defaultBankName,
            isBold: true,
          ),
          const SizedBox(height: 10),

          // Số tài khoản
          _buildCopyableTile(
            label: 'Số tài khoản',
            value: VietQRHelper.defaultAccountNo,
            copyText: VietQRHelper.defaultAccountNo,
            isHighlight: true,
          ),
          const SizedBox(height: 10),

          // Chủ tài khoản
          _buildCopyableTile(
            label: 'Chủ tài khoản',
            value: VietQRHelper.defaultAccountDisplayName,
            copyText: VietQRHelper.defaultAccountDisplayName,
            isBold: true,
          ),
          const SizedBox(height: 10),

          // Số tiền
          _buildCopyableTile(
            label: 'Số tiền thanh toán',
            value: currencyFmt.format(widget.paymentAmount),
            copyText: widget.paymentAmount.toInt().toString(),
            isHighlight: true,
            highlightColor: const Color(0xFFDC2626),
          ),
          const SizedBox(height: 10),

          // Nội dung chuyển khoản
          _buildCopyableTile(
            label: 'Nội dung chuyển khoản (Mã ID người dùng)',
            value: _transferContent,
            copyText: _transferContent,
            isBold: true,
            isHighlight: true,
            highlightColor: AppColors.primary,
            subtitle: 'Mã 5 ký tự giúp Admin dễ dàng tìm kiếm & kích hoạt đơn',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({required String label, required String value, bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildCopyableTile({
    required String label,
    required String value,
    required String copyText,
    String? subtitle,
    bool isBold = false,
    bool isHighlight = false,
    Color? highlightColor,
  }) {
    return Semantics(
      button: true,
      label: '$label: $value. Chạm để sao chép',
      child: InkWell(
        onTap: () => _copyToClipboard(copyText, label),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: isHighlight ? 16 : 14,
                        fontWeight: (isBold || isHighlight) ? FontWeight.bold : FontWeight.w600,
                        color: highlightColor ?? (isHighlight ? AppColors.primary : AppColors.textDark),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 10.5, color: AppColors.primary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.copy, size: 14, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text('Sao chép', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Color(0xFF1D4ED8)),
              SizedBox(width: 6),
              Text(
                'Lưu ý thanh toán an toàn',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1D4ED8)),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            '• Quét mã QR hoặc nhập chính xác STK 0382542737 tại MBBank.\n'
            '• Giữ đúng nội dung chuyển khoản để hệ thống tự động đối soát.\n'
            '• Sau khi chuyển tiền, nhấn nút "Tôi đã chuyển khoản thành công" bên dưới.',
            style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF1E3A8A)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    final isExpired = _secondsRemaining <= 0;

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
        child: SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isExpired ? Colors.grey : AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: (_isConfirming || isExpired) ? null : _onConfirmPayment,
            child: _isConfirming
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isExpired ? Icons.timer_off : Icons.check_circle_outline, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        isExpired ? 'Hết Hạn Giữ Phòng (Đặt Lại)' : 'Tôi Đã Chuyển Khoản Thành Công',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
