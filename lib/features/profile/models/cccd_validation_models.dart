import 'package:flutter/foundation.dart';
import 'cccd_data.dart';

/// Enum phân định hai mặt của thẻ Căn cước công dân
enum CccdImageSide {
  front,
  back,
}

/// Danh mục mã lý do kiểm định an toàn (Tuyệt đối không chứa PII, số CCCD, raw OCR hoặc đường dẫn)
abstract final class CccdValidationReasonCodes {
  static const String valid = 'VALID';
  static const String qrMissingOrInvalid = 'QR_MISSING_OR_INVALID';
  static const String qrMissingRequiredFields = 'QR_MISSING_REQUIRED_FIELDS';
  static const String invalidIdNumber = 'INVALID_ID_NUMBER';
  static const String invalidDate = 'INVALID_DATE';
  static const String frontMarkersMissing = 'FRONT_MARKERS_MISSING';
  static const String backMarkersInsufficient = 'BACK_MARKERS_INSUFFICIENT';
  static const String wrongSideDetected = 'WRONG_SIDE_DETECTED';
  static const String imageTooSmall = 'IMAGE_TOO_SMALL';
  static const String imageTooLarge = 'IMAGE_TOO_LARGE';
  static const String resolutionTooLow = 'RESOLUTION_TOO_LOW';
  static const String emptyHash = 'EMPTY_HASH';
  static const String duplicateImageHash = 'DUPLICATE_IMAGE_HASH';
  static const String demoImageRejected = 'DEMO_IMAGE_REJECTED';
  static const String legacyUrlNotAllowed = 'LEGACY_URL_NOT_ALLOWED';
  static const String proofIncomplete = 'PROOF_INCOMPLETE';
  static const String imageFormatInvalid = 'IMAGE_FORMAT_INVALID';
  static const String fileNotFound = 'FILE_NOT_FOUND';
  static const String notImplemented = 'NOT_IMPLEMENTED';
}

/// Ngoại lệ ném ra khi vi phạm Save Boundary xác thực CCCD
class CccdValidationException implements Exception {
  final String message;
  const CccdValidationException(this.message);

  @override
  String toString() => 'CccdValidationException: $message';
}

/// Bằng chứng hình ảnh CCCD bất biến (Immutable Evidence)
@immutable
class CccdImageEvidence {
  final CccdImageSide side;
  final String normalizedOcrText;
  final String? qrPayload;
  final String imageByteHash;
  final int width;
  final int height;
  final int byteLength;
  final String? filePath;
  final bool isDemo;

  const CccdImageEvidence({
    required this.side,
    required this.normalizedOcrText,
    this.qrPayload,
    required this.imageByteHash,
    required this.width,
    required this.height,
    required this.byteLength,
    this.filePath,
    this.isDemo = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CccdImageEvidence &&
          runtimeType == other.runtimeType &&
          side == other.side &&
          imageByteHash == other.imageByteHash &&
          byteLength == other.byteLength &&
          width == other.width &&
          height == other.height &&
          isDemo == other.isDemo;

  @override
  int get hashCode => Object.hash(
        side,
        imageByteHash,
        byteLength,
        width,
        height,
        isDemo,
      );
}

/// Kết quả kiểm định ảnh CCCD (Immutable Result)
/// Đảm bảo nguyên tắc bảo mật: không bao giờ lưu/in thông tin định danh cá nhân nhạy cảm
@immutable
class CccdImageValidationResult {
  final bool isValid;
  final CccdImageSide? detectedSide;
  final CccdData? strictData;
  final String reasonCode;

  const CccdImageValidationResult({
    required this.isValid,
    this.detectedSide,
    this.strictData,
    required this.reasonCode,
  });

  @override
  String toString() =>
      'CccdImageValidationResult(isValid: $isValid, detectedSide: ${detectedSide?.name}, reasonCode: $reasonCode)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CccdImageValidationResult &&
          runtimeType == other.runtimeType &&
          isValid == other.isValid &&
          detectedSide == other.detectedSide &&
          reasonCode == other.reasonCode;

  @override
  int get hashCode => Object.hash(isValid, detectedSide, reasonCode);
}

/// Bằng chứng xác thực toàn diện 2 mặt CCCD (Immutable Proof Bundle)
/// Chỉ hợp lệ khi cả 2 mặt đều hợp lệ, khác hash byte và trích xuất thành công strict QR
@immutable
class CccdValidationProof {
  final bool isValid;
  final CccdImageEvidence? frontEvidence;
  final CccdImageEvidence? backEvidence;
  final CccdData? verifiedData;
  final String? rejectionReasonCode;
  final String version;
  final bool isDemo;
  final DateTime? createdAt;

  const CccdValidationProof({
    required this.isValid,
    this.frontEvidence,
    this.backEvidence,
    this.verifiedData,
    this.rejectionReasonCode,
    this.version = 'v1',
    this.isDemo = false,
    this.createdAt,
  });

  @override
  String toString() =>
      'CccdValidationProof(isValid: $isValid, version: $version, isDemo: $isDemo, reasonCode: $rejectionReasonCode)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CccdValidationProof &&
          runtimeType == other.runtimeType &&
          isValid == other.isValid &&
          version == other.version &&
          isDemo == other.isDemo &&
          rejectionReasonCode == other.rejectionReasonCode;

  @override
  int get hashCode => Object.hash(isValid, version, isDemo, rejectionReasonCode);
}
