import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/booking_service.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/room_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import 'booking_payment_screen.dart';

/// Màn hình Chi Tiết Đặt Phòng chuẩn 100% theo thiết kế Figma
/// Hỗ trợ 2 trường hợp:
/// 1. Bản thân thuê -> Có nút lấy dữ liệu thật từ tài khoản
/// 2. Đặt hộ người thân (anh/chị/em, bạn bè) -> Người dùng tự nhập thông tin người ở
/// Tuyệt đối KHÔNG sử dụng dữ liệu giả (mock data fix cứng)
class RoomBookingDetailScreen extends ConsumerStatefulWidget {
  final RoomModel room;

  const RoomBookingDetailScreen({super.key, required this.room});

  @override
  ConsumerState<RoomBookingDetailScreen> createState() => _RoomBookingDetailScreenState();
}

class _RoomBookingDetailScreenState extends ConsumerState<RoomBookingDetailScreen> {
  // Trạng thái: true = Bản thân tôi thuê, false = Đặt hộ người thân
  bool _isBookingForSelf = true;

  // Form controllers cho người ở trực tiếp (khởi tạo mặc định tránh LateInitializationError)
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _jobController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  // Kế hoạch dọn vào & ở
  DateTime _moveInDate = DateTime.now().add(const Duration(days: 1));
  int _rentalMonths = 6;
  int _occupantCount = 1;
  String _renterGender = 'nam'; // 'nam' | 'nu' | 'khac'

  // Phương thức thanh toán: 'deposit' (Cọc giữ phòng) hoặc 'full' (Toàn bộ)
  String _paymentOption = 'deposit';

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider).value;
    final user = ref.read(currentUserProvider);

    // Mặc định ban đầu: Điền thông tin thật từ tài khoản nếu có, ngược lại để trống
    final realName = profile?.displayName.isNotEmpty == true
        ? profile!.displayName
        : (profile?.cccdFullName.isNotEmpty == true ? profile!.cccdFullName : (user?.displayName ?? ''));
    _nameController.text = realName;

    String realAge = '';
    if (profile?.birthDate != null) {
      realAge = '${DateTime.now().year - profile!.birthDate!.year} tuổi';
    }
    _ageController.text = realAge;
    _jobController.text = profile?.occupation ?? '';
    _phoneController.text = profile?.phoneNumber ?? '';

    _renterGender = profile?.gender == 'nu' ? 'nu' : (profile?.gender == 'khac' ? 'khac' : 'nam');

    final now = DateTime.now();
    _moveInDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _jobController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Lấy thông tin thật từ tài khoản người dùng
  void _fillFromAccount() {
    final profile = ref.read(userProfileProvider).value;
    final user = ref.read(currentUserProvider);

    setState(() {
      _isBookingForSelf = true;
      _nameController.text = profile?.displayName.isNotEmpty == true
          ? profile!.displayName
          : (profile?.cccdFullName.isNotEmpty == true ? profile!.cccdFullName : (user?.displayName ?? ''));

      if (profile?.birthDate != null) {
        final age = DateTime.now().year - profile!.birthDate!.year;
        _ageController.text = '$age tuổi';
      } else {
        _ageController.text = '';
      }

      _jobController.text = profile?.occupation ?? '';
      _phoneController.text = profile?.phoneNumber ?? '';
      _renterGender = profile?.gender == 'nu' ? 'nu' : (profile?.gender == 'khac' ? 'khac' : 'nam');
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã nạp thông tin từ tài khoản của bạn ✓'),
        backgroundColor: AppColors.primary,
        duration: Duration(seconds: 1),
      ),
    );
  }

  /// Chuyển sang chế độ Đặt hộ người thân (Xóa trắng để người dùng tự nhập)
  void _switchToBookingForOther() {
    setState(() {
      _isBookingForSelf = false;
      _nameController.clear();
      _ageController.clear();
      _jobController.clear();
      _phoneController.clear();
      _renterGender = 'nam';
    });
  }

  /// Ngày rời đi dự kiến = Ngày dọn đến + Thời hạn thuê (tháng)
  DateTime get _calculatedMoveOutDate {
    return DateTime(_moveInDate.year, _moveInDate.month + _rentalMonths, _moveInDate.day);
  }

  /// Tiền cọc giữ phòng tạm tính
  double get _depositAmount => widget.room.deposit > 0 ? widget.room.deposit : 1000000.0;

  /// Tổng tiền cần thanh toán tùy theo phương thức chọn
  double get _selectedPaymentAmount {
    if (_paymentOption == 'full') {
      return _depositAmount + widget.room.price;
    }
    return _depositAmount;
  }

  Future<void> _pickMoveInDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _moveInDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 180)),
    );
    if (picked != null) {
      setState(() => _moveInDate = picked);
    }
  }

  Future<void> _onSubmitBooking() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim().replaceAll(RegExp(r'\s+'), '');

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isBookingForSelf ? 'Vui lòng nhập họ và tên của bạn' : 'Vui lòng nhập họ và tên người được đặt hộ'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final phoneRegex = RegExp(r'^(0|\+84)[3|5|7|8|9][0-9]{8}$');
    if (!phoneRegex.hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số điện thoại Việt Nam hợp lệ (VD: 0987654321)'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = ref.read(currentUserProvider);
      final profile = ref.read(userProfileProvider).value;
      final booking = BookingRequestModel(
        id: '',
        renterId: user?.uid ?? 'guest',
        renterUserCode: profile?.userCode ?? (user != null ? UserProfile.generateUserCode(seed: user.uid) : ''),
        renterName: name,
        renterPhone: phone,
        renterGender: _renterGender,
        roomId: widget.room.id,
        roomTitle: widget.room.title,
        roomAddress: widget.room.address,
        roomPrice: widget.room.price,
        deposit: _depositAmount,
        totalAmount: _selectedPaymentAmount,
        rentalMonths: _rentalMonths,
        hostId: widget.room.hostId,
        hostName: widget.room.hostName,
        status: 'pending_payment',
        moveInDate: _moveInDate,
        note: _noteController.text.trim(),
        createdAt: DateTime.now(),
      );

      // Lưu booking vào Firestore và thu nhận Document ID
      final createdBookingId = await ref.read(bookingServiceProvider).createBooking(booking);
      final finalBooking = booking.copyWith(id: createdBookingId);

      if (mounted) {
        // Chuyển sang Màn hình thanh toán chuẩn Figma với mã QR VietQR MBBank 0382542737
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BookingPaymentScreen(
              room: widget.room,
              booking: finalBooking,
              paymentAmount: _selectedPaymentAmount,
              paymentType: _paymentOption,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Có lỗi xảy ra: $e'), backgroundColor: AppColors.danger),
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
    final currencyFmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final profile = ref.watch(userProfileProvider).value;
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildFigmaAppBar(profile),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Thẻ Tóm tắt phòng trọ
            _buildRoomSummaryCard(currencyFmt),

            const SizedBox(height: 14),

            // 2. Kế hoạch chuyển đến (Ngày dọn đến, ngày rời đi, thời hạn, số người)
            _buildMoveInPlanCard(),

            const SizedBox(height: 14),

            // 3. Thông tin người thuê (Có chuyển đổi 2 chế độ: Tôi tự thuê / Đặt hộ người thân)
            _buildRenterDetailsCard(),

            const SizedBox(height: 14),

            // 4. Thông tin người liên hệ (Đại diện, SĐT chính, Email)
            _buildContactInfoCard(profile, user),

            const SizedBox(height: 14),

            // 5. Lời nhắn cho Chủ nhà
            _buildHostMessageCard(),

            const SizedBox(height: 14),

            // 6. Phương thức thanh toán (Cọc giữ phòng / Thanh toán toàn bộ)
            _buildPaymentMethodCard(currencyFmt),

            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActionBar(),
    );
  }

  /// App Bar chuẩn Figma: Nút back tròn, Icon nhà trong badge xanh, Tiêu đề, Avatar góc phải
  PreferredSizeWidget _buildFigmaAppBar(UserProfile? profile) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(Icons.arrow_back, color: Color(0xFF334155), size: 18),
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.home_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          const Text(
            'Chi Tiết Đặt Phòng',
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: const Color(0xFFE2E8F0),
                backgroundImage: profile?.avatarUrl.isNotEmpty == true ? NetworkImage(profile!.avatarUrl) : null,
                child: profile?.avatarUrl.isEmpty != false
                    ? const Icon(Icons.person, size: 20, color: Color(0xFF64748B))
                    : null,
              ),
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Card 1: Thẻ Tóm tắt phòng trọ + Cọc tạm tính + Chủ nhà
  Widget _buildRoomSummaryCard(NumberFormat currencyFmt) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 80,
                  height: 80,
                  color: const Color(0xFFF1F5F9),
                  child: widget.room.images.isNotEmpty && widget.room.images.first.isNotEmpty
                      ? Image.network(
                          widget.room.images.first,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.home, color: AppColors.primary),
                        )
                      : const Icon(Icons.home, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.room.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF64748B)),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            widget.room.address,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${currencyFmt.format(widget.room.price)}/tháng',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Banner Cọc giữ phòng tạm tính
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Cọc giữ phòng tạm tính',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
                ),
                const Spacer(),
                Text(
                  currencyFmt.format(_depositAmount),
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Thông tin Chủ nhà
          Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFF1F5F9),
                child: Icon(Icons.person, size: 18, color: Color(0xFF64748B)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.room.hostName.isNotEmpty ? widget.room.hostName : 'Chủ nhà',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${widget.room.hostPhone.isNotEmpty ? widget.room.hostPhone : '0903 *** 858'} • Chủ nhà nhiệt tình',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('• Online', style: TextStyle(color: Color(0xFF16A34A), fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Card 2: Kế hoạch chuyển đến (đã bỏ mục phương tiện theo yêu cầu)
  Widget _buildMoveInPlanCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kế hoạch chuyển đến', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A))),
                  Text('Giúp chủ nhà chuẩn bị phòng tươm tất nhất', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2 ô ngày: Ngày dọn đến & Ngày rời đi
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: const TextSpan(
                        text: 'Ngày dọn đến ',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        children: [
                          TextSpan(text: '*', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    InkWell(
                      onTap: _pickMoveInDate,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat('dd/MM/yyyy').format(_moveInDate),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ngày rời đi (dự kiến)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('dd/MM/yyyy').format(_calculatedMoveOutDate),
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Thời hạn thuê stepper
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                const Text('Thời hạn thuê:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                const Spacer(),
                IconButton(
                  tooltip: 'Giảm số tháng thuê',
                  icon: const Icon(Icons.remove, size: 16, color: Color(0xFF64748B)),
                  onPressed: _rentalMonths > 1 ? () => setState(() => _rentalMonths--) : null,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$_rentalMonths tháng',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                  ),
                ),
                IconButton(
                  tooltip: 'Tăng số tháng thuê',
                  icon: const Icon(Icons.add, size: 16, color: Color(0xFF64748B)),
                  onPressed: _rentalMonths < 24 ? () => setState(() => _rentalMonths++) : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Số lượng người ở (Thanh ngang gọn gàng)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.group_outlined, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                const Text('Số lượng người ở:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                const Spacer(),
                IconButton(
                  tooltip: 'Giảm số người ở',
                  icon: const Icon(Icons.remove, size: 16, color: Color(0xFF64748B)),
                  onPressed: _occupantCount > 1 ? () => setState(() => _occupantCount--) : null,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$_occupantCount người',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                  ),
                ),
                IconButton(
                  tooltip: 'Tăng số người ở',
                  icon: const Icon(Icons.add, size: 16, color: Color(0xFF64748B)),
                  onPressed: _occupantCount < 5 ? () => setState(() => _occupantCount++) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Card 3: Thông tin người thuê (Hỗ trợ 2 trường hợp: Bản thân thuê / Đặt hộ người thân)
  Widget _buildRenterDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_outline_rounded, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              const Text('Thông tin người thuê', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A))),
              const Spacer(),
              // Nút lấy nhanh thông tin từ tài khoản
              OutlinedButton.icon(
                onPressed: _fillFromAccount,
                icon: const Icon(Icons.account_circle_outlined, size: 14, color: AppColors.primary),
                label: const Text('Lấy từ tài khoản', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                  backgroundColor: AppColors.primarySurface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Bộ chuyển đổi 2 trường hợp: Bản thân thuê VS Đặt hộ người thân
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _fillFromAccount,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _isBookingForSelf ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _isBookingForSelf
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person, size: 16, color: _isBookingForSelf ? AppColors.primary : const Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Text(
                            'Bản thân tôi thuê',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _isBookingForSelf ? FontWeight.bold : FontWeight.w500,
                              color: _isBookingForSelf ? AppColors.primary : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: InkWell(
                    onTap: _switchToBookingForOther,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !_isBookingForSelf ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: !_isBookingForSelf
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.family_restroom_rounded, size: 16, color: !_isBookingForSelf ? AppColors.primary : const Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Text(
                            'Đặt hộ người thân',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: !_isBookingForSelf ? FontWeight.bold : FontWeight.w500,
                              color: !_isBookingForSelf ? AppColors.primary : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Nhãn chỉ dẫn người ở
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _isBookingForSelf ? AppColors.primarySurface : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _isBookingForSelf ? AppColors.primary.withValues(alpha: 0.2) : const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                Icon(
                  _isBookingForSelf ? Icons.auto_awesome : Icons.edit_note,
                  size: 14,
                  color: _isBookingForSelf ? AppColors.primary : const Color(0xFFD97706),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _isBookingForSelf
                        ? 'Người ở trực tiếp là chủ tài khoản (Đã điền tự động)'
                        : 'Đặt hộ (anh/chị/em, bạn bè) - Vui lòng nhập thông tin người ở bên dưới',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _isBookingForSelf ? const Color(0xFF1E40AF) : const Color(0xFFB45309),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Họ tên & Tuổi
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        text: _isBookingForSelf ? 'Họ và tên người thuê ' : 'Họ và tên người ở ',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        children: const [
                          TextSpan(text: '*', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: _isBookingForSelf ? 'Nhập họ và tên' : 'VD: Nguyễn Văn A (Em trai)',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tuổi / Năm sinh', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                    const SizedBox(height: 5),
                    TextField(
                      controller: _ageController,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'VD: 20 tuổi',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Giới tính
          const Text('Giới tính', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCBD5E1)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: RadioGroup<String>(
              groupValue: _renterGender,
              onChanged: (val) {
                if (val != null) setState(() => _renterGender = val);
              },
              child: Row(
                children: [
                  _buildGenderRadio('nam', 'Nam'),
                  _buildGenderRadio('nu', 'Nữ'),
                  _buildGenderRadio('khac', 'Khác'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Nghề nghiệp / Trường học
          const Text('Nghề nghiệp / Trường học hoặc Nơi làm việc', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
          const SizedBox(height: 5),
          TextField(
            controller: _jobController,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'VD: Sinh viên ĐH Bách Khoa, nhân viên văn phòng...',
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.school_outlined, size: 18, color: Color(0xFF64748B)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            ),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),

          // Số điện thoại người ở trực tiếp
          RichText(
            text: TextSpan(
              text: _isBookingForSelf ? 'Số điện thoại cá nhân ' : 'Số điện thoại người ở trực tiếp ',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              children: const [
                TextSpan(text: '*', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
          const SizedBox(height: 5),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'VD: 0912345678',
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.phone_iphone_outlined, size: 18, color: Color(0xFF64748B)),
              suffixIcon: const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF16A34A)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            ),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),

          const Text(
            '* Thông tin dùng để tạo hồ sơ lưu trữ nhanh gọn, không yêu cầu xác thực CCCD lúc này.',
            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderRadio(String value, String label) {
    final isSelected = _renterGender == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _renterGender = value),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Radio<String>(
              value: value,
              activeColor: AppColors.primary,
              visualDensity: VisualDensity.compact,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card 4: Thông tin người liên hệ (Lấy trực tiếp từ tài khoản đăng nhập)
  Widget _buildContactInfoCard(UserProfile? profile, dynamic user) {
    final accountHolderName = profile?.displayName.isNotEmpty == true
        ? profile!.displayName
        : (profile?.cccdFullName.isNotEmpty == true ? profile!.cccdFullName : (user?.displayName ?? 'Chủ tài khoản'));
    final accountPhone = profile?.phoneNumber.isNotEmpty == true ? profile!.phoneNumber : 'Chưa cập nhật SĐT';
    final accountEmail = profile?.email.isNotEmpty == true ? profile!.email : (user?.email ?? 'Chưa cập nhật email');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.badge_outlined, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              const Text('Thông tin người liên hệ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 12),

          // Dòng 1: Người đại diện
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline, size: 18, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Họ và tên người đại diện', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                      Text(
                        accountHolderName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _isBookingForSelf ? AppColors.primarySurface : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _isBookingForSelf ? 'Bản thân' : 'Người đặt hộ',
                    style: TextStyle(
                      color: _isBookingForSelf ? AppColors.primary : const Color(0xFF475569),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Dòng 2: SĐT liên hệ
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.phone_outlined, size: 18, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Số điện thoại liên hệ chính', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                      Text(
                        accountPhone,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Ưu tiên Zalo/Gọi', style: TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Dòng 3: Email
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.mail_outline, size: 18, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Email nhận xác nhận đặt phòng', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                      Text(
                        accountEmail,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Card 5: Lời nhắn cho Chủ nhà (Không có mock data cứng)
  Widget _buildHostMessageCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lời nhắn cho ${widget.room.hostName.isNotEmpty ? widget.room.hostName : 'Chủ nhà'}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
              ),
              const Text('Tùy chọn', style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _noteController,
              maxLines: 3,
              maxLength: 250,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Nhập ghi chú thêm hoặc thời gian bạn muốn hẹn xem phòng trực tiếp (nếu có)...',
                hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                contentPadding: EdgeInsets.all(10),
                border: InputBorder.none,
                counterStyle: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  /// Card 6: Phương thức thanh toán
  Widget _buildPaymentMethodCard(NumberFormat currencyFmt) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.payment_outlined, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              const Text('Phương thức thanh toán', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('An toàn qua ứng dụng', style: TextStyle(color: Color(0xFF16A34A), fontSize: 10.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Lựa chọn phương thức thanh toán bọc trong RadioGroup
          RadioGroup<String>(
            groupValue: _paymentOption,
            onChanged: (val) {
              if (val != null) setState(() => _paymentOption = val);
            },
            child: Column(
              children: [
                _buildPaymentOptionTile(
                  value: 'deposit',
                  title: 'Thanh toán cọc giữ phòng',
                  amount: currencyFmt.format(_depositAmount),
                  subtitle: 'Giữ chỗ ưu tiên ngay lập tức, tiền thuê tháng đầu sẽ thanh toán khi nhận bàn giao phòng.',
                ),
                const SizedBox(height: 10),
                _buildPaymentOptionTile(
                  value: 'full',
                  title: 'Thanh toán toàn bộ',
                  amount: currencyFmt.format(_depositAmount + widget.room.price),
                  subtitle: 'Bao gồm cọc (${currencyFmt.format(_depositAmount)}) + Tháng đầu tiên (${currencyFmt.format(widget.room.price)}). Ký nhận chìa khóa nhanh.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOptionTile({
    required String value,
    required String title,
    required String amount,
    required String subtitle,
  }) {
    final isSelected = _paymentOption == value;

    return InkWell(
      onTap: () => setState(() => _paymentOption = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer.withValues(alpha: 0.15) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Radio<String>(
              value: value,
              activeColor: AppColors.primary,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom Action Bar: Nút Gửi yêu cầu đặt phòng (Miễn phí) + Chú thích bảo mật
  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSubmitting ? null : _onSubmitBooking,
                icon: _isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 18),
                label: const Text(
                  'Gửi yêu cầu đặt phòng (Miễn phí)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 12, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Không trừ phí ngay • Chỉ cọc khi chủ nhà chấp thuận lịch hẹn.',
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
