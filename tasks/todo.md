# Danh Sách Đầu Việc (Todo List): Lát Cắt Role-Based Routing

- [x] **Bước 1: Tài liệu & Kế hoạch**
  - [x] Tạo `tasks/plan.md` với bối cảnh, tiêu chí nghiệm thu (AC) và danh sách file dự kiến
  - [x] Tạo `tasks/todo.md` để theo dõi tiến độ chi tiết

- [x] **Bước 2: TDD - Viết Test Suite cho Role Normalization & Resolution trước**
  - [x] Tạo `test/role_routing_test.dart`
  - [x] Kiểm thử đọc các khóa `role`, `vaiTro`, `vaiTro_id`
  - [x] Kiểm thử ánh xạ alias `renter` (`renter`, `tenant`, `nguoiDung`, `1`)
  - [x] Kiểm thử ánh xạ alias `host` (`host`, `landlord`, `chutro`, `2`)
  - [x] Kiểm thử ánh xạ alias `admin` (`admin`, `administrator`, `3`)
  - [x] Kiểm thử độ ưu tiên khóa (`role` > `vaiTro` > `vaiTro_id`)
  - [x] Kiểm thử các trường hợp thiếu/rỗng/sai vai trò (fail-closed, trả về null, không rơi về renter)
  - [x] Kiểm thử hàm thuần `resolveAuthDestination` cho từng trạng thái điều hướng

- [x] **Bước 3: Triển khai Thành phần Thuần Phân Giải Vai Trò**
  - [x] Tạo `lib/features/auth/services/role_resolver.dart` với `RoleResolver`, `UserRole`, `AuthDestination` và `resolveAuthDestination`
  - [x] Cập nhật `lib/features/auth/providers/user_provider.dart`:
    - [x] Dùng `RoleResolver.extractRoleFromMap(data)` trong `UserProfile.fromMap`
    - [x] Xóa bỏ hardcode `role: 'renter'`
    - [x] Bổ sung getter `isAdmin => role == 'admin'` và `hasValidRole`
    - [x] Cập nhật `ActiveRoleNotifier.switchRole` để chuẩn hóa vai trò

- [x] **Bước 4: Tạo Màn Hình Bổ Trợ (InvalidRoleScreen & AdminDashboardScreen Shell)**
  - [x] Tạo `lib/features/auth/screens/invalid_role_screen.dart`:
    - [x] Giao diện cảnh báo vai trò không hợp lệ / tài khoản chưa phân quyền
    - [x] Nút "Đăng xuất" kích hoạt `authService.signOut()`
  - [x] Tạo `lib/features/admin/screens/admin_dashboard_screen.dart`:
    - [x] Shell tối thiểu đúng vai trò Quản trị viên
    - [x] Hiển thị thông tin admin và banner chú thích rõ ràng đây là shell
    - [x] Nút "Đăng xuất" cho quản trị viên

- [x] **Bước 5: Cập Nhật Phân Luồng Trong AuthGate**
  - [x] Cập nhật `lib/main.dart`:
    - [x] `AuthGate` quan sát `authStateProvider` và `userProfileProvider`
    - [x] Xử lý loading và error
    - [x] Điều hướng `renter` -> `RenterMainScreen`
    - [x] Điều hướng `host` -> `HostMainScreen`
    - [x] Điều hướng `admin` -> `AdminDashboardScreen`
    - [x] Thiếu/sai vai trò -> `InvalidRoleScreen` (fail-closed)

- [x] **Bước 6: Cập Nhật Test Cũ & Đảm Bảo Tính Toàn Vẹn**
  - [x] Sửa test `UserProfile parses from DrawIO keys and enforces renter role` trong `test/renter_suite_test.dart`
  - [x] Đảm bảo các test case cũ không còn ép sai dữ liệu thiếu role thành renter

- [x] **Bước 7: Rà Soát & Báo Cáo**
  - [x] Kiểm tra tính tương thích, cú pháp và quy tắc không thêm dependency
  - [x] Tổng hợp danh sách file thay đổi, reasoning, rủi ro và các lệnh kiểm thử đề xuất

- [x] **Bước 8: Hoàn Thiện 4 Điểm Theo Yêu Cầu Review Độc Lập**
  - [x] **REQUIRED 1**: Fail-closed serialization trong `UserProfile.toMap` — chỉ sinh `vaiTro_id` khi role hợp lệ (1/2/3), omit khi role rỗng/sai; thêm regression test toMap & round-trip.
  - [x] **REQUIRED 2**: Xóa circular dependency giữa `role_resolver.dart` và `user_provider.dart` — đổi `resolveAuthDestination` nhận `String? role`, `main.dart` truyền `profile?.role`.
  - [x] **REQUIRED 3**: Xóa hardcode dữ liệu giả trong `AdminDashboardScreen` — fallback email và userCode thành "Chưa cập nhật".
  - [x] **REQUIRED 4**: Không lộ exception nội bộ lên UI — ẩn `$error`/`$e` trong `main.dart`, `AdminDashboardScreen`, `InvalidRoleScreen`, dùng thông báo thân thiện và `debugPrint` không chứa PII.

---

# Lát Cắt: Trang Cá Nhân Cho Người Thuê (Renter Personal Profile Screen)

- [x] **Giai đoạn 1: Foundation & View Model (Model/Helper thuần)**
  - [x] Tạo `lib/features/home/models/profile_overview.dart` với `ProfileOverviewStats` và helper `ProfileOverviewHelper`:
    - [x] `calculateStats(List<BookingRequestModel> bookings)` tính tổng, pending, active
    - [x] `calculateCompletionPercentage(UserProfile? profile)` tính tỷ lệ hoàn thiện hồ sơ trên 6 trường (0-100%)
    - [x] `calculateCompletionRatio(UserProfile? profile)` (0.0-1.0 cho ProgressIndicator)
    - [x] Xử lý an toàn dữ liệu null/rỗng

- [x] **Giai đoạn 2: UI Presentation Widget (PersonalProfileContent)**
  - [x] Tạo `lib/features/home/widgets/personal_profile_content.dart`:
    - [x] Header chuẩn: Avatar (ảnh mạng hoặc initial), tên, badge "Người thuê", ID userCode, email/SĐT khi có, trạng thái eKYC (đã xác thực vs chưa xác thực)
    - [x] Thẻ "Hoàn thiện hồ sơ" với `LinearProgressIndicator` thực tế và nút CTA "Cập nhật hồ sơ"
    - [x] Thẻ "Thống kê hoạt động" hiển thị số liệu thật từ bookings, hỗ trợ trạng thái loading và error thân thiện
    - [x] Menu "Quản lý tài khoản": 4 mục hoạt động (`Đơn thuê & lịch hẹn`, `Xác thực danh tính`, `Cài đặt tài khoản`, `Đăng xuất`)
    - [x] Xóa bỏ triệt để các dead tap (yêu thích, phòng đang thuê, báo sự cố)
    - [x] Dialog xác nhận đăng xuất với nút Hủy và Đăng xuất
    - [x] Đảm bảo tap target >= 44, semantics/tooltip, hỗ trợ màn hình 320px và text scale lớn

- [x] **Giai đoạn 3: Screen Container Wiring & Provider Orchestration**
  - [x] Cập nhật `lib/features/home/screens/home_screen.dart`:
    - [x] Xử lý đầy đủ `AsyncValue` của `userProfileProvider` (loading, error, data, null profile)
    - [x] Lắng nghe `currentUserProvider` và `renterBookingsStreamProvider(user.uid)`
    - [x] Kết nối các callback điều hướng: `AccountSettingsScreen`, `CccdVerificationScreen`, `RenterBookingsScreen`
    - [x] Xử lý đăng xuất an toàn qua `authServiceProvider.signOut()` với thông báo lỗi thân thiện, không lộ `$e`

- [x] **Giai đoạn 4: Unit & Widget Test Suite**
  - [x] Tạo `test/profile_screen_test.dart`:
    - [x] Test helper thống kê booking: empty, all pending, all active, mixed, canceled/rejected
    - [x] Test helper hoàn thiện hồ sơ: 0%, partial (e.g. 50%), 100%
    - [x] Test UI không chứa dữ liệu giả ("08", "02", "01", "user@homeshare.vn")
    - [x] Test hiển thị đúng menu hoạt động và không có dead tap
    - [x] Test trạng thái eKYC verified và unverified
    - [x] Test responsive layout 320x568 không bị overflow

- [x] **Giai đoạn 5: Hoàn Thiện Theo Phản Hồi Review Độc Lập**
  - [x] **REQ 1**: Cập nhật `test/profile_screen_test.dart` dùng `tester.ensureVisible(...)` trước mỗi tap (đặc biệt Đăng xuất) và finder cụ thể `find.descendant` cho dialog.
  - [x] **REQ 2**: Khắc phục RenderFlex overflow 35px: dùng `Wrap` trong Header Card và layout `Expanded + Flexible` trong action rows, chống tràn ở 320x568 và text scale lớn.
  - [x] **REQ 3**: Avatar dùng `Image.network` với `errorBuilder` fallback về initials thật khi URL lỗi/mất mạng.
  - [x] **REQ 4**: Refactor `personal_profile_content.dart` thành 4 widget con độc lập (`ProfileHeaderCard`, `ProfileCompletionCard`, `ProfileStatsCard`, `ProfileActionsCard`), giữ `PersonalProfileContent` < 70 dòng.
  - [x] **REQ 5**: Bổ sung `addTearDown` reset `tester.view`, thêm test avatar URL hỏng và test text scale 1.3x trên 320px.
  - [x] **REQ 6**: Đổi nhãn pending từ "Đang chờ duyệt" sang "Đang xử lý".

- [x] **Giai đoạn 6: Vòng Review Độc Lập Thứ 2 (Khắc phục triệt để Overflow 115px ở 320px + Text Scale 1.3x)**
  - [x] **R2-1**: Sửa tận gốc nguyên nhân tràn 115px: bọc `ConstrainedBox(constraints: BoxConstraints(maxWidth: maxContentWidth))` qua `LayoutBuilder` cho eKYC badge container, Text tên, Text email và SĐT; `Row + Flexible` trong eKYC badge có bound thật để ép ellipsis.
  - [x] **R2-2**: Trong `ProfileCompletionCard`, dùng `Expanded` cho text tiêu đề và `Wrap` cho mô tả + nút "Cập nhật".
  - [x] **R2-3**: Trong `ProfileActionsCard`, dùng `LayoutBuilder` + `ConstrainedBox` cho title và subtitle; badge bọc an toàn trong `Wrap`.
  - [x] **R2-4**: Tách test responsive thành các test cô lập từng component (Header unverified, Header verified, Header chuỗi dài, Completion, Stats, Actions) và test Composition tổng.
  - [x] **R2-5**: Đảm bảo toàn bộ test responsive dùng `addTearDown` reset `tester.view` và giữ nguyên tiêu chí khắt khe `expect(tester.takeException(), isNull)` ở 320x568 + 1.3x text scale.

- [x] **Giai đoạn 7: Vòng Sửa Lỗi Analyzer (Khắc phục 2 diagnostics từ flutter analyze)**
  - [x] **ANA-1 (ERROR)**: `lib/features/home/screens/home_screen.dart:87`: Đổi `bookingsAsync?.valueOrNull` thành `bookingsAsync?.asData?.value` tương thích với API Riverpod của dự án, giữ fail-safe null khi loading/error không gây throw.
  - [x] **ANA-2 (INFO)**: `lib/features/auth/providers/user_provider.dart:201`: Refactor `if (vaiTroId != null) 'vaiTro_id': vaiTroId` thành cú pháp null-aware element `'vaiTro_id': ?vaiTroId`, bảo toàn 100% logic fail-closed (chỉ emit khi `vaiTroId` non-null).

---

# Lát Cắt: Xác Thực 2 Mặt Ảnh CCCD Trước Khi Lưu (CCCD Image Evidence Validation & Save Boundary)

- [x] **Giai đoạn 1: Kế Hoạch & Thiết Kế Kiến Trúc (Planning & Security Boundaries)**
  - [x] Xác định nguyên tắc bảo mật: fail-closed, on-device validation, zero PII logging, không tin filename/MIME, cách ly demo image, save boundary tái thẩm định.
  - [x] Cập nhật `tasks/plan.md` và `tasks/todo.md` với vertical slice, acceptance criteria (AC 1-5), rủi ro & điểm kiểm soát.

- [x] **Giai đoạn 2: TDD RED - Contract Models & Skeleton Validator**
  - [x] Tạo `lib/features/profile/models/cccd_validation_models.dart`:
    - [x] `enum CccdImageSide { front, back }`
    - [x] `CccdValidationReasonCodes`: Bộ mã lỗi an toàn không chứa PII
    - [x] Immutable `CccdImageEvidence`: side, normalized OCR text, qrPayload, imageByteHash, width, height, byteLength, filePath, isDemo
    - [x] Immutable `CccdImageValidationResult`: isValid, detectedSide, strictData, reasonCode, toString/log an toàn không chứa PII
    - [x] Immutable `CccdValidationProof`: frontEvidence, backEvidence, verifiedData, isValid, rejectionReasonCode, version, isDemo
  - [x] Tạo `lib/features/profile/services/cccd_image_evidence_validator.dart`:
    - [x] Skeleton `CccdImageEvidenceValidator` với public API: `validateStrictQr`, `validateEvidence`, `createProof`, `canSave`
    - [x] Đặt `UnimplementedError` cho mọi method nghiệp vụ để phục vụ giai đoạn RED (compile sạch nhưng test fail)

- [x] **Giai đoạn 3: TDD RED - Bộ Kiểm Thử 10 Test Cases trong `test/cccd_image_validation_test.dart`**
  - [x] Test 1: Strict QR hợp lệ đủ 7 trường, ID 12 số, tên/địa chỉ không rỗng, ngày sinh/ngày cấp hợp lệ
  - [x] Test 2: Reject chuỗi 12 số đơn lẻ, QR thiếu trường, ngày sai logic, ID sai định dạng
  - [x] Test 3: Mặt trước chỉ valid khi có QR strict + dấu hiệu mặt trước; reject ảnh thường và mặt sau
  - [x] Test 4: Mặt sau chỉ valid khi có >=2 dấu hiệu đặc trưng (Đặc điểm nhận dạng, Bộ Công An, MRZ-like); reject mặt trước
  - [x] Test 5: Reject ảnh quá nhỏ (<20KB), quá lớn (>15MB), độ phân giải thấp (<600x400), hash rỗng
  - [x] Test 6: Reject hai mặt cùng hash byte
  - [x] Test 7: Proof hợp lệ mới cho phép save; thiếu mặt/invalid/wrong-side/duplicate đều bị chặn
  - [x] Test 8: Reason code và log/toString không chứa raw OCR, số CCCD, path/URL
  - [x] Test 9: Ảnh demo (`demo_cccd_*`) không bao giờ tạo proof hợp lệ và không thể save
  - [x] Test 10: Legacy URL không có validation metadata/version không được coi là proof cho lần lưu mới

- [x] **Giai đoạn 4: TDD GREEN - Triển Khai Logic Validator & Thuật Toán Xác Thực**
  - [x] Implement `validateStrictQr` với regex 7 trường và kiểm tra ngày hợp lệ logic
  - [x] Implement `validateEvidence` kiểm tra độ phân giải, dung lượng, hash, OCR keywords mặt trước/mặt sau
  - [x] Implement `createProof` đối soát duplicate hash, demo flag, và tổng hợp strictData
  - [x] Implement `canSave` save boundary kiểm tra toàn vẹn proof
  - [x] Hoàn thành triển khai logic validator thuần cho bộ test

- [x] **Giai đoạn 5: TDD REFACTOR & Tích Hợp UI/Backend (On-Device OCR/QR & Save Boundary)**
  - [x] On-device OCR/QR: Triển khai `DefaultCccdOcrEngine` bằng `google_mlkit_text_recognition`, bóc tách 100% on-device, đóng tài nguyên an toàn trong `finally`.
  - [x] QR Strict Scanner: Cập nhật `CccdScannerScreen` thẩm định nghiêm ngặt qua `validateStrictQr`, loại bỏ hoàn toàn permissive parsing và bypass "Thử Mẫu".
  - [x] Tích hợp Màn hình eKYC Thật: Cập nhật `CccdVerificationScreen` với `CccdSideValidationStatus` (idle, validating, valid, invalid), trích xuất strict QR từ ảnh mặt trước, loại bỏ toàn bộ bypass demo/chỉnh tay.
  - [x] Save Boundary: Ràng buộc `saveCccdVerificationToBackend` yêu cầu `CccdValidationProof`, upload ảnh từ local path trong proof, từ chối lưu dữ liệu thiếu hoặc sai mặt.
  - [x] Storage Hardening: `ImageStorageService.uploadCccdImage` từ chối URL từ xa (`http://`, `https://`) và Data URI bằng `FormatException` an toàn trước khi gọi Firebase.
  - [x] UI States & Safety: Quản lý trạng thái thẩm định riêng từng mặt, disable picker và nút lưu trong lúc validating, nút lưu chỉ kích hoạt khi `_isComplete` thỏa mãn `canSave`.
  - [x] Unit & Widget Tests: Tạo `test/cccd_save_boundary_test.dart` (tracking storage & URL hardening) và `test/cccd_verification_screen_test.dart` (initial states & disabled submit).
  - [x] Static Analysis: Toàn bộ mã nguồn workspace đạt trạng thái sạch, không còn compiler warning hay analyzer error (chờ user tự chạy kiểm thử suite).






