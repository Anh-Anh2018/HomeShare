import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/cccd_validation_models.dart';
import 'cccd_image_evidence_validator.dart';

/// Interface bóc tách chữ từ ảnh (OCR Engine) on-device
abstract class CccdOcrEngine {
  Future<String> recognizeText(String filePath);
}

/// Engine mặc định sử dụng phân tích on-device an toàn
class DefaultCccdOcrEngine implements CccdOcrEngine {
  const DefaultCccdOcrEngine();

  @override
  Future<String> recognizeText(String filePath) async {
    // Không bao giờ gửi ảnh ra API bên ngoài hoặc LLM
    TextRecognizer? recognizer;
    try {
      final inputImage = InputImage.fromFilePath(filePath);
      recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognizedText = await recognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (_) {
      // Fail-safe: không log exception thô hay đường dẫn file
      return '';
    } finally {
      await recognizer?.close();
    }
  }
}

/// Dịch vụ đọc file ảnh cục bộ, kiểm tra tính toàn vẹn và trích xuất bằng chứng CCCD (100% on-device)
class CccdImageEvidenceExtractor {
  final CccdOcrEngine _ocrEngine;
  final CccdImageEvidenceValidator _validator;

  const CccdImageEvidenceExtractor({
    this._ocrEngine = const DefaultCccdOcrEngine(),
    this._validator = const CccdImageEvidenceValidator(),
  });

  /// Phân tích file ảnh cục bộ và trích xuất bằng chứng xác thực
  Future<({CccdImageEvidence? evidence, CccdImageValidationResult result})>
      extractAndValidate({
    required String filePath,
    required CccdImageSide side,
    String? explicitQrPayload,
    String? explicitOcrText,
  }) async {
    // 1. Kiểm tra tồn tại file
    final file = File(filePath);
    if (!file.existsSync()) {
      return (
        evidence: null,
        result: const CccdImageValidationResult(
          isValid: false,
          detectedSide: null,
          strictData: null,
          reasonCode: CccdValidationReasonCodes.fileNotFound,
        )
      );
    }

    // 2. Chặn file demo
    final lowerPath = filePath.toLowerCase();
    if (lowerPath.contains('demo_cccd')) {
      return (
        evidence: null,
        result: const CccdImageValidationResult(
          isValid: false,
          detectedSide: null,
          strictData: null,
          reasonCode: CccdValidationReasonCodes.demoImageRejected,
        )
      );
    }

    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      return (
        evidence: null,
        result: const CccdImageValidationResult(
          isValid: false,
          detectedSide: null,
          strictData: null,
          reasonCode: CccdValidationReasonCodes.proofIncomplete,
        )
      );
    }

    // 3. Kiểm định Magic Bytes (JPEG, PNG, WebP) - Không tin cậy extension/MIME
    if (!isValidImageMagicBytes(bytes)) {
      return (
        evidence: null,
        result: const CccdImageValidationResult(
          isValid: false,
          detectedSide: null,
          strictData: null,
          reasonCode: CccdValidationReasonCodes.imageFormatInvalid,
        )
      );
    }

    // 4. Tính toán kích thước ảnh (width, height)
    final dimensions = await _extractDimensions(bytes);
    final width = dimensions.width;
    final height = dimensions.height;

    // 5. Tính toán SHA-256 hash chuẩn
    final hash = computeSha256(bytes);

    // 6. Trích xuất mã QR (đối với mặt trước)
    String? qrPayload = explicitQrPayload;
    if (qrPayload == null && side == CccdImageSide.front) {
      qrPayload = await _scanQrFromFile(filePath);
    }

    // 7. Trích xuất OCR text on-device
    String ocrText = explicitOcrText ?? '';
    if (ocrText.isEmpty) {
      try {
        ocrText = await _ocrEngine.recognizeText(filePath);
      } catch (_) {
        ocrText = '';
      }
    }

    final evidence = CccdImageEvidence(
      side: side,
      normalizedOcrText: ocrText,
      qrPayload: qrPayload,
      imageByteHash: hash,
      width: width,
      height: height,
      byteLength: bytes.length,
      filePath: filePath,
      isDemo: false,
    );

    final result = _validator.validateEvidence(evidence, expectedSide: side);
    return (evidence: evidence, result: result);
  }

  /// Quét mã QR từ file ảnh thông qua mobile_scanner
  Future<String?> _scanQrFromFile(String filePath) async {
    try {
      final controller = MobileScannerController();
      final capture = await controller.analyzeImage(filePath);
      await controller.dispose();

      if (capture != null && capture.barcodes.isNotEmpty) {
        for (final barcode in capture.barcodes) {
          // ignore: deprecated_member_use
          final rawBytes = barcode.rawBytes;
          if (rawBytes != null && rawBytes.isNotEmpty) {
            try {
              final decoded = String.fromCharCodes(rawBytes);
              if (decoded.trim().isNotEmpty) return decoded.trim();
            } catch (_) {}
          }
          final rawVal = barcode.rawValue;
          if (rawVal != null && rawVal.trim().isNotEmpty) {
            return rawVal.trim();
          }
        }
      }
    } catch (_) {
      // Fail-safe: không log path hay exception
    }
    return null;
  }

  /// Trích xuất kích thước ảnh từ bytes (hỗ trợ đọc codec Skia/Impeller)
  static Future<({int width, int height})> _extractDimensions(
      Uint8List bytes) async {
    // Thử đọc header trực tiếp trước
    final headerDim = _parseHeaderDimensions(bytes);
    if (headerDim != null && headerDim.width > 0 && headerDim.height > 0) {
      return headerDim;
    }

    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final w = frame.image.width;
      final h = frame.image.height;
      frame.image.dispose();
      codec.dispose();
      return (width: w, height: h);
    } catch (_) {
      return (width: 0, height: 0);
    }
  }

  /// Phân tích kích thước từ cấu trúc byte (PNG, JPEG, WebP)
  static ({int width, int height})? _parseHeaderDimensions(Uint8List bytes) {
    if (bytes.length < 24) return null;

    // PNG: IHDR chunk bắt đầu tại byte 12, width tại 16..19, height tại 20..23
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E) {
      final w = (bytes[16] << 24) |
          (bytes[17] << 16) |
          (bytes[18] << 8) |
          bytes[19];
      final h = (bytes[20] << 24) |
          (bytes[21] << 16) |
          (bytes[22] << 8) |
          bytes[23];
      return (width: w, height: h);
    }

    // JPEG: Quét các SOF markers (0xFF, 0xC0 .. 0xC3)
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
      int offset = 2;
      while (offset < bytes.length - 8) {
        if (bytes[offset] == 0xFF) {
          final marker = bytes[offset + 1];
          if ((marker >= 0xC0 && marker <= 0xC3) ||
              (marker >= 0xC5 && marker <= 0xC7) ||
              (marker >= 0xC9 && marker <= 0xCB) ||
              (marker >= 0xCD && marker <= 0xCF)) {
            final h = (bytes[offset + 5] << 8) | bytes[offset + 6];
            final w = (bytes[offset + 7] << 8) | bytes[offset + 8];
            return (width: w, height: h);
          }
          final length = (bytes[offset + 2] << 8) | bytes[offset + 3];
          offset += 2 + length;
        } else {
          offset++;
        }
      }
    }

    return null;
  }

  /// Kiểm tra Magic Bytes hợp lệ cho ảnh (JPEG, PNG, WebP)
  static bool isValidImageMagicBytes(List<int> bytes) {
    if (bytes.length < 12) return false;

    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return true;
    }

    // WebP: RIFF ... WEBP
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }

    return false;
  }

  /// Tính toán SHA-256 thuần Dart (NIST FIPS 180-4) chuẩn xác, độc lập 100%
  static String computeSha256(Uint8List data) {
    const k = [
      0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
      0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
      0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
      0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
      0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
      0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
      0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
      0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
      0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
      0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
      0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    ];

    var h0 = 0x6a09e667, h1 = 0xbb67ae85, h2 = 0x3c6ef372, h3 = 0xa54ff53a;
    var h4 = 0x510e527f, h5 = 0x9b05688c, h6 = 0x1f83d9ab, h7 = 0x5be0cd19;

    final length = data.length;
    final bitLength = length * 8;
    final padLength = (length % 64 < 56) ? 64 - (length % 64) : 128 - (length % 64);
    final padded = Uint8List(length + padLength);
    padded.setRange(0, length, data);
    padded[length] = 0x80;

    final bData = ByteData.view(padded.buffer);
    bData.setUint64(padded.length - 8, bitLength, Endian.big);

    final w = Uint32List(64);
    for (var chunk = 0; chunk < padded.length; chunk += 64) {
      for (var i = 0; i < 16; i++) {
        w[i] = bData.getUint32(chunk + (i * 4), Endian.big);
      }
      for (var i = 16; i < 64; i++) {
        final s0 = ((w[i - 15] >> 7) | (w[i - 15] << 25)) ^
            ((w[i - 15] >> 18) | (w[i - 15] << 14)) ^
            (w[i - 15] >> 3);
        final s1 = ((w[i - 2] >> 17) | (w[i - 2] << 15)) ^
            ((w[i - 2] >> 19) | (w[i - 2] << 13)) ^
            (w[i - 2] >> 10);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xFFFFFFFF;
      }

      var a = h0, b = h1, c = h2, d = h3, e = h4, f = h5, g = h6, h = h7;

      for (var i = 0; i < 64; i++) {
        final s1 = ((e >> 6) | (e << 26)) ^
            ((e >> 11) | (e << 21)) ^
            ((e >> 25) | (e << 7));
        final ch = (e & f) ^ (~e & g);
        final temp1 = (h + s1 + ch + k[i] + w[i]) & 0xFFFFFFFF;
        final s0 = ((a >> 2) | (a << 30)) ^
            ((a >> 13) | (a << 19)) ^
            ((a >> 22) | (a << 10));
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = (s0 + maj) & 0xFFFFFFFF;

        h = g;
        g = f;
        f = e;
        e = (d + temp1) & 0xFFFFFFFF;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & 0xFFFFFFFF;
      }

      h0 = (h0 + a) & 0xFFFFFFFF;
      h1 = (h1 + b) & 0xFFFFFFFF;
      h2 = (h2 + c) & 0xFFFFFFFF;
      h3 = (h3 + d) & 0xFFFFFFFF;
      h4 = (h4 + e) & 0xFFFFFFFF;
      h5 = (h5 + f) & 0xFFFFFFFF;
      h6 = (h6 + g) & 0xFFFFFFFF;
      h7 = (h7 + h) & 0xFFFFFFFF;
    }

    return [h0, h1, h2, h3, h4, h5, h6, h7]
        .map((e) => e.toRadixString(16).padLeft(8, '0'))
        .join();
  }
}
