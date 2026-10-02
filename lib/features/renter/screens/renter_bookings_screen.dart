import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/booking_model.dart';
import '../../../core/services/booking_service.dart';
import '../../auth/providers/auth_provider.dart';

class RenterBookingsScreen extends ConsumerStatefulWidget {
  const RenterBookingsScreen({super.key});

  @override
  ConsumerState<RenterBookingsScreen> createState() => _RenterBookingsScreenState();
}

class _RenterBookingsScreenState extends ConsumerState<RenterBookingsScreen> {
  String _selectedStatusFilter = 'Tất cả';

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'pending':
      case 'pending_payment':
        return AppColors.warning; // Contrast 5.2:1 (Passes WCAG AA)
      case 'paid':
        return AppColors.success; // Contrast 4.5+:1
      case 'approved':
        return AppColors.primary; // Contrast 5.5:1 (Passes WCAG AA)
      case 'active':
        return AppColors.info; // Contrast 4.9:1 (Passes WCAG AA)
      case 'cancelled':
      case 'rejected':
        return AppColors.danger; // Contrast 6.2:1 (Passes WCAG AA)
      default:
        return AppColors.textSecondary;
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case 'pending':
      case 'pending_payment':
        return AppColors.warningContainer;
      case 'paid':
        return AppColors.successContainer;
      case 'approved':
        return AppColors.primaryContainer;
      case 'active':
        return AppColors.infoContainer;
      case 'cancelled':
      case 'rejected':
        return AppColors.dangerContainer;
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending_payment':
        return 'Chờ thanh toán cọc';
      case 'paid':
        return 'Đã thanh toán cọc';
      case 'pending':
        return 'Chờ chủ nhà duyệt';
      case 'approved':
        return 'Đã duyệt • Đã hẹn nhận phòng';
      case 'active':
        return 'Đang thuê (Active)';
      case 'cancelled':
        return 'Đã hủy đơn';
      case 'rejected':
        return 'Chủ nhà từ chối';
      default:
        return status;
    }
  }

  Future<void> _cancelBookingDialog(BookingRequestModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận hủy yêu cầu đặt phòng'),
        content: Text(
          'Bạn có chắc chắn muốn hủy yêu cầu đặt "${booking.roomTitle}" không?\n\n'
          'Lưu ý: Thao tác này không thể hoàn tác và chủ trọ sẽ không còn giữ lịch hẹn này.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Giữ lại yêu cầu'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(bookingServiceProvider).cancelBooking(booking.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã hủy yêu cầu đặt phòng thành công'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi hủy: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final currencyFormatter = NumberFormat('#,###', 'vi_VN');

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Quản lý Đơn Thuê'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'Vui lòng đăng nhập để xem đơn thuê & lịch hẹn',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark),
              ),
            ],
          ),
        ),
      );
    }

    final bookingsAsync = ref.watch(renterBookingsStreamProvider(user.uid));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quản lý Đơn Thuê & Trạng Thái'),
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  'Tất cả',
                  'Chờ duyệt',
                  'Đã duyệt',
                  'Đang ở',
                  'Đã hủy',
                ].map((s) {
                  final isSel = _selectedStatusFilter == s;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ChoiceChip(
                      label: Text(s),
                      selected: isSel,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : AppColors.textDark,
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) => setState(() => _selectedStatusFilter = s),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Danh sách đơn thuê
          Expanded(
            child: bookingsAsync.when(
              data: (bookings) {
                var filtered = bookings;
                if (_selectedStatusFilter == 'Chờ duyệt') {
                  filtered = bookings.where((b) => b.status == 'pending' || b.status == 'pending_payment').toList();
                } else if (_selectedStatusFilter == 'Đã duyệt') {
                  filtered = bookings.where((b) => b.status == 'approved' || b.status == 'paid').toList();
                } else if (_selectedStatusFilter == 'Đang ở') {
                  filtered = bookings.where((b) => b.status == 'active').toList();
                } else if (_selectedStatusFilter == 'Đã hủy') {
                  filtered = bookings.where((b) => b.status == 'cancelled' || b.status == 'rejected').toList();
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text('Không có đơn thuê hoặc lịch hẹn nào', style: TextStyle(color: AppColors.textMuted)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final b = filtered[index];
                    final textColor = _getStatusTextColor(b.status);
                    final bgColor = _getStatusBgColor(b.status);
                    final statusText = _getStatusText(b.status);
                    final priceStr = '${currencyFormatter.format(b.roomPrice)} đ/tháng';

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(radius: 4, backgroundColor: textColor),
                                      const SizedBox(width: 6),
                                      Text(
                                        statusText,
                                        style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  DateFormat('dd/MM/yyyy').format(b.createdAt),
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Room Title
                            Text(
                              b.roomTitle,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              b.roomAddress,
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 8),

                            // Price & Move-in date
                            Row(
                              children: [
                                const Icon(Icons.price_change_outlined, size: 16, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    priceStr,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Dọn vào: ${DateFormat('dd/MM/yyyy').format(b.moveInDate)}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 8),

                            // Landlord info and Action
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.person_pin, size: 18, color: AppColors.textSecondary),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Chủ trọ: ${b.hostName}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                                if (b.status == 'pending' || b.status == 'pending_payment')
                                  Semantics(
                                    label: 'Hủy yêu cầu đặt phòng ${b.roomTitle}',
                                    button: true,
                                    child: TextButton(
                                      onPressed: () => _cancelBookingDialog(b),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.danger,
                                        minimumSize: const Size(80, 44),
                                      ),
                                      child: const Text('Hủy yêu cầu', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Lỗi tải dữ liệu: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
