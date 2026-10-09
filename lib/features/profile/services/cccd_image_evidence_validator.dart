import '../models/cccd_data.dart';
import '../models/cccd_validation_models.dart';

/// Pure validator thẩm định hình ảnh CCCD và xây dựng bằng chứng xác thực (Validation Proof)
/// Đảm bảo tính toán độc lập, chạy 100% on-device và không có side effects
class CccdImageEvidenceValidator {
  const CccdImageEvidenceValidator();

  static const int minWidth = 600;
  static const int minHeight = 400;
  static const int minByteLength = 20 * 1024; // 20 KB
  static const int maxByteLength = 15 * 1024 * 1024; // 15 MB
  static const String currentProofVersion = 'v1';

  /// Thẩm định mã QR theo chuẩn strict 7 trường của thẻ CCCD gắn chip Bộ Công An
  /// Yêu cầu:
  /// - Phải có đúng 7 trường phân cách bởi dấu `|`
  /// - Số CCCD đúng 12 chữ số
  /// - Họ tên và địa chỉ không rỗng
  /// - Ngày sinh và ngày cấp hợp lệ theo lịch
  CccdData? validateStrictQr(String? qrPayload) {
    if (qrPayload == null) return null;
    final trimmed = qrPayload.trim().replaceAll('\uFEFF', '');
    if (trimmed.isEmpty) return null;

    final parts = trimmed.split('|');
    if (parts.length != 7) return null;

    final idNum = parts[0].trim();
    final oldId = parts[1].trim();
    final name = parts[2].trim();
    final rawDob = parts[3].trim();
    final gender = parts[4].trim();
    final address = parts[5].trim();
    final rawIssue = parts[6].trim();

    // 1. Số CCCD: đúng 12 chữ số
    if (!RegExp(r'^\d{12}$').hasMatch(idNum)) return null;

    // 2. CMND cũ: rỗng hoặc đúng 9 số
    if (oldId.isNotEmpty && !RegExp(r'^\d{9}$').hasMatch(oldId)) return null;

    // 3. Họ tên không rỗng
    if (name.isEmpty) return null;

    // 4. Giới tính: Nam hoặc Nữ
    if (gender != 'Nam' && gender != 'Nữ') return null;

    // 5. Địa chỉ không rỗng
    if (address.isEmpty) return null;

    // 6. Phân tích & kiểm tra tính hợp lệ của ngày sinh
    final birthDateFormatted = _parseAndValidateDate(rawDob);
    if (birthDateFormatted == null) return null;

    // 7. Phân tích & kiểm tra tính hợp lệ của ngày cấp
    final issueDateFormatted = _parseAndValidateDate(rawIssue);
    if (issueDateFormatted == null) return null;

    return CccdData(
      idNumber: idNum,
      oldCmnd: oldId,
      fullName: name,
      birthDate: birthDateFormatted,
      gender: gender,
      address: address,
      issueDate: issueDateFormatted,
    );
  }

  /// Thẩm định bằng chứng ảnh CCCD đơn lẻ (mặt trước hoặc mặt sau)
  /// Kiểm tra:
  /// - Độ phân giải, dung lượng byte và tính toàn vẹn mã băm (hash)
  /// - Mặt trước: Bắt buộc có strict QR + các dấu hiệu nhận diện mặt trước
  /// - Mặt sau: Bắt buộc có >= 2 dấu hiệu đặc trưng (Đặc điểm nhận dạng, Bộ Công An, MRZ-like)
  /// - Từ chối khi phát hiện nhầm mặt hoặc ảnh demo
  CccdImageValidationResult validateEvidence(
    CccdImageEvidence evidence, {
    CccdImageSide? expectedSide,
  }) {
    // 1. Kiểm tra demo image fail-closed
    if (evidence.isDemo ||
        (evidence.filePath != null &&
            evidence.filePath!.toLowerCase().contains('demo_cccd'))) {
      return const CccdImageValidationResult(
        isValid: false,
        detectedSide: null,
        strictData: null,
        reasonCode: CccdValidationReasonCodes.demoImageRejected,
      );
    }

    // 2. Kiểm tra mã băm hash rỗng hoặc toàn khoảng trắng
    if (evidence.imageByteHash.trim().isEmpty) {
      return const CccdImageValidationResult(
        isValid: false,
        detectedSide: null,
        strictData: null,
        reasonCode: CccdValidationReasonCodes.emptyHash,
      );
    }

    // 3. Kiểm tra độ phân giải (hỗ trợ cả ảnh ngang lẫn dọc)
    final longSide =
        evidence.width >= evidence.height ? evidence.width : evidence.height;
    final shortSide =
        evidence.width >= evidence.height ? evidence.height : evidence.width;
    if (longSide < minWidth || shortSide < minHeight) {
      return const CccdImageValidationResult(
        isValid: false,
        detectedSide: null,
        strictData: null,
        reasonCode: CccdValidationReasonCodes.resolutionTooLow,
      );
    }

    // 4. Kiểm tra dung lượng byte
    if (evidence.byteLength < minByteLength) {
      return const CccdImageValidationResult(
        isValid: false,
        detectedSide: null,
        strictData: null,
        reasonCode: CccdValidationReasonCodes.imageTooSmall,
      );
    }
    if (evidence.byteLength > maxByteLength) {
      return const CccdImageValidationResult(
        isValid: false,
        detectedSide: null,
        strictData: null,
        reasonCode: CccdValidationReasonCodes.imageTooLarge,
      );
    }

    // 5. Chuẩn hóa OCR text loại bỏ dấu tiếng Việt để đối soát đa dạng font/ánh sáng
    final norm = _normalize(evidence.normalizedOcrText);

    // Dấu hiệu mặt trước:
    final hasFrontTitle = norm.contains('CAN CUOC CONG DAN') ||
        norm.contains('CAN CUOC') ||
        norm.contains('CĂN CƯỚC');
    final hasNationalMotto = norm.contains('CONG HOA XA HOI') ||
        norm.contains('VIET NAM') ||
        norm.contains('DOC LAP TU DO');
    final hasPersonalField = norm.contains('HO VA TEN') ||
        norm.contains('SO') ||
        norm.contains('QUOC TICH') ||
        norm.contains('NGAY SINH');
    final hasFrontMarkers =
        hasFrontTitle && (hasNationalMotto || hasPersonalField);

    // Thẩm định QR strict (chỉ mặt trước mới có QR)
    final strictData = validateStrictQr(evidence.qrPayload);

    // Dấu hiệu mặt sau:
    // Nhóm 1: Đặc điểm nhận dạng / identifying features / dấu vết riêng
    final hasGroup1 = norm.contains('DAC DIEM NHAN DANG') ||
        norm.contains('IDENTIFYING FEATURES') ||
        norm.contains('DAU VET RIENG');
    // Nhóm 2: Bộ Công An / Cục Cảnh Sát / Giám Đốc / Cục Trưởng
    final hasGroup2 = norm.contains('BO CONG AN') ||
        norm.contains('CUC CANH SAT') ||
        norm.contains('GIAM DOC') ||
        norm.contains('CUC TRUONG');
    // Nhóm 3: MRZ-like (IDVNM hoặc <<) hoặc chip
    final hasGroup3 = norm.contains('IDVNM') ||
        norm.contains('<<') ||
        norm.contains('CHIP') ||
        norm.contains('CHIP DIEN TU');

    int backGroups = 0;
    if (hasGroup1) backGroups++;
    if (hasGroup2) backGroups++;
    if (hasGroup3) backGroups++;
    final hasBackMarkers = backGroups >= 2;

    final targetSide = expectedSide ?? evidence.side;

    if (targetSide == CccdImageSide.front) {
      // Kỳ vọng mặt trước
      if (hasBackMarkers && strictData == null && !hasFrontMarkers) {
        return const CccdImageValidationResult(
          isValid: false,
          detectedSide: CccdImageSide.back,
          strictData: null,
          reasonCode: CccdValidationReasonCodes.wrongSideDetected,
        );
      }

      if (strictData == null) {
        final reason = (evidence.qrPayload == null ||
                evidence.qrPayload!.trim().isEmpty)
            ? CccdValidationReasonCodes.qrMissingOrInvalid
            : CccdValidationReasonCodes.qrMissingRequiredFields;
        return CccdImageValidationResult(
          isValid: false,
          detectedSide: null,
          strictData: null,
          reasonCode: reason,
        );
      }

      if (!hasFrontMarkers) {
        return const CccdImageValidationResult(
          isValid: false,
          detectedSide: null,
          strictData: null,
          reasonCode: CccdValidationReasonCodes.frontMarkersMissing,
        );
      }

      return CccdImageValidationResult(
        isValid: true,
        detectedSide: CccdImageSide.front,
        strictData: strictData,
        reasonCode: CccdValidationReasonCodes.valid,
      );
    } else {
      // Kỳ vọng mặt sau
      if ((hasFrontMarkers || strictData != null) && !hasBackMarkers) {
        return const CccdImageValidationResult(
          isValid: false,
          detectedSide: CccdImageSide.front,
          strictData: null,
          reasonCode: CccdValidationReasonCodes.wrongSideDetected,
        );
      }

      if (!hasBackMarkers) {
        return const CccdImageValidationResult(
          isValid: false,
          detectedSide: null,
          strictData: null,
          reasonCode: CccdValidationReasonCodes.backMarkersInsufficient,
        );
      }

      return const CccdImageValidationResult(
        isValid: true,
        detectedSide: CccdImageSide.back,
        strictData: null,
        reasonCode: CccdValidationReasonCodes.valid,
      );
    }
  }

  /// Tạo bó bằng chứng xác thực toàn diện (Proof Bundle) cho 2 mặt
  /// Chỉ hợp lệ khi cả 2 mặt đều hợp lệ, khác hash byte và QR strict thành công
  CccdValidationProof createProof({
    required CccdImageEvidence frontEvidence,
    required CccdImageEvidence backEvidence,
    String version = currentProofVersion,
  }) {
    // 1. Chặn ảnh demo
    if (frontEvidence.isDemo ||
        backEvidence.isDemo ||
        (frontEvidence.filePath != null &&
            frontEvidence.filePath!.toLowerCase().contains('demo_cccd')) ||
        (backEvidence.filePath != null &&
            backEvidence.filePath!.toLowerCase().contains('demo_cccd'))) {
      return CccdValidationProof(
        isValid: false,
        frontEvidence: frontEvidence,
        backEvidence: backEvidence,
        verifiedData: null,
        rejectionReasonCode: CccdValidationReasonCodes.demoImageRejected,
        version: version,
        isDemo: true,
      );
    }

    // 2. Chặn trùng lặp mã băm byte giữa 2 mặt
    if (frontEvidence.imageByteHash == backEvidence.imageByteHash) {
      return CccdValidationProof(
        isValid: false,
        frontEvidence: frontEvidence,
        backEvidence: backEvidence,
        verifiedData: null,
        rejectionReasonCode: CccdValidationReasonCodes.duplicateImageHash,
        version: version,
      );
    }

    // 3. Thẩm định độc lập từng mặt
    final frontRes = validateEvidence(
      frontEvidence,
      expectedSide: CccdImageSide.front,
    );
    if (!frontRes.isValid) {
      return CccdValidationProof(
        isValid: false,
        frontEvidence: frontEvidence,
        backEvidence: backEvidence,
        verifiedData: null,
        rejectionReasonCode: frontRes.reasonCode,
        version: version,
      );
    }

    final backRes = validateEvidence(
      backEvidence,
      expectedSide: CccdImageSide.back,
    );
    if (!backRes.isValid) {
      return CccdValidationProof(
        isValid: false,
        frontEvidence: frontEvidence,
        backEvidence: backEvidence,
        verifiedData: null,
        rejectionReasonCode: backRes.reasonCode,
        version: version,
      );
    }

    // 4. Kiểm tra strictData
    if (frontRes.strictData == null) {
      return CccdValidationProof(
        isValid: false,
        frontEvidence: frontEvidence,
        backEvidence: backEvidence,
        verifiedData: null,
        rejectionReasonCode:
            CccdValidationReasonCodes.qrMissingRequiredFields,
        version: version,
      );
    }

    return CccdValidationProof(
      isValid: true,
      frontEvidence: frontEvidence,
      backEvidence: backEvidence,
      verifiedData: frontRes.strictData,
      rejectionReasonCode: null,
      version: version,
      createdAt: DateTime.now(),
    );
  }

  /// Kiểm tra điều kiện tiên quyết cho phép lưu dữ liệu vào hệ thống (Save Boundary)
  /// Chặn mọi trường hợp:
  /// - Proof null, invalid, thiếu mặt hoặc sai mặt
  /// - Trùng lặp mã băm giữa 2 mặt
  /// - Ảnh mẫu demo hoặc URL legacy không có validation metadata hợp chuẩn
  bool canSave(CccdValidationProof? proof) {
    if (proof == null) return false;
    if (!proof.isValid) return false;
    if (proof.isDemo) return false;
    if (proof.frontEvidence == null || proof.backEvidence == null) return false;
    if (proof.frontEvidence!.imageByteHash ==
        proof.backEvidence!.imageByteHash) {
      return false;
    }
    if (proof.frontEvidence!.side != CccdImageSide.front ||
        proof.backEvidence!.side != CccdImageSide.back) {
      return false;
    }
    if (proof.verifiedData == null) return false;
    if (proof.version != currentProofVersion) return false;
    return true;
  }

  /// Phân tích và kiểm tra tính hợp lệ của ngày tháng năm
  static String? _parseAndValidateDate(String rawDate) {
    int day, month, year;
    if (rawDate.length == 8 && RegExp(r'^\d{8}$').hasMatch(rawDate)) {
      day = int.parse(rawDate.substring(0, 2));
      month = int.parse(rawDate.substring(2, 4));
      year = int.parse(rawDate.substring(4, 8));
    } else if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(rawDate)) {
      final parts = rawDate.split('/');
      day = int.parse(parts[0]);
      month = int.parse(parts[1]);
      year = int.parse(parts[2]);
    } else {
      return null;
    }

    if (year < 1900 || year > 2100) return null;
    if (month < 1 || month > 12) return null;

    final daysInMonth = _daysInMonth(year, month);
    if (day < 1 || day > daysInMonth) return null;

    final dStr = day.toString().padLeft(2, '0');
    final mStr = month.toString().padLeft(2, '0');
    final yStr = year.toString();
    return '$dStr/$mStr/$yStr';
  }

  static int _daysInMonth(int year, int month) {
    if (month == 2) {
      final isLeap =
          (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      return isLeap ? 29 : 28;
    }
    const days = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month];
  }

  static String _normalize(String input) {
    var result = input.toUpperCase();
    const accents = {
      'À': 'A', 'Á': 'A', 'Ạ': 'A', 'Ả': 'A', 'Ã': 'A',
      'Â': 'A', 'Ầ': 'A', 'Ấ': 'A', 'Ậ': 'A', 'Ẩ': 'A', 'Ẫ': 'A',
      'Ă': 'A', 'Ằ': 'A', 'Ắ': 'A', 'Ặ': 'A', 'Ẳ': 'A', 'Ẵ': 'A',
      'È': 'E', 'É': 'E', 'Ẹ': 'E', 'Ẻ': 'E', 'Ẽ': 'E',
      'Ê': 'E', 'Ề': 'E', 'Ế': 'E', 'Ệ': 'E', 'Ể': 'E', 'Ễ': 'E',
      'Ì': 'I', 'Í': 'I', 'Ị': 'I', 'Ỉ': 'I', 'Ĩ': 'I',
      'Ò': 'O', 'Ó': 'O', 'Ọ': 'O', 'Ỏ': 'O', 'Õ': 'O',
      'Ô': 'O', 'Ồ': 'O', 'Ố': 'O', 'Ộ': 'O', 'Ổ': 'O', 'Ỗ': 'O',
      'Ơ': 'O', 'Ờ': 'O', 'Ớ': 'O', 'Ợ': 'O', 'Ở': 'O', 'Ỡ': 'O',
      'Ù': 'U', 'Ú': 'U', 'Ụ': 'U', 'Ủ': 'U', 'Ũ': 'U',
      'Ư': 'U', 'Ừ': 'U', 'Ứ': 'U', 'Ự': 'U', 'Ử': 'U', 'Ữ': 'U',
      'Ỳ': 'Y', 'Ý': 'Y', 'Ỵ': 'Y', 'Ỷ': 'Y', 'Ỹ': 'Y',
      'Đ': 'D',
    };
    accents.forEach((key, value) {
      result = result.replaceAll(key, value);
    });
    return result;
  }
}
