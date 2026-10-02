import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/booking_model.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Gửi yêu cầu đặt thuê / hẹn xem phòng (Đơn đặt phòng, trả về Document ID)
  Future<String> createBooking(BookingRequestModel booking) async {
    final docRef = await _firestore.collection('bookings').add(booking.toMap());
    return docRef.id;
  }

  // Cập nhật trạng thái thanh toán hoặc trạng thái đơn đặt phòng
  Future<void> updateBookingStatus(String bookingId, String status) async {
    if (bookingId.isEmpty) return;
    await _firestore.collection('bookings').doc(bookingId).update({
      'status': status,
      'trangThai': status == 'paid' ? 'daThanhToan' : status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Stream danh sách đơn thuê của người thuê (an toàn, tránh lỗi composite index bằng in-memory sort)
  Stream<List<BookingRequestModel>> getRenterBookingsStream(String renterId) {
    if (renterId.isEmpty || renterId == 'guest') {
      return Stream.value([]);
    }

    return _firestore
        .collection('bookings')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        try {
          final data = doc.data();
          final docRenterId = data['renterId'] ?? data['nguoiDung_Id'] ?? data['khachXemId'] ?? '';
          if (docRenterId != renterId) return null;
          return BookingRequestModel.fromFirestore(doc);
        } catch (e) {
          debugPrint('Error parsing booking ${doc.id}: $e');
          return null;
        }
      }).whereType<BookingRequestModel>().toList();

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // Hủy đơn thuê (cập nhật cả status và trangThai)
  Future<void> cancelBooking(String bookingId) async {
    await _firestore.collection('bookings').doc(bookingId).update({
      'status': 'cancelled',
      'trangThai': 'daHuy',
    });
  }
}

final bookingServiceProvider = Provider<BookingService>((ref) => BookingService());

final renterBookingsStreamProvider = StreamProvider.autoDispose.family<List<BookingRequestModel>, String>((ref, renterId) {
  final service = ref.watch(bookingServiceProvider);
  return service.getRenterBookingsStream(renterId);
});
