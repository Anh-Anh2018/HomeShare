import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/room_model.dart';
import '../../../data/models/booking_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../../core/services/booking_service.dart';
import '../../chat/screens/chat_detail_screen.dart';
import 'report_host_screen.dart';
import 'room_booking_detail_screen.dart';

class RoomDetailScreen extends ConsumerStatefulWidget {
  final RoomModel room;

  const RoomDetailScreen({super.key, required this.room});

  @override
  ConsumerState<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends ConsumerState<RoomDetailScreen> {
  int _currentImageIndex = 0;
  bool _isFavorite = false;

  void _onQuickBookingPressed() {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để đặt phòng')),
      );
      return;
    }

    if (user.uid == widget.room.hostId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đây là phòng do chính bạn quản lý')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomBookingDetailScreen(room: widget.room),
      ),
    );
  }

  void _onReportPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportHostScreen(room: widget.room),
      ),
    );
  }

  void _onChatPressed() {
    final currentUser = ref.read(currentUserProvider);
    final profile = ref.read(userProfileProvider).value;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để nhắn tin với chủ trọ')),
      );
      return;
    }

    if (currentUser.uid == widget.room.hostId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đây là phòng do chính bạn quản lý')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          receiverId: widget.room.hostId,
          receiverName: widget.room.hostName,
          receiverPhone: widget.room.hostPhone,
          isLandlord: true,
          currentUserId: currentUser.uid,
          currentUserName: profile?.displayName ?? currentUser.displayName ?? 'Khách thuê',
          pinnedRoom: widget.room,
        ),
      ),
    );
  }

  void _onCallHostPressed() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Số điện thoại chủ nhà'),
        content: Text(
          'Liên hệ trực tiếp với chủ trọ ${widget.room.hostName}:\n\n'
          '📞 ${widget.room.hostPhone}',
          style: const TextStyle(fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat('#,###', 'vi_VN');
    final priceStr = '${currencyFormatter.format(widget.room.price)} đ/tháng';
    final depositStr = '${currencyFormatter.format(widget.room.deposit)} đ';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // 1. App Bar với Image Slider
          SliverAppBar(
            expandedHeight: 280.0,
            pinned: true,
            leading: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Semantics(
                label: 'Quay lại',
                button: true,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textDark, size: 20),
                    tooltip: 'Quay lại',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: Semantics(
                  label: _isFavorite ? 'Bỏ lưu khỏi danh sách yêu thích' : 'Lưu vào danh sách yêu thích',
                  toggled: _isFavorite,
                  button: true,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorite ? Colors.red : AppColors.textDark,
                        size: 20,
                      ),
                      tooltip: _isFavorite ? 'Bỏ lưu yêu thích' : 'Lưu yêu thích',
                      onPressed: () {
                        setState(() => _isFavorite = !_isFavorite);
                      },
                    ),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: widget.room.images.isNotEmpty
                  ? Stack(
                      children: [
                        PageView.builder(
                          itemCount: widget.room.images.length,
                          onPageChanged: (idx) => setState(() => _currentImageIndex = idx),
                          itemBuilder: (context, index) {
                            return Semantics(
                              image: true,
                              label: 'Ảnh phòng trọ ${index + 1} trên ${widget.room.images.length}',
                              child: Image.network(
                                widget.room.images[index],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.apartment, size: 64, color: Colors.grey),
                                ),
                              ),
                            );
                          },
                        ),
                        // Indicator
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${_currentImageIndex + 1}/${widget.room.images.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.apartment, size: 80, color: Colors.grey),
                    ),
            ),
          ),

          // 2. Nội dung chi tiết phòng trọ
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.room.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        label: 'Đánh giá ${widget.room.rating} sao trên ${widget.room.reviewCount} lượt đánh giá',
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF9E6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFFE082)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star, size: 14, color: Color(0xFFFFA000)),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.room.rating}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB78103)),
                              ),
                              Text(
                                ' (${widget.room.reviewCount})',
                                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Address
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.room.address,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Price & Deposit Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Giá thuê phòng', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                            const SizedBox(height: 2),
                            Text(
                              priceStr,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        Container(height: 32, width: 1, color: const Color(0xFFE5E7EB)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tiền đặt cọc', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                            const SizedBox(height: 2),
                            Text(
                              depositStr,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Thông số phòng (Diện tích, Loại phòng, Trạng thái)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSpecItem(Icons.square_foot, '${widget.room.area} m²', 'Diện tích'),
                        _buildSpecDivider(),
                        _buildSpecItem(Icons.home_work_outlined, widget.room.roomType, 'Loại phòng'),
                        _buildSpecDivider(),
                        _buildSpecItem(
                          widget.room.isAvailable ? Icons.check_circle_outline : Icons.cancel_outlined,
                          widget.room.isAvailable ? 'Còn phòng' : 'Hết phòng',
                          'Tình trạng',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Thông tin chủ nhà
                  const Text('Thông tin chủ trọ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.primaryContainer,
                          child: Text(
                            widget.room.hostName.isNotEmpty ? widget.room.hostName[0] : 'H',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 18),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    widget.room.hostName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified, size: 14, color: AppColors.primary),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Chủ nhà đã xác minh • Phản hồi 100%',
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.phone_in_talk, color: AppColors.primary),
                          tooltip: 'Gọi điện chủ trọ',
                          onPressed: _onCallHostPressed,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tiện ích phòng trọ
                  const Text('Tiện ích phòng trọ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.room.amenities.map((amenity) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle, size: 14, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              _getAmenityLabel(amenity),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textDark),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Mô tả chi tiết
                  const Text('Mô tả chi tiết', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      widget.room.description,
                      style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // 3. Bottom Action Bar
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // 1. Nút Báo cáo
              Semantics(
                label: 'Báo cáo vi phạm chủ nhà hoặc phòng trọ',
                button: true,
                excludeSemantics: true,
                child: OutlinedButton.icon(
                  onPressed: _onReportPressed,
                  icon: const Icon(Icons.flag_outlined, color: Color(0xFFDC2626), size: 16),
                  label: const Text(
                    'Báo cáo',
                    style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(78, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    backgroundColor: const Color(0xFFFEF2F2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Nút Nhắn tin
              Semantics(
                label: 'Nhắn tin với chủ nhà',
                button: true,
                excludeSemantics: true,
                child: OutlinedButton.icon(
                  onPressed: _onChatPressed,
                  icon: const Icon(Icons.chat_outlined, color: AppColors.primary, size: 17),
                  label: const Text(
                    'Nhắn tin',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(92, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    side: const BorderSide(color: AppColors.primary, width: 1.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 3. Nút Đặt phòng nhanh
              Expanded(
                child: Semantics(
                  label: 'Đặt phòng nhanh',
                  button: true,
                  excludeSemantics: true,
                  child: ElevatedButton.icon(
                    onPressed: _onQuickBookingPressed,
                    icon: const Icon(Icons.bolt, color: Colors.white, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Đặt phòng nhanh',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        maxLines: 1,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(120, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecItem(IconData icon, String value, String label) {
    return MergeSemantics(
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildSpecDivider() {
    return Container(
      height: 28,
      width: 1,
      color: const Color(0xFFE5E7EB),
    );
  }

  String _getAmenityLabel(String key) {
    switch (key) {
      case 'wifi':
        return 'Wifi tốc độ cao';
      case 'air_conditioner':
        return 'Máy lạnh Inverter';
      case 'fridge':
        return 'Tủ lạnh riêng';
      case 'washer':
        return 'Máy giặt';
      case 'balcony':
        return 'Ban công thoáng';
      case 'loft':
        return 'Gác lửng cao';
      case 'security':
        return 'Bảo vệ / Camera';
      case 'parking':
        return 'Bãi xe trong nhà';
      default:
        return key;
    }
  }
}

// Dedicated StatefulWidget for Booking Bottom Sheet to prevent memory leaks and unmounted crashes
class _BookingBottomSheetModal extends ConsumerStatefulWidget {
  final RoomModel room;

  const _BookingBottomSheetModal({required this.room});

  @override
  ConsumerState<_BookingBottomSheetModal> createState() => _BookingBottomSheetModalState();
}

class _BookingBottomSheetModalState extends ConsumerState<_BookingBottomSheetModal> {
  late final TextEditingController _noteController;
  late DateTime _selectedDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = _selectedDate.isBefore(today) ? today : _selectedDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: today.add(const Duration(days: 60)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _confirmBooking() async {
    setState(() => _isSubmitting = true);
    final user = ref.read(currentUserProvider);
    final profile = ref.read(userProfileProvider).value;

    try {
      final booking = BookingRequestModel(
        id: '',
        renterId: user?.uid ?? 'guest',
        renterUserCode: profile?.userCode ?? (user != null ? UserProfile.generateUserCode(seed: user.uid) : ''),
        renterName: profile?.displayName ?? user?.displayName ?? 'Khách thuê',
        renterPhone: profile?.phoneNumber.isNotEmpty == true ? profile!.phoneNumber : '0981234567',
        renterGender: profile?.gender ?? 'nam',
        roomId: widget.room.id,
        roomTitle: widget.room.title,
        roomAddress: widget.room.address,
        roomPrice: widget.room.price,
        deposit: widget.room.deposit,
        totalAmount: widget.room.price + widget.room.deposit,
        rentalMonths: 1,
        hostId: widget.room.hostId,
        hostName: widget.room.hostName,
        status: 'pending',
        moveInDate: _selectedDate,
        note: _noteController.text.trim(),
        createdAt: DateTime.now(),
      );

      await ref.read(bookingServiceProvider).createBooking(booking);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi yêu cầu đến chủ nhà thành công!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Đặt Lịch Xem Phòng / Thuê Phòng',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            widget.room.title,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),

          // Chọn ngày
          const Text(
            'Ngày dự kiến xem phòng / dọn vào:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: 'Chọn ngày hẹn xem phòng, ngày đang chọn là ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
            button: true,
            child: InkWell(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd/MM/yyyy').format(_selectedDate),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Text(
                      'Thay đổi',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Lời nhắn cho chủ nhà
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Lời nhắn cho chủ nhà (tùy chọn)',
              hintText: 'Ví dụ: Mình là sinh viên muốn qua xem phòng vào buổi chiều...',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 20),

          // Nút xác nhận
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _confirmBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Xác Nhận Gửi Yêu Cầu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
