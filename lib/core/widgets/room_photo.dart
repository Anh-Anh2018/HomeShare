import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Ảnh phòng trong bài đăng.
/// Đọc được trên mọi tài khoản: URL công khai, Data URI Base64 đã lưu trên
/// Firestore, hoặc file cục bộ còn nằm trên chính máy đăng bài.
/// Đường dẫn máy khác không được thay bằng ảnh mẫu.
class RoomPhoto extends StatefulWidget {
  const RoomPhoto({
    super.key,
    required this.imageRef,
    this.iconSize = 48,
    this.memCacheWidth = 720,
  });

  final String imageRef;
  final double iconSize;

  /// Giải mã bitmap theo bề rộng hiển thị để danh sách không lag.
  final int memCacheWidth;

  static final Map<int, Uint8List> _decoded = {};
  static final List<int> _decodedOrder = [];
  static const int _decodedLimit = 24;

  static int _cacheKey(String ref) {
    final head = ref.length >= 48 ? ref.substring(ref.length - 48) : ref;
    return Object.hash(ref.length, ref.hashCode, head);
  }

  @override
  State<RoomPhoto> createState() => _RoomPhotoState();
}

class _RoomPhotoState extends State<RoomPhoto> {
  Uint8List? _bytes;
  String? _filePath;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _primeCache();
    _resolve();
  }

  @override
  void didUpdateWidget(RoomPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageRef != widget.imageRef) {
      _bytes = null;
      _filePath = null;
      _loading = false;
      _primeCache();
      _resolve();
    }
  }

  void _primeCache() {
    final ref = widget.imageRef.trim();
    if (!ref.startsWith('data:image')) return;
    final cached = RoomPhoto._decoded[RoomPhoto._cacheKey(ref)];
    if (cached != null) {
      _bytes = cached;
    } else {
      _loading = true;
    }
  }

  Future<void> _resolve() async {
    final ref = widget.imageRef.trim();
    if (ref.isEmpty || ref.startsWith('http://') || ref.startsWith('https://') || _bytes != null) {
      return;
    }

    if (ref.startsWith('data:image')) {
      final key = RoomPhoto._cacheKey(ref);
      try {
        final commaIdx = ref.indexOf(',');
        final payload = commaIdx >= 0 ? ref.substring(commaIdx + 1) : ref;
        final bytes = await compute(base64Decode, payload);
        if (!mounted || widget.imageRef.trim() != ref) return;
        if (RoomPhoto._decodedOrder.length >= RoomPhoto._decodedLimit) {
          RoomPhoto._decoded.remove(RoomPhoto._decodedOrder.removeAt(0));
        }
        RoomPhoto._decoded[key] = bytes;
        RoomPhoto._decodedOrder.add(key);
        setState(() {
          _bytes = bytes;
          _loading = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _loading = false);
      }
      return;
    }

    try {
      final exists = await File(ref).exists();
      if (mounted && exists) setState(() => _filePath = ref);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final ref = widget.imageRef.trim();
    if (ref.isEmpty) return _placeholder();

    if (ref.startsWith('http://') || ref.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: ref,
        fit: BoxFit.cover,
        memCacheWidth: widget.memCacheWidth,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (_, _) => _placeholder(),
        errorWidget: (_, _, _) => _placeholder(),
      );
    }

    if (_bytes != null) {
      return Image.memory(
        _bytes!,
        fit: BoxFit.cover,
        cacheWidth: widget.memCacheWidth,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }

    if (_filePath != null) {
      return Image.file(
        File(_filePath!),
        fit: BoxFit.cover,
        cacheWidth: widget.memCacheWidth,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }

    return _placeholder(showProgress: _loading);
  }

  Widget _placeholder({bool showProgress = false}) {
    return Container(
      color: const Color(0xFFF2F4F7),
      alignment: Alignment.center,
      child: showProgress
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF667085)),
            )
          : Icon(Icons.image_outlined, color: const Color(0xFF667085), size: widget.iconSize),
    );
  }
}
