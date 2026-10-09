# Kế Hoạch Triển Khai: Phân Luồng Sau Đăng Nhập Theo Vai Trò (Role-Based Routing)

## 1. Bối cảnh & Mục tiêu
- **Vấn đề hiện tại:** 
  - `lib/main.dart` đang đưa mọi người dùng đăng nhập thành công vào `RenterMainScreen`.
  - `UserProfile.fromMap` trong `lib/features/auth/providers/user_provider.dart` đang hardcode `role: 'renter'`.
  - Người dùng có vai trò `host` (chủ trọ) hoặc `admin` (quản trị viên) bị ép thành `renter`, không thể truy cập màn hình tương ứng.
- **Mục tiêu:**
  - Chuẩn hóa đọc vai trò từ Firestore với đầy đủ các khóa tương thích (`role`, `vaiTro`, `vaiTro_id`) và các alias định danh.
  - Tách logic phân giải vai trò thành thành phần thuần (pure function), độc lập, dễ kiểm thử tự động (TDD).
  - Cập nhật `AuthGate` để chờ cả `authStateProvider` và `userProfileProvider`, phân luồng chính xác:
    - `renter` -> [RenterMainScreen](file:///d:/App/HomeShare/lib/features/renter/screens/renter_main_screen.dart)
    - `host` -> [HostMainScreen](file:///d:/App/HomeShare/lib/features/host/screens/host_main_screen.dart)
    - `admin` -> [AdminDashboardScreen](file:///d:/App/HomeShare/lib/features/admin/screens/admin_dashboard_screen.dart) (shell tối thiểu, đúng vai trò)
    - Thiếu/sai vai trò -> [InvalidRoleScreen](file:///d:/App/HomeShare/lib/features/auth/screens/invalid_role_screen.dart) (fail-closed, cho phép đăng xuất, tuyệt đối không tự rơi về renter).
  - Sửa các test cũ khẳng định sai việc ép role thành renter.
  - Không thêm dependency, giữ tương thích schema, không chạy lệnh terminal.

---

## 2. Tiêu Chí Nghiệm Thu (Acceptance Criteria)

### AC 1: Chuẩn hóa Vai Trò (Role Normalization)
- Hỗ trợ đọc các khóa theo thứ tự ưu tiên: `role` -> `vaiTro` -> `vaiTro_id`.
- Hỗ trợ các alias không phân biệt hoa thường và tự động loại bỏ khoảng trắng thừa:
  - `renter`, `tenant`, `nguoiDung`, `nguoi_dung`, `1` -> `'renter'`
  - `host`, `landlord`, `chutro`, `chu_tro`, `2` -> `'host'`
  - `admin`, `administrator`, `quantri`, `quan_tri`, `3` -> `'admin'`
- Tuyệt đối không ép `host` hoặc `admin` thành `renter`.
- Khi không có khóa nào hợp lệ hoặc giá trị không thuộc tập alias quy định, trả về `null` (không tự ý gán `renter`).

### AC 2: Logic Phân Giải Thuần (Pure Role Resolution)
- Hàm thuần `RoleResolver.normalizeRole(dynamic raw)` và `RoleResolver.extractRoleFromMap(Map<String, dynamic>? data)`.
- Hàm thuần phân giải điều hướng `resolveAuthDestination({isAuthenticated, isProfileLoading, profile, error})` trả về enum `AuthDestination` (`unauthenticated`, `loading`, `renter`, `host`, `admin`, `invalidRole`, `error`).
- Dễ dàng kiểm thử độc lập 100% không phụ thuộc Firebase hay Widget tree.

### AC 3: Phân Luồng AuthGate & Nguyên Tắc Fail-Closed
- `AuthGate` lắng nghe `authStateProvider`:
  - Chưa đăng nhập (`user == null`) -> hiển thị `LoginScreen`.
  - Đang tải -> hiển thị loading indicator.
- Khi đã đăng nhập (`user != null`), lắng nghe `userProfileProvider`:
  - Đang tải profile -> hiển thị loading indicator.
  - Profile lỗi -> hiển thị thông báo lỗi và nút đăng xuất.
  - Profile `renter` -> điều hướng `RenterMainScreen`.
  - Profile `host` -> điều hướng `HostMainScreen`.
  - Profile `admin` -> điều hướng `AdminDashboardScreen` (shell rõ ràng, ghi chú trung thực về phạm vi shell, có nút đăng xuất).
  - Profile `null`, thiếu role hoặc role không hợp lệ -> hiển thị `InvalidRoleScreen` thông báo lỗi và cung cấp nút đăng xuất (`signOut`), không chuyển sang bất kỳ màn hình chính nào.

### AC 4: Cập Nhật Mô Hình Dữ Liệu & Test Cases
- `UserProfile.fromMap` sử dụng `RoleResolver.extractRoleFromMap`, không hardcode `'renter'`.
- Thêm trường/getter hỗ trợ vai trò: `isRenter`, `isHost`, `isAdmin`.
- Viết test suite mới kiểm thử toàn diện các case alias, precedence, invalid/missing roles, fail-closed resolution.
- Cập nhật test cũ tại `test/renter_suite_test.dart` đang kỳ vọng sai việc ép mọi dữ liệu thành `renter`.
- Giữ vững toàn bộ các test hiện có khác trong project.

---

## 3. Danh Sách File Dự Kiến

| STT | Đường Dẫn File | Trạng Thái | Mô Tả |
|---|---|---|---|
| 1 | `tasks/plan.md` | Mới | Tài liệu kế hoạch và tiêu chí nghiệm thu |
| 2 | `tasks/todo.md` | Mới | Danh sách đầu việc chi tiết theo tiến độ |
| 3 | `lib/features/auth/services/role_resolver.dart` | Mới | Logic thuần chuẩn hóa role và phân giải AuthDestination |
| 4 | `lib/features/auth/screens/invalid_role_screen.dart` | Mới | Màn hình fail-closed thông báo vai trò không hợp lệ & cho phép đăng xuất |
| 5 | `lib/features/admin/screens/admin_dashboard_screen.dart` | Mới | Màn hình Admin Dashboard Shell tối thiểu với thông tin admin & đăng xuất |
| 6 | `lib/features/auth/providers/user_provider.dart` | Sửa | Xóa hardcode `role: 'renter'`, tích hợp `RoleResolver`, thêm `isAdmin` |
| 7 | `lib/main.dart` | Sửa | Cập nhật `AuthGate` chờ cả authState & userProfile, phân luồng theo role |
| 8 | `test/role_routing_test.dart` | Mới | TDD test suite cho role normalization & role routing resolution |
| 9 | `test/renter_suite_test.dart` | Sửa | Cập nhật test case cũ bỏ khẳng định ép role thành renter |

---

# Active Plan — Renter Personal Profile Screen

## 1. Bối cảnh & Mục tiêu
- **Vấn đề hiện tại:**
  - `HomeScreen` (`lib/features/home/screens/home_screen.dart`) đang dùng làm tab "Cá nhân" cho Người thuê trong `RenterMainScreen`.
  - Màn hình này đang dùng `ref.watch(userProfileProvider).value` bỏ qua trạng thái loading/error, hardcode các số liệu giả ("08", "02", "01"), email mẫu `user@homeshare.vn`, badge role chưa chuẩn.
  - Chứa nhiều menu item "dead tap" (yêu thích, phòng đang thuê, báo cáo sự cố) chưa có logic hay provider persistence.
- **Mục tiêu:**
  - Thiết kế lại trang Cá nhân Người thuê bám sát SRS/SDS: xem thông tin tài khoản thật, theo dõi tiến độ hoàn thiện hồ sơ thật, xác thực CCCD (eKYC), theo dõi thống kê đơn thuê/lịch hẹn từ `renterBookingsStreamProvider`, và đăng xuất an toàn có xác nhận.
  - Tách logic helper thuần (`ProfileOverview` / `ProfileOverviewStats`) để tính toán thống kê đơn thuê và % hoàn thiện hồ sơ một cách tất định, test được độc lập.
  - Tách presentation widget (`PersonalProfileContent`) độc lập với Firebase để widget test không cần mock phức tạp.
  - Không hardcode dữ liệu giả, không để lộ exception nội bộ lên UI, hỗ trợ tốt màn hình 320px và text scale lớn.

## 2. Tiêu Chí Nghiệm Thu (Acceptance Criteria)

### AC 1: Xử lý Trạng thái Bất đồng bộ & Dữ liệu Thật (Data & State Architecture)
- `HomeScreen` xử lý đầy đủ các trạng thái `AsyncValue` của `userProfileProvider`: `loading`, `error`, `data (null | UserProfile)`.
- Kết nối `currentUserProvider` và `renterBookingsStreamProvider(user.uid)` để lấy danh sách đơn thuê thật.
- Helper thuần `ProfileOverview`:
  - `totalBookings`: Tổng số đơn/lịch hẹn.
  - `pendingCount`: Số đơn ở các trạng thái chờ (`pending`, `pending_payment`, `approved`, `paid`, alias tiếng Việt `choDuyet`, `daDuyet`, `choThanhToan`).
  - `activeCount`: Số đơn ở trạng thái đang thuê (`active`, alias `dangO`).
  - `calculateCompletionPercentage(UserProfile? profile)`: Tính % hoàn thiện hồ sơ trên 6 trường thật: `displayName`, `email`, `phoneNumber`, `address`, `avatarUrl`, `isCccdVerified` (0% -> 100%).
- Hiển thị nhãn trung tính "Chưa cập nhật", "Chưa có mã" khi thiếu dữ liệu; không fallback email/tên/mã giả.

### AC 2: Giao Diện Chuẩn Design System (Production-Quality UI)
- Header rõ thứ bậc thị giác:
  - Avatar thật từ `avatarUrl` hoặc fallback chữ cái đầu (initial) của tên người dùng.
  - Tên hiển thị (hoặc nhãn trung tính).
  - Badge vai trò chuẩn ("Người thuê" / `profile.role`).
  - Mã định danh `userCode` (hoặc "Chưa có mã").
  - Email & Số điện thoại nếu có (hoặc "Chưa cập nhật").
  - Trạng thái eKYC: Đã xác thực (badge verified) hoặc Chưa xác thực (thẻ nhắc kèm nút quét/xác thực mở `CccdVerificationScreen`).
- Thẻ "Hoàn thiện hồ sơ":
  - Thanh tiến trình thực tế (`LinearProgressIndicator`).
  - Hiển thị tỷ lệ % (0% - 100%).
  - Nút CTA "Cập nhật hồ sơ" mở `AccountSettingsScreen`.
- Thẻ "Thống kê hoạt động":
  - Dùng số liệu thật từ stream bookings.
  - Hiển thị skeleton/placeholder khi đang tải, thông báo thân thiện khi lỗi (không hiển thị `$e`).
- Khu "Quản lý tài khoản":
  - Chỉ giữ 4 hành động thực sự hoạt động:
    1. "Đơn thuê & lịch hẹn" -> mở `RenterBookingsScreen`.
    2. "Xác thực danh tính (CCCD)" -> mở `CccdVerificationScreen`.
    3. "Cài đặt tài khoản" -> mở `AccountSettingsScreen`.
    4. "Đăng xuất" -> Dialog xác nhận, gọi `authServiceProvider.signOut()`, thông báo thân thiện nếu lỗi.
  - Xóa bỏ triệt để các tile onTap rỗng (dead taps).

### AC 3: Khả năng Tiếp cận & Đáp ứng (Accessibility & Responsiveness)
- Hỗ trợ màn hình nhỏ (320px) không lỗi RenderFlex overflow.
- Tap target tối thiểu 44x44px.
- Semantics và tooltip đầy đủ cho các nút bấm và icon tương tác.

### AC 4: Kiểm Thử Độc Lập (Test Suite)
- Tạo `test/profile_screen_test.dart` kiểm thử:
  - Helper thống kê: tính đúng total, pending, active cho các tập bookings mẫu.
  - Helper hoàn thiện hồ sơ: 0%, một phần, 100%.
  - UI presentation: không chứa dữ liệu giả ("08", "02", "user@homeshare.vn", "ADM01"), hiển thị đúng menu hoạt động, trạng thái eKYC verified/unverified, không overflow trên viewport hẹp.

## 3. Danh Sách File Dự Kiến Lát Cắt Mới
| STT | File | Trạng Thái | Mô Tả |
|---|---|---|---|
| 1 | `lib/features/home/models/profile_overview.dart` | Mới | Model/helper thuần tính thống kê và tỷ lệ hoàn thiện hồ sơ |
| 2 | `lib/features/home/widgets/personal_profile_content.dart` | Mới | Presentation widget thuần, độc lập với Firebase cho test |
| 3 | `lib/features/home/screens/home_screen.dart` | Sửa | Screen container điều phối Riverpod provider & navigation |
| 4 | `test/profile_screen_test.dart` | Mới | Unit & Widget test cho helper và UI trang cá nhân |
| 5 | `tasks/plan.md` | Sửa | Cập nhật kế hoạch active |
| 6 | `tasks/todo.md` | Sửa | Cập nhật checklist theo dõi tiến độ |

---

# Active Plan — Xác Thực 2 Mặt Ảnh CCCD Trước Khi Lưu (CCCD Image Evidence Validation & Save Boundary)

## 1. Bối cảnh & Mục tiêu
- **Vấn đề hiện tại:**
  - `CccdVerificationScreen` cho phép lưu khi người dùng chọn bất kỳ ảnh nào (kể cả ảnh không phải CCCD, ảnh demo mẫu `demo_cccd_*`, hoặc nhầm lẫn giữa mặt trước và mặt sau).
  - Quét QR hiện đang khoan dung (nhận cả chuỗi 12 số đơn lẻ, hoặc fallback dữ liệu tĩnh), không xác thực strict 7 trường theo chuẩn CCCD gắn chip của Bộ Công An.
  - Tầng lưu trữ `saveCccdVerificationToBackend` và UI chưa có save boundary để thẩm định evidence proof (bằng chứng xác thực) trước khi upload và ghi vào Firestore / SharedPreferences.
- **Mục tiêu:**
  - Xây dựng cơ chế kiểm định ảnh CCCD on-device: bắt buộc cả 2 mặt trước và mặt sau phải được ứng dụng xác nhận đúng là CCCD và đúng mặt tương ứng thì mới được phép lưu.
  - Tuân thủ nguyên tắc bảo mật thông tin định danh (fail-closed, không log raw OCR/số CCCD/URL, không gửi ảnh cho API bên thứ ba/LLM, không tin cậy filename hay MIME).
  - Áp dụng triệt để phương pháp **Test-Driven Development (TDD)**:
    - **Giai đoạn RED (hiện tại)**: Xây dựng public contract skeleton (types, models, enum, pure validator với `UnimplementedError`) và viết đầy đủ 10 bài kiểm thử khắt khe trong `test/cccd_image_validation_test.dart`.
    - **Giai đoạn GREEN (lượt tiếp theo)**: Triển khai thuật toán xác thực QR strict, trích xuất đặc trưng OCR 2 mặt và cơ chế proof bundle.
    - **Giai đoạn REFACTOR**: Tích hợp save boundary vào `CccdVerificationScreen` và các service lưu trữ.

## 2. Nguyên Tắc Bảo Mật & Ranh Giới (Security Principles)
1. **Dữ liệu nhạy cảm:** Tuyệt đối không ghi log (debugPrint, console, analytics) chứa raw OCR text, số CCCD 12 số, họ tên chi tiết, đường dẫn file cục bộ hoặc download URL.
2. **Fail-Closed:** Mọi trường hợp lỗi, bất định, thiếu dữ liệu hoặc không đạt ngưỡng kiểm định đều dẫn đến kết quả từ chối (`isValid = false`, `canSave = false`). Không giữ ảnh mới, không kích hoạt upload Firebase Storage, không cập nhật Firestore/SharedPreferences.
3. **On-Device Validation:** Toàn bộ quá trình phân tích QR, kích thước, hash và đối soát đặc trưng được thực hiện 100% cục bộ trên thiết bị, không gửi ảnh qua API bên ngoài hay mô hình ngôn ngữ lớn (LLM).
4. **Không tin cậy siêu dữ liệu bề mặt:** Không dựa vào filename, extension (.jpg, .png), MIME type hay trạng thái checkbox phía UI để xác định tính hợp lệ.
5. **Cách ly hoàn toàn dữ liệu thử nghiệm:** Ảnh demo (`demo_cccd_*`) không bao giờ được cấp proof hợp lệ và bị chặn triệt để tại ranh giới lưu trữ production.
6. **Save Boundary Độc Lập:** Tầng lưu trữ tái kiểm định toàn diện proof bundle; không phụ thuộc vào trạng thái disabled của nút bấm trên UI.

## 3. Tiêu Chí Nghiệm Thu (Acceptance Criteria)

### AC 1: Strict QR Code Validation
- Mã QR mặt trước phải đủ chính xác 7 trường phân tách bằng ký tự `|`:
  1. Số CCCD: đúng 12 chữ số (`^\d{12}$`).
  2. Số CMND 9 số cũ (có thể rỗng hoặc 9 số).
  3. Họ và tên: chuỗi tiếng Việt không rỗng.
  4. Ngày sinh: định dạng chuẩn `ddMMyyyy` (hoặc `dd/MM/yyyy`), ngày/tháng/năm hợp lệ logic.
  5. Giới tính: `Nam` hoặc `Nữ`.
  6. Địa chỉ thường trú: chuỗi không rỗng.
  7. Ngày cấp: định dạng chuẩn `ddMMyyyy` (hoặc `dd/MM/yyyy`), ngày hợp lệ.
- Từ chối chuỗi 12 số đơn lẻ, QR thiếu trường, ngày sinh/ngày cấp không hợp lệ, hoặc số CCCD không hợp chuẩn.

### AC 2: Front & Back Side Evidence Verification
- **Mặt trước (Front):** Chỉ hợp lệ khi trích xuất được QR code strict hợp lệ (AC 1) VÀ văn bản OCR chứa các dấu hiệu mặt trước tiêu biểu (tiêu ngữ, tiêu đề CCCD, Họ tên, Quốc tịch). Reject ảnh thông thường hoặc ảnh mặt sau nạp nhầm vào vị trí mặt trước.
- **Mặt sau (Back):** Chỉ hợp lệ khi chứa từ 2 dấu hiệu đặc trưng trở lên (ĐẶC ĐIỂM NHẬN DẠNG / IDENTIFYING FEATURES, BỘ CÔNG AN / CỤC CẢNH SÁT, hoặc chuỗi MRZ-like `IDVNM<<...`). Reject ảnh mặt trước nạp nhầm vào vị trí mặt sau.

### AC 3: Image Integrity & Anti-Duplicate
- Từ chối ảnh có độ phân giải quá thấp (< 600x400), dung lượng quá nhỏ (< 20KB) hoặc quá lớn (> 15MB).
- Từ chối ảnh có mã băm (byte hash) rỗng hoặc không xác định.
- Bắt buộc kiểm tra trùng lặp: Nếu mặt trước và mặt sau có cùng mã băm (`frontHash == backHash`), lập tức từ chối tạo proof và chặn lưu.

### AC 4: Immutable Validation Proof & Save Boundary
- `CccdValidationProof` là đối tượng bất biến (immutable bundle) chứa bằng chứng của cả 2 mặt, dữ liệu `strictData` đã kiểm chứng, và phiên bản quy chuẩn (`version`).
- Hàm `canSave(proof)` chỉ trả về `true` khi proof thỏa mãn toàn bộ: mặt trước valid + mặt sau valid + khác hash + QR strict + không phải demo + có version hợp lệ.
- Từ chối lưu các đối tượng legacy (chỉ có URL cũ mà không có bằng chứng validation metadata/version tương thích).

### AC 5: An Toàn Thông Tin Trong Mã Lỗi (Safe Reason Codes)
- Mọi mã từ chối (`reasonCode`) phải sử dụng mã định danh an toàn (thuộc `CccdValidationReasonCodes`), không chứa thông tin PII, số định danh, URL hoặc raw OCR.
- Phương thức `toString()` của các model kết quả được chuẩn hóa an toàn.

## 4. Rủi Ro & Điểm Kiểm Soát (Risks & Checkpoints)
- **Rủi ro 1: Phá vỡ luồng người dùng hiện hữu khi dữ liệu cũ chưa có proof.**
  - *Kiểm soát:* Cho phép hiển thị dữ liệu lịch sử đã lưu trước đó, nhưng bất kỳ thao tác lưu/cập nhật ảnh mới nào đều phải trải qua save boundary với proof bundle hoàn chỉnh.
- **Rủi ro 2: OCR trên thiết bị có thể đọc thiếu dấu do ánh sáng.**
  - *Kiểm soát:* Bộ nhận diện từ khóa cho phép đối soát cả dạng có dấu và không dấu (normalized text), kết hợp QR strict ở mặt trước để làm mỏ neo dữ liệu vững chắc.
- **Rủi ro 3: Trượt qua ranh giới lưu bằng cách giả lập request.**
  - *Kiểm soát:* Tầng backend service kiểm tra bắt buộc `CccdValidationProof` trước khi gọi upload và lưu dữ liệu.

## 5. Danh Sách File & Tiến Độ Thực Thi
| STT | File | Trạng Thái | Mô Tả |
|---|---|---|---|
| 1 | `tasks/plan.md` | Hoàn thành | Cập nhật tài liệu thiết kế, tiêu chí nghiệm thu và tiến độ |
| 2 | `tasks/todo.md` | Hoàn thành | Cập nhật danh sách công việc theo tiến trình TDD GREEN/REFACTOR |
| 3 | `lib/features/profile/models/cccd_validation_models.dart` | Hoàn thành | Contract types: enum CccdImageSide, CccdImageEvidence, CccdImageValidationResult, CccdValidationProof, Safe Reason Codes |
| 4 | `lib/features/profile/services/cccd_image_evidence_validator.dart` | Hoàn thành | Pure validator triển khai đầy đủ: `validateStrictQr`, `validateEvidence`, `createProof`, `canSave` |
| 5 | `lib/features/profile/services/cccd_image_evidence_extractor.dart` | Hoàn thành | On-device ML Kit OCR Text Recognition engine và evidence extractor với SHA-256 + magic bytes |
| 6 | `lib/features/profile/screens/cccd_scanner_screen.dart` | Hoàn thành | Strict QR scanner: thẩm định strict 7 trường cho camera/paste/gallery, loại bỏ permissive & bypass |
| 7 | `lib/features/profile/screens/cccd_verification_screen.dart` | Hoàn thành | Tích hợp proof 2 mặt, 4 UI states (validating/valid/invalid/idle), submit boundary `canSave`, loại bỏ bypass |
| 8 | `lib/features/auth/providers/user_provider.dart` | Hoàn thành | Save boundary: `saveCccdVerificationToBackend` yêu cầu `CccdValidationProof`, upload từ local paths trong proof |
| 9 | `lib/core/services/image_storage_service.dart` | Hoàn thành | Storage hardening: `uploadCccdImage` ném FormatException với URL từ xa / Data URI |
| 10 | `test/cccd_image_validation_test.dart` | Hoàn thành | 10 bài test TDD cho pure validator |
| 11 | `test/cccd_save_boundary_test.dart` | Hoàn thành | Unit test cho Save Boundary, tracking storage và URL reject hardening |
| 12 | `test/cccd_verification_screen_test.dart` | Hoàn thành | Widget test cho màn hình xác thực: initial idle states và disabled submit |

## 6. Trạng Thái Hiện Tại
- **Giai đoạn TDD:** GREEN & REFACTOR đã hoàn tất trên toàn bộ các file mã nguồn.
- **On-device OCR/QR:** Sử dụng `google_mlkit_text_recognition` và regex strict 7 trường; không gửi dữ liệu ra ngoài thiết bị.
- **Save Boundary:** Kiểm tra `canSave(proof)` trước khi upload ảnh hoặc ghi cơ sở dữ liệu.
- **UI States:** Hiển thị rõ ràng 4 trạng thái thẩm định cho từng mặt; nút lưu bị khóa khi chưa đạt proof hợp lệ.
- **Static Analysis:** Toàn bộ workspace 0 error, 0 warning (chờ user tự chạy kiểm thử suite).


