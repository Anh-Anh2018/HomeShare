import '../../../data/models/booking_model.dart';
import '../../auth/providers/user_provider.dart';

/// Dữ liệu thống kê hoạt động của Người thuê dựa trên danh sách đơn thuê và lịch hẹn thực tế
class ProfileOverviewStats {
  /// Tổng số đơn đặt phòng và lịch xem phòng
  final int totalBookings;

  /// Số đơn đang trong tiến trình xử lý / chờ xác nhận / đã duyệt / đã thanh toán
  /// Status: pending, pending_payment, approved, paid (hoặc alias tiếng Việt)
  final int pendingCount;

  /// Số phòng đang thuê thực tế (hợp đồng đang hoạt động)
  /// Status: active (hoặc alias tiếng Việt)
  final int activeCount;

  const ProfileOverviewStats({
    this.totalBookings = 0,
    this.pendingCount = 0,
    this.activeCount = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileOverviewStats &&
          runtimeType == other.runtimeType &&
          totalBookings == other.totalBookings &&
          pendingCount == other.pendingCount &&
          activeCount == other.activeCount;

  @override
  int get hashCode =>
      totalBookings.hashCode ^ pendingCount.hashCode ^ activeCount.hashCode;
}

/// Helper tính toán các chỉ số thống kê và tỷ lệ hoàn thiện hồ sơ người dùng
class ProfileOverviewHelper {
  /// Tập các trạng thái được tính vào "Đang chờ / Đang xử lý"
  static const Set<String> _pendingStatuses = {
    'pending',
    'pending_payment',
    'approved',
    'paid',
    'choduyet',
    'cho_duyet',
    'daduyet',
    'da_duyet',
    'chothanhtoan',
    'cho_thanh_toan',
  };

  /// Tập các trạng thái được tính vào "Đang thuê"
  static const Set<String> _activeStatuses = {'active', 'dango', 'dang_o'};

  /// Tính toán thống kê hoạt động từ danh sách đơn thuê thực tế
  static ProfileOverviewStats calculateStats(
    List<BookingRequestModel>? bookings,
  ) {
    if (bookings == null || bookings.isEmpty) {
      return const ProfileOverviewStats();
    }

    int pending = 0;
    int active = 0;

    for (final booking in bookings) {
      final normalizedStatus = booking.status.trim().toLowerCase();
      if (_pendingStatuses.contains(normalizedStatus)) {
        pending++;
      } else if (_activeStatuses.contains(normalizedStatus)) {
        active++;
      }
    }

    return ProfileOverviewStats(
      totalBookings: bookings.length,
      pendingCount: pending,
      activeCount: active,
    );
  }

  /// 6 trường tiêu chí đánh giá mức độ hoàn thiện hồ sơ người dùng:
  /// 1. displayName: Đã cập nhật và khác giá trị mặc định 'Người dùng HomeShare'
  /// 2. email: Không rỗng
  /// 3. phoneNumber: Không rỗng
  /// 4. address: Không rỗng
  /// 5. avatarUrl: Không rỗng
  /// 6. isCccdVerified: Đã xác thực eKYC thành công (true)
  static int countCompletedFields(UserProfile? profile) {
    if (profile == null) return 0;

    int completed = 0;

    final trimmedName = profile.displayName.trim();
    if (trimmedName.isNotEmpty && trimmedName != 'Người dùng HomeShare') {
      completed++;
    }

    if (profile.email.trim().isNotEmpty) {
      completed++;
    }

    if (profile.phoneNumber.trim().isNotEmpty) {
      completed++;
    }

    if (profile.address.trim().isNotEmpty) {
      completed++;
    }

    if (profile.avatarUrl.trim().isNotEmpty) {
      completed++;
    }

    if (profile.isCccdVerified) {
      completed++;
    }

    return completed;
  }

  /// Tỷ lệ hoàn thiện hồ sơ dạng số thực từ 0.0 đến 1.0 (cho LinearProgressIndicator)
  static double calculateCompletionRatio(UserProfile? profile) {
    if (profile == null) return 0.0;
    final completed = countCompletedFields(profile);
    return completed / 6.0;
  }

  /// Tỷ lệ phần trăm hoàn thiện hồ sơ từ 0% đến 100%
  static int calculateCompletionPercentage(UserProfile? profile) {
    if (profile == null) return 0;
    final ratio = calculateCompletionRatio(profile);
    return (ratio * 100).round();
  }
}
