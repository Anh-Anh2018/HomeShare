import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/services/image_storage_service.dart';
import 'package:home_share/features/auth/providers/user_provider.dart';
import 'package:home_share/features/profile/models/cccd_data.dart';
import 'package:home_share/features/profile/models/cccd_validation_models.dart';

class TrackingImageStorageService extends ImageStorageService {
  int uploadCallCount = 0;

  @override
  Future<String> uploadCccdImage({
    required String filePath,
    required String uid,
    required bool isFront,
  }) async {
    uploadCallCount++;
    return 'https://mock.storage.test/$uid/${isFront ? "front" : "back"}.jpg';
  }
}

void main() {
  group('Save Boundary & Storage Hardening Tests', () {
    test(
      'saveCccdVerificationToBackend ném CccdValidationException và không gọi upload khi proof invalid (isValid: false)',
      () async {
        final trackingStorage = TrackingImageStorageService();
        const invalidProof = CccdValidationProof(
          isValid: false,
          rejectionReasonCode: CccdValidationReasonCodes.proofIncomplete,
        );

        expect(
          () => saveCccdVerificationToBackend(
            uid: 'test_user_001',
            proof: invalidProof,
            imageStorageService: trackingStorage,
          ),
          throwsA(isA<CccdValidationException>()),
        );

        expect(trackingStorage.uploadCallCount, equals(0));
      },
    );

    test(
      'saveCccdVerificationToBackend ném CccdValidationException khi proof có verifiedData null hoặc legacy version',
      () async {
        final trackingStorage = TrackingImageStorageService();
        const legacyProof = CccdValidationProof(
          isValid: true,
          version: 'legacy_v0',
          verifiedData: null,
        );

        expect(
          () => saveCccdVerificationToBackend(
            uid: 'test_user_002',
            proof: legacyProof,
            imageStorageService: trackingStorage,
          ),
          throwsA(isA<CccdValidationException>()),
        );

        expect(trackingStorage.uploadCallCount, equals(0));
      },
    );

    test(
      'saveCccdVerificationToBackend ném CccdValidationException khi bằng chứng sai mặt (wrong side)',
      () async {
        final trackingStorage = TrackingImageStorageService();
        const frontEvidenceAsBack = CccdImageEvidence(
          side: CccdImageSide.front,
          normalizedOcrText: 'ĐẶC ĐIỂM NHẬN DẠNG NGÓN TRỎ',
          imageByteHash: 'hash_synthetic_back_002',
          width: 800,
          height: 600,
          byteLength: 50000,
          filePath: '/synthetic/path/back.jpg',
        );

        const frontEvidence = CccdImageEvidence(
          side: CccdImageSide.front,
          normalizedOcrText: 'CĂN CƯỚC CÔNG DÂN CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM',
          qrPayload: '079201000001||NGUYEN VAN A|01012000|Nam|TP HO CHI MINH|01012022',
          imageByteHash: 'hash_synthetic_front_001',
          width: 800,
          height: 600,
          byteLength: 50000,
          filePath: '/synthetic/path/front.jpg',
        );

        const syntheticData = CccdData(
          idNumber: '079201000001',
          fullName: 'NGUYEN VAN A',
          birthDate: '01/01/2000',
          gender: 'Nam',
          address: 'TP HO CHI MINH',
          issueDate: '01/01/2022',
        );

        const wrongSideProof = CccdValidationProof(
          isValid: true,
          frontEvidence: frontEvidence,
          backEvidence: frontEvidenceAsBack,
          verifiedData: syntheticData,
        );

        expect(
          () => saveCccdVerificationToBackend(
            uid: 'test_user_003',
            proof: wrongSideProof,
            imageStorageService: trackingStorage,
          ),
          throwsA(isA<CccdValidationException>()),
        );

        expect(trackingStorage.uploadCallCount, equals(0));
      },
    );

    test(
      'uploadCccdImage reject http/https/data URL trước khi chạm Firebase',
      () async {
        final storage = ImageStorageService();

        // 1. URL http
        expect(
          () => storage.uploadCccdImage(
            filePath: 'http://example.com/fake_cccd.jpg',
            uid: 'test_uid',
            isFront: true,
          ),
          throwsA(isA<FormatException>()),
        );

        // 2. URL https
        expect(
          () => storage.uploadCccdImage(
            filePath: 'https://firebasestorage.googleapis.com/v0/b/bucket/o/cccd.jpg',
            uid: 'test_uid',
            isFront: true,
          ),
          throwsA(isA<FormatException>()),
        );

        // 3. Data URI
        expect(
          () => storage.uploadCccdImage(
            filePath: 'data:image/jpeg;base64,/9j/4AAQSkZJRg==',
            uid: 'test_uid',
            isFront: true,
          ),
          throwsA(isA<FormatException>()),
        );

        // 4. File rỗng
        expect(
          () => storage.uploadCccdImage(
            filePath: '',
            uid: 'test_uid',
            isFront: true,
          ),
          throwsA(isA<FormatException>()),
        );

        // 5. File demo
        expect(
          () => storage.uploadCccdImage(
            filePath: '/path/to/demo_cccd_sample.jpg',
            uid: 'test_uid',
            isFront: true,
          ),
          throwsA(isA<FormatException>()),
        );
      },
    );
  });
}
