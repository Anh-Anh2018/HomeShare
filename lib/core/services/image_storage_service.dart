import 'dart:convert';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

/// Nén ảnh phòng về JPEG nhỏ để nhét vừa tài liệu Firestore
/// và để tài khoản khác giải mã được mà không cần file trên máy đăng bài.
Uint8List compressRoomPhoto(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;

  final oriented = img.bakeOrientation(decoded);
  var working = oriented.width > 1280
      ? img.copyResize(oriented, width: 1280)
      : oriented;

  var quality = 62;
  var encoded = img.encodeJpg(working, quality: quality);
  while (encoded.length > 90 * 1024 && quality > 36) {
    quality -= 8;
    encoded = img.encodeJpg(working, quality: quality);
  }

  if (encoded.length > 110 * 1024) {
    working = img.copyResize(working, width: 960);
    encoded = img.encodeJpg(working, quality: 40);
  }

  return Uint8List.fromList(encoded);
}

/// Lưu ảnh phòng sao cho mọi tài khoản đọc bài đăng đều thấy đúng ảnh đã chọn.
///
/// 1. Nén JPEG trước khi gửi.
/// 2. Ưu tiên Firebase Storage để lấy `downloadUrl`.
/// 3. Nếu Storage lỗi, ghi Data URI của chính ảnh đã nén vào Firestore.
/// Không thay ảnh người dùng bằng ảnh mẫu.
class ImageStorageService {
  final FirebaseStorage? _customStorage;

  ImageStorageService({FirebaseStorage? storage}) : _customStorage = storage;

  FirebaseStorage get _storage => _customStorage ?? FirebaseStorage.instance;

  /// Trả về URL hoặc Data URI. Chuỗi rỗng khi không có ảnh thật để chia sẻ.
  Future<String> uploadSingleImage({
    required String filePath,
    required String folder,
    required String fileName,
    int sampleIndex = 0,
  }) async {
    if (filePath.startsWith('http://') ||
        filePath.startsWith('https://') ||
        filePath.startsWith('data:image')) {
      return filePath;
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      debugPrint('[ImageStorageService] Không có file tại $filePath, bỏ qua ảnh này.');
      return '';
    }

    final Uint8List compressed;
    try {
      final raw = await file.readAsBytes();
      compressed = await compute(compressRoomPhoto, raw);
    } catch (e) {
      debugPrint('[ImageStorageService] Không nén được ảnh: $e');
      return '';
    }

    try {
      final storageRef = _storage.ref().child('$folder/$fileName');
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'uploadedAt': DateTime.now().toIso8601String()},
      );
      final snapshot = await storageRef
          .putData(compressed, metadata)
          .timeout(const Duration(seconds: 20));
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('[ImageStorageService] Đã tải ảnh lên Storage: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('[ImageStorageService] Storage không dùng được ($e), lưu JPEG vào bài đăng.');
      return 'data:image/jpeg;base64,${base64Encode(compressed)}';
    }
  }

  /// Tải danh sách ảnh của một bài đăng. Bỏ qua ảnh không lưu được.
  Future<List<String>> uploadRoommateImages({
    required List<String> localPaths,
    required String postId,
  }) async {
    if (localPaths.isEmpty) return [];

    final uploadedUrls = <String>[];
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    var embeddedBytes = 0;

    for (int i = 0; i < localPaths.length; i++) {
      final url = await uploadSingleImage(
        filePath: localPaths[i],
        folder: 'roommate_posts/$postId',
        fileName: '${postId}_img_${timestamp}_$i.jpg',
        sampleIndex: i,
      );
      if (url.isEmpty) continue;
      if (url.startsWith('data:image')) {
        if (embeddedBytes + url.length > 720000) {
          debugPrint('[ImageStorageService] Bỏ ảnh thứ ${i + 1} vì bài đăng sắp vượt giới hạn Firestore.');
          continue;
        }
        embeddedBytes += url.length;
      }
      uploadedUrls.add(url);
    }

    return uploadedUrls;
  }
}

final imageStorageServiceProvider = Provider<ImageStorageService>((ref) {
  return ImageStorageService();
});
