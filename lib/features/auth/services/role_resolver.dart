/// Lớp xử lý chuẩn hóa và phân giải vai trò người dùng (Role Resolution)
/// Nguồn chân lý: SRS/SDS, Database homeShare DrawIO pkg_0, tiendo.md
class RoleResolver {
  static const String renter = 'renter';
  static const String host = 'host';
  static const String admin = 'admin';

  /// Kiểm tra một chuỗi vai trò có thuộc các vai trò hợp lệ của hệ thống hay không
  static bool isValidRole(String? role) {
    if (role == null) return false;
    final normalized = normalizeRole(role);
    return normalized != null;
  }

  /// Chuẩn hóa giá trị vai trò từ dữ liệu thô (chuỗi, số) thành giá trị chuẩn:
  /// - 'renter', 'tenant', 'nguoidung', 'nguoi_dung', 1, '1' -> 'renter'
  /// - 'host', 'landlord', 'chutro', 'chu_tro', 2, '2' -> 'host'
  /// - 'admin', 'administrator', 'quantri', 'quan_tri', 3, '3' -> 'admin'
  ///
  /// Bất kỳ giá trị nào khác (thiếu, rỗng, lạ) sẽ trả về `null` (Fail-closed).
  /// Tuyệt đối không tự động ép về 'renter'.
  static String? normalizeRole(dynamic raw) {
    if (raw == null) return null;
    final str = raw.toString().trim();
    if (str.isEmpty) return null;

    final lower = str.toLowerCase();

    // Nhóm 1: Renter / Người thuê / Ở ghép
    if (lower == 'renter' ||
        lower == 'tenant' ||
        lower == 'nguoidung' ||
        lower == 'nguoi_dung' ||
        lower == '1') {
      return renter;
    }

    // Nhóm 2: Host / Chủ trọ
    if (lower == 'host' ||
        lower == 'landlord' ||
        lower == 'chutro' ||
        lower == 'chu_tro' ||
        lower == '2') {
      return host;
    }

    // Nhóm 3: Admin / Quản trị viên
    if (lower == 'admin' ||
        lower == 'administrator' ||
        lower == 'quantri' ||
        lower == 'quan_tri' ||
        lower == '3') {
      return admin;
    }

    // Không khớp vai trò hợp lệ nào
    return null;
  }

  /// Đọc và chuẩn hóa vai trò từ Map dữ liệu Firestore của bảng Người dùng.
  /// Thứ tự ưu tiên kiểm tra:
  /// 1. `role` (Tiêu chuẩn code)
  /// 2. `vaiTro` (Tiếng Việt DrawIO)
  /// 3. `vaiTro_id` (Khóa ngoại DrawIO / AuthService)
  ///
  /// Trả về `null` nếu không có khóa nào chứa vai trò hợp lệ.
  static String? extractRoleFromMap(Map<String, dynamic>? data) {
    if (data == null) return null;

    const candidateKeys = ['role', 'vaiTro', 'vaiTro_id'];

    for (final key in candidateKeys) {
      if (data.containsKey(key)) {
        final val = data[key];
        if (val != null && val.toString().trim().isNotEmpty) {
          return normalizeRole(val);
        }
      }
    }

    return null;
  }
}

/// Các trạng thái điều hướng đích sau khi xác thực
enum AuthDestination {
  /// Chưa đăng nhập Firebase Auth -> Màn hình đăng nhập
  unauthenticated,

  /// Đang tải thông tin xác thực hoặc hồ sơ người dùng -> Loading
  loading,

  /// Vai trò Người thuê / Ở ghép -> RenterMainScreen
  renter,

  /// Vai trò Chủ trọ -> HostMainScreen
  host,

  /// Vai trò Quản trị viên -> AdminDashboardScreen
  admin,

  /// Vai trò thiếu hoặc không hợp lệ -> InvalidRoleScreen (Fail-closed)
  invalidRole,

  /// Lỗi xảy ra trong quá trình truy vấn hồ sơ -> Màn hình thông báo lỗi
  error,
}

/// Hàm thuần phân giải điều hướng đích dựa trên trạng thái xác thực và vai trò người dùng.
/// Đảm bảo kiểm thử độc lập 100% không phụ thuộc widget tree, Firebase hay provider.
AuthDestination resolveAuthDestination({
  required bool isAuthenticated,
  bool isProfileLoading = false,
  String? role,
  Object? error,
}) {
  if (!isAuthenticated) {
    return AuthDestination.unauthenticated;
  }

  if (error != null) {
    return AuthDestination.error;
  }

  if (isProfileLoading) {
    return AuthDestination.loading;
  }

  final normalizedRole = RoleResolver.normalizeRole(role);
  switch (normalizedRole) {
    case RoleResolver.renter:
      return AuthDestination.renter;
    case RoleResolver.host:
      return AuthDestination.host;
    case RoleResolver.admin:
      return AuthDestination.admin;
    default:
      return AuthDestination.invalidRole;
  }
}
