import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/profile/models/cccd_validation_models.dart';
import 'package:home_share/features/profile/services/cccd_image_evidence_validator.dart';

void main() {
  const validator = CccdImageEvidenceValidator();

  group('Giai đoạn TDD RED: Xác thực 2 mặt ảnh CCCD & Save Boundary', () {
    test(
      '1. Strict QR hợp lệ phải đủ 7 trường, ID đúng 12 số, tên/địa chỉ không rỗng, ngày sinh/ngày cấp hợp lệ',
      () {
        const validQr =
            '079201012345||NGUYỄN VĂN AN|15082001|Nam|Số 123 Võ Văn Ngân, Phường Linh Chiểu, TP. Thủ Đức, TP. Hồ Chí Minh|25122021';
        final result = validator.validateStrictQr(validQr);
        expect(result, isNotNull);
        expect(result!.idNumber, equals('079201012345'));
        expect(result.fullName, equals('NGUYỄN VĂN AN'));
        expect(result.birthDate, equals('15/08/2001'));
        expect(result.gender, equals('Nam'));
        expect(result.address, contains('Võ Văn Ngân'));
        expect(result.issueDate, equals('25/12/2021'));
      },
    );

    test(
      '2. Reject chuỗi 12 số đơn lẻ, QR thiếu trường, ngày sai, ID sai',
      () {
        // Chuỗi 12 số đơn lẻ (không chứa dấu phân cách '|')
        expect(validator.validateStrictQr('079201012345'), isNull);

        // QR thiếu trường (chỉ có 5 trường)
        expect(
          validator.validateStrictQr(
            '079201012345||NGUYỄN VĂN AN|15082001|Nam',
          ),
          isNull,
        );

        // Tên rỗng
        expect(
          validator.validateStrictQr(
            '079201012345|||15082001|Nam|Hồ Chí Minh|25122021',
          ),
          isNull,
        );

        // Địa chỉ rỗng
        expect(
          validator.validateStrictQr(
            '079201012345||NGUYỄN VĂN AN|15082001|Nam||25122021',
          ),
          isNull,
        );

        // ID không đủ 12 chữ số hoặc chứa chữ cái
        expect(
          validator.validateStrictQr(
            '07920101234||NGUYỄN VĂN AN|15082001|Nam|Hồ Chí Minh|25122021',
          ),
          isNull,
        );
        expect(
          validator.validateStrictQr(
            '07920101234A||NGUYỄN VĂN AN|15082001|Nam|Hồ Chí Minh|25122021',
          ),
          isNull,
        );

        // Ngày sinh sai logic (ngày 32 hoặc tháng 13)
        expect(
          validator.validateStrictQr(
            '079201012345||NGUYỄN VĂN AN|32082001|Nam|Hồ Chí Minh|25122021',
          ),
          isNull,
        );
        expect(
          validator.validateStrictQr(
            '079201012345||NGUYỄN VĂN AN|15132001|Nam|Hồ Chí Minh|25122021',
          ),
          isNull,
        );

        // Ngày cấp sai định dạng
        expect(
          validator.validateStrictQr(
            '079201012345||NGUYỄN VĂN AN|15082001|Nam|Hồ Chí Minh|99999999',
          ),
          isNull,
        );
      },
    );

    test(
      '3. Front chỉ valid khi có QR strict + dấu hiệu mặt trước; ảnh thường hoặc back chọn nhầm invalid',
      () {
        const validQr =
            '079201012345||NGUYỄN VĂN AN|15082001|Nam|Hồ Chí Minh|25122021';

        // Mặt trước chuẩn
        const validFront = CccdImageEvidence(
          side: CccdImageSide.front,
          normalizedOcrText:
              'CONG HOA XA HOI CHU NGHIA VIET NAM CAN CUOC CONG DAN SO 079201012345 HO VA TEN NGUYEN VAN AN',
          qrPayload: validQr,
          imageByteHash: 'hash_front_123',
          width: 1200,
          height: 800,
          byteLength: 250 * 1024,
        );
        final frontResult = validator.validateEvidence(
          validFront,
          expectedSide: CccdImageSide.front,
        );
        expect(frontResult.isValid, isTrue);
        expect(frontResult.detectedSide, equals(CccdImageSide.front));
        expect(frontResult.strictData, isNotNull);

        // Ảnh thông thường (không phải thẻ CCCD)
        const normalImage = CccdImageEvidence(
          side: CccdImageSide.front,
          normalizedOcrText: 'HINH ANH PHONG TRO SINH VIEN GIA RE',
          qrPayload: null,
          imageByteHash: 'hash_normal_123',
          width: 1200,
          height: 800,
          byteLength: 200 * 1024,
        );
        final normalResult = validator.validateEvidence(
          normalImage,
          expectedSide: CccdImageSide.front,
        );
        expect(normalResult.isValid, isFalse);

        // Ảnh mặt sau nhưng chọn nhầm vào vị trí mặt trước
        const backAsFront = CccdImageEvidence(
          side: CccdImageSide.front,
          normalizedOcrText:
              'DAC DIEM NHAN DANG NOT RUOI CUC CANH SAT DANG KY QUAN LY CU TRU',
          qrPayload: null,
          imageByteHash: 'hash_back_wrong_123',
          width: 1200,
          height: 800,
          byteLength: 220 * 1024,
        );
        final wrongResult = validator.validateEvidence(
          backAsFront,
          expectedSide: CccdImageSide.front,
        );
        expect(wrongResult.isValid, isFalse);
      },
    );

    test(
      '4. Back chỉ valid khi có >=2 dấu hiệu đặc trưng (ĐẶC ĐIỂM NHẬN DẠNG, BỘ CÔNG AN/CỤC CẢNH SÁT, MRZ-like); front chọn làm back invalid',
      () {
        // Mặt sau chuẩn có >=2 dấu hiệu đặc trưng
        const validBack = CccdImageEvidence(
          side: CccdImageSide.back,
          normalizedOcrText:
              'DAC DIEM NHAN DANG SEO CHAM CANH MUI PHAI CUC CANH SAT QUAN LY HANH CHINH VE TRAT TU XA HOI IDVNM079201012345<<',
          qrPayload: null,
          imageByteHash: 'hash_back_456',
          width: 1200,
          height: 800,
          byteLength: 260 * 1024,
        );
        final backResult = validator.validateEvidence(
          validBack,
          expectedSide: CccdImageSide.back,
        );
        expect(backResult.isValid, isTrue);
        expect(backResult.detectedSide, equals(CccdImageSide.back));

        // Mặt sau chỉ có 1 dấu hiệu yếu (không đủ >=2)
        const weakBack = CccdImageEvidence(
          side: CccdImageSide.back,
          normalizedOcrText: 'CONG AN THANH PHO HO CHI MINH',
          qrPayload: null,
          imageByteHash: 'hash_weak_back',
          width: 1200,
          height: 800,
          byteLength: 210 * 1024,
        );
        final weakResult = validator.validateEvidence(
          weakBack,
          expectedSide: CccdImageSide.back,
        );
        expect(weakResult.isValid, isFalse);

        // Mặt trước nạp nhầm vào vị trí mặt sau
        const frontAsBack = CccdImageEvidence(
          side: CccdImageSide.back,
          normalizedOcrText:
              'CONG HOA XA HOI CHU NGHIA VIET NAM CAN CUOC CONG DAN SO 079201012345',
          qrPayload:
              '079201012345||NGUYỄN VĂN AN|15082001|Nam|Hồ Chí Minh|25122021',
          imageByteHash: 'hash_front_wrong_456',
          width: 1200,
          height: 800,
          byteLength: 250 * 1024,
        );
        final wrongResult = validator.validateEvidence(
          frontAsBack,
          expectedSide: CccdImageSide.back,
        );
        expect(wrongResult.isValid, isFalse);
      },
    );

    test(
      '5. Reject ảnh quá nhỏ/quá lớn, độ phân giải thấp, hash rỗng',
      () {
        // Độ phân giải thấp (< 600x400)
        const lowRes = CccdImageEvidence(
          side: CccdImageSide.front,
          normalizedOcrText: 'CAN CUOC CONG DAN',
          qrPayload:
              '079201012345||NGUYỄN VĂN AN|15082001|Nam|Hồ Chí Minh|25122021',
          imageByteHash: 'valid_hash_1',
          width: 150,
          height: 100,
          byteLength: 50 * 1024,
        );
        final lowResRes = validator.validateEvidence(lowRes);
        expect(lowResRes.isValid, isFalse);
        expect(
          lowResRes.reasonCode,
          equals(CccdValidationReasonCodes.resolutionTooLow),
        );

        // Dung lượng quá nhỏ (< 20KB)
        const tooSmall = CccdImageEvidence(
          side: CccdImageSide.front,
          normalizedOcrText: 'CAN CUOC CONG DAN',
          qrPayload:
              '079201012345||NGUYỄN VĂN AN|15082001|Nam|Hồ Chí Minh|25122021',
          imageByteHash: 'valid_hash_2',
          width: 1200,
          height: 800,
          byteLength: 5 * 1024,
        );
        final tooSmallRes = validator.validateEvidence(tooSmall);
        expect(tooSmallRes.isValid, isFalse);
        expect(
          tooSmallRes.reasonCode,
          equals(CccdValidationReasonCodes.imageTooSmall),
        );

        // Dung lượng quá lớn (> 15MB)
        const tooLarge = CccdImageEvidence(
          side: CccdImageSide.front,
          normalizedOcrText: 'CAN CUOC CONG DAN',
          qrPayload:
              '079201012345||NGUYỄN VĂN AN|15082001|Nam|Hồ Chí Minh|25122021',
          imageByteHash: 'valid_hash_3',
          width: 1200,
          height: 800,
          byteLength: 20 * 1024 * 1024,
        );
        final tooLargeRes = validator.validateEvidence(tooLarge);
        expect(tooLargeRes.isValid, isFalse);
        expect(
          tooLargeRes.reasonCode,
          equals(CccdValidationReasonCodes.imageTooLarge),
        );

        // Hash rỗng hoặc chỉ có khoảng trắng
        const emptyHash = CccdImageEvidence(
          side: CccdImageSide.front,
          normalizedOcrText: 'CAN CUOC CONG DAN',
          qrPayload:
              '079201012345||NGUYỄN VĂN AN|15082001|Nam|Hồ Chí Minh|25122021',
          imageByteHash: '   ',
          width: 1200,
          height: 800,
          byteLength: 100 * 1024,
        );
        final emptyHashRes = validator.validateEvidence(emptyHash);
        expect(emptyHashRes.isValid, isFalse);
        expect(
          emptyHashRes.reasonCode,
          equals(CccdValidationReasonCodes.emptyHash),
        );
      },
    );

    test(
      '6. Reject hai mặt cùng hash byte',
      () {
        const sharedHash = 'identical_image_hash_999';
        const front = CccdImageEvidence(
          side: CccdImageSide.front,
          normalizedOcrText: 'CAN CUOC CONG DAN SO 079201012345',
          qrPayload:
              '079201012345||NGUYỄN VĂN AN|15082001|Nam|Hồ Chí Minh|25122021',
          imageByteHash: sharedHash,
          width: 1200,
          height: 800,
          byteLength: 200 * 1024,
        );
        const back = CccdImageEvidence(
          side: CccdImageSide.back,
          normalizedOcrText: 'DAC DIEM NHAN DANG CUC CANH SAT',
          qrPayload: null,
          imageByteHash: sharedHash, // Cùng hash với mặt trước!
          width: 1200,
          height: 800,
          byteLength: 200 * 1024,
        );

        final proof = validator.createProof(
          frontEvidence: front,
          backEvidence: back,
        );
        expect(proof.isValid, isFalse);
        expect(
          proof.rejectionReasonCode,
          equals(CccdValidationReasonCodes.duplicateImageHash),
        );
        expect(validator.canSave(proof), isFalse);
      },
    );

    test(
      '7. Proof hợp lệ mới cho phép save; thiếu mặt/validating/invalid/wrong-side/duplicate đều chặn',
      () {
        const validFront = CccdImageEvidence(
          side: CccdImageSide.front,
          normalizedOcrText: 'CAN CUOC CONG DAN HO VA TEN NGUYEN VAN AN',
          qrPayload:
              '079201012345||NGUYỄN VĂN AN|15082001|Nam|Hồ Chí Minh|25122021',
          imageByteHash: 'front_unique_hash',
          width: 1200,
          height: 800,
          byteLength: 200 * 1024,
        );
        const validBack = CccdImageEvidence(
          side: CccdImageSide.back,
          normalizedOcrText:
              'DAC DIEM NHAN DANG CUC CANH SAT IDVNM079201012345<<',
          qrPayload: null,
          imageByteHash: 'back_unique_hash',
          width: 1200,
          height: 800,
          byteLength: 220 * 1024,
        );

        // Hợp lệ trọn vẹn
        final validProof = validator.createProof(
          frontEvidence: validFront,
          backEvidence: validBack,
        );
        expect(validProof.isValid, isTrue);
        expect(validator.canSave(validProof), isTrue);

        // Chặn khi proof null
        expect(validator.canSave(null), isFalse);

        // Chặn khi thiếu mặt
        const incompleteProof = CccdValidationProof(
          isValid: false,
          frontEvidence: null,
          backEvidence: null,
          rejectionReasonCode: CccdValidationReasonCodes.proofIncomplete,
        );
        expect(validator.canSave(incompleteProof), isFalse);

        // Chặn khi proof có cờ isValid = false
        const invalidProof = CccdValidationProof(
          isValid: false,
          frontEvidence: validFront,
          backEvidence: validBack,
          rejectionReasonCode: CccdValidationReasonCodes.wrongSideDetected,
        );
        expect(validator.canSave(invalidProof), isFalse);
      },
    );

    test(
      '8. Reason code không chứa raw OCR, số CCCD, path/URL',
      () {
        const sensitiveId = '079201012345';
        const sensitivePath = 'D:/secret/cccd_front_079201012345.jpg';
        const sensitiveUrl =
            'https://firebasestorage.googleapis.com/v0/b/app/o/users%2F123%2Fcccd.jpg';
        const rawOcr =
            'CONG HOA XA HOI CHU NGHIA VIET NAM CAN CUOC CONG DAN 079201012345';

        const evidence = CccdImageEvidence(
          side: CccdImageSide.front,
          normalizedOcrText: rawOcr,
          qrPayload: '$sensitiveId||AN|15082001|Nam|HCM|25122021',
          imageByteHash: 'hash_test',
          width: 100, // Trigger failure độ phân giải thấp
          height: 100,
          byteLength: 10 * 1024,
          filePath: sensitivePath,
        );

        final result = validator.validateEvidence(evidence);

        // Reason code an toàn tuyệt đối không chứa dữ liệu nhạy cảm
        expect(result.reasonCode, isNot(contains(sensitiveId)));
        expect(result.reasonCode, isNot(contains(sensitivePath)));
        expect(result.reasonCode, isNot(contains(sensitiveUrl)));
        expect(result.reasonCode, isNot(contains(rawOcr)));

        // toString/log an toàn không chứa PII
        final resultStr = result.toString();
        expect(resultStr, isNot(contains(sensitiveId)));
        expect(resultStr, isNot(contains(sensitivePath)));
        expect(resultStr, isNot(contains(sensitiveUrl)));
        expect(resultStr, isNot(contains(rawOcr)));
      },
    );

    test(
      '9. demo_cccd_* không tạo proof hợp lệ',
      () {
        const demoFront = CccdImageEvidence(
          side: CccdImageSide.front,
          normalizedOcrText: 'DEMO CAN CUOC CONG DAN NGUYEN VAN AN',
          qrPayload:
              '079201012345||NGUYỄN VĂN AN|15082001|Nam|HCM|25122021',
          imageByteHash: 'demo_front_hash',
          width: 1200,
          height: 800,
          byteLength: 100 * 1024,
          filePath: 'demo_cccd_front.jpg',
          isDemo: true,
        );
        const demoBack = CccdImageEvidence(
          side: CccdImageSide.back,
          normalizedOcrText: 'DEMO DAC DIEM NHAN DANG CUC CANH SAT',
          qrPayload: null,
          imageByteHash: 'demo_back_hash',
          width: 1200,
          height: 800,
          byteLength: 100 * 1024,
          filePath: 'demo_cccd_back.jpg',
          isDemo: true,
        );

        final proof = validator.createProof(
          frontEvidence: demoFront,
          backEvidence: demoBack,
        );
        expect(proof.isValid, isFalse);
        expect(
          proof.rejectionReasonCode,
          equals(CccdValidationReasonCodes.demoImageRejected),
        );
        expect(validator.canSave(proof), isFalse);
      },
    );

    test(
      '10. Legacy URL không có validation metadata/version không được coi là proof cho lần lưu mới',
      () {
        // Proof thiếu version hoặc version rỗng
        const legacyProof = CccdValidationProof(
          isValid: true,
          version: '',
          verifiedData: null,
          rejectionReasonCode: null,
        );
        expect(validator.canSave(legacyProof), isFalse);

        // Proof mang version cũ không được hỗ trợ
        const outdatedProof = CccdValidationProof(
          isValid: true,
          version: 'legacy_v0',
          verifiedData: null,
        );
        expect(validator.canSave(outdatedProof), isFalse);
      },
    );
  });
}
