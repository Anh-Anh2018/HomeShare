import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import 'cccd_scanner_screen.dart';

/// Màn hình Xác thực CCCD (eKYC) với 3 mục bắt buộc:
/// 1. Ảnh mặt trước CCCD (Tải lên Firebase Storage & lưu trữ đám mây)
/// 2. Ảnh mặt sau CCCD (Tải lên Firebase Storage & lưu trữ đám mây)
/// 3. Quét lấy thông tin từ mã QR CCCD (hỗ trợ camera hoặc ảnh trong thư viện)
/// Hỗ trợ truy xuất phóng to ảnh thẻ 2 mặt và tự động đồng bộ vào thông tin cá nhân.
class CccdVerificationScreen extends ConsumerStatefulWidget {
  const CccdVerificationScreen({super.key});

  @override
  ConsumerState<CccdVerificationScreen> createState() => _CccdVerificationScreenState();
}

class _CccdVerificationScreenState extends ConsumerState<CccdVerificationScreen> {
  final ImagePicker _picker = ImagePicker();

  XFile? _frontImage;
  XFile? _backImage;
  String? _savedFrontImageUrl;
  String? _savedBackImageUrl;
  CccdData? _cccdData;
  bool _isSubmitting = false;
  bool _isLoadingCloudData = false;

  @override
  void initState() {
    super.initState();
    // Nạp đồng thời từ cache local và Firestore để dữ liệu hiện ra ngay lập tức
    _fetchAndSyncFromFirebase();
  }

  /// Nạp thông tin và ảnh CCCD đã lưu trước đó trên Firebase để người dùng truy xuất
  Future<void> _fetchAndSyncFromFirebase() async {
    final user = ref.read(currentUserProvider);
    final uid = user?.uid;
    if (uid == null || uid.isEmpty) return;

    setState(() => _isLoadingCloudData = true);

    // 1. Nạp tức thì từ SharedPreferences nếu có cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final isVerified = prefs.getBool('cccd_verified_$uid') ?? false;
      final cachedFront = prefs.getString('cccd_front_$uid');
      final cachedBack = prefs.getString('cccd_back_$uid');
      final cachedNumber = prefs.getString('cccd_number_$uid');
      final cachedName = prefs.getString('cccd_name_$uid');
      final cachedHometown = prefs.getString('cccd_hometown_$uid');
      final cachedIssue = prefs.getString('cccd_issue_date_$uid');
      final cachedGender = prefs.getString('cccd_gender_$uid') ?? 'Nam';
      final cachedBirth = prefs.getString('cccd_birth_$uid');

      String bDate = '';
      if (cachedBirth != null && cachedBirth.isNotEmpty) {
        try {
          final dt = DateTime.parse(cachedBirth);
          bDate = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
        } catch (_) {}
      }

      if (mounted && (isVerified || (cachedNumber != null && cachedNumber.isNotEmpty))) {
        setState(() {
          if (cachedFront != null && cachedFront.isNotEmpty && _frontImage == null) {
            _savedFrontImageUrl = cachedFront;
          }
          if (cachedBack != null && cachedBack.isNotEmpty && _backImage == null) {
            _savedBackImageUrl = cachedBack;
          }
          if (_cccdData == null && cachedNumber != null && cachedNumber.isNotEmpty) {
            _cccdData = CccdData(
              idNumber: cachedNumber,
              fullName: cachedName ?? '',
              birthDate: bDate,
              gender: cachedGender,
              address: cachedHometown ?? '',
              issueDate: cachedIssue ?? '',
            );
          }
        });
      }
    } catch (_) {}

    // 2. Fetch trực tiếp từ Cloud Firestore để đảm bảo lấy dữ liệu chuẩn xác nhất
    try {
      final data = await fetchCccdDataFromFirestore(uid: uid);
      if (data != null && mounted) {
        final frontUrl = (data['cccdFrontImageUrl'] ?? data['anhMatTruoc'] ?? data['anhGiayTo_id'] ?? '').toString();
        final backUrl = (data['cccdBackImageUrl'] ?? data['anhMatSau'] ?? '').toString();
        final cccdNum = (data['cccdNumber'] ?? data['soGiayTo'] ?? data['soCccd'] ?? '').toString();
        final cccdName = (data['cccdFullName'] ?? data['hoTenCccd'] ?? data['displayName'] ?? data['hoTen'] ?? '').toString();
        final cccdHometown = (data['cccdHometown'] ?? data['queQuan'] ?? data['diaChiThuongTru'] ?? data['address'] ?? '').toString();
        final cccdIssue = (data['cccdIssueDate'] ?? data['ngayCap'] ?? '').toString();
        final gender = (data['gender'] ?? data['gioiTinh'] ?? 'Nam').toString();

        String bDate = '';
        final rawBirth = data['birthDate'] ?? data['ngaySinh'];
        if (rawBirth is Timestamp) {
          final d = rawBirth.toDate();
          bDate = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
        }

        setState(() {
          if (frontUrl.isNotEmpty && _frontImage == null) {
            _savedFrontImageUrl = frontUrl;
          }
          if (backUrl.isNotEmpty && _backImage == null) {
            _savedBackImageUrl = backUrl;
          }
          if (cccdNum.isNotEmpty) {
            _cccdData = CccdData(
              idNumber: cccdNum,
              fullName: cccdName,
              birthDate: bDate,
              gender: gender,
              address: cccdHometown,
              issueDate: cccdIssue,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('[_fetchAndSyncFromFirebase] Lỗi nạp trực tiếp Firestore: $e');
    } finally {
      if (mounted) setState(() => _isLoadingCloudData = false);
    }
  }

  /// Đồng bộ state từ UserProfile khi Riverpod stream cập nhật
  void _syncFromProfile(UserProfile profile) {
    if (profile.cccdFrontImageUrl.isNotEmpty && _frontImage == null) {
      _savedFrontImageUrl = profile.cccdFrontImageUrl;
    }
    if (profile.cccdBackImageUrl.isNotEmpty && _backImage == null) {
      _savedBackImageUrl = profile.cccdBackImageUrl;
    }
    if (profile.cccdNumber.isNotEmpty && _cccdData == null) {
      String bDate = '';
      if (profile.birthDate != null) {
        final d = profile.birthDate!;
        bDate = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      }
      _cccdData = CccdData(
        idNumber: profile.cccdNumber,
        fullName: profile.cccdFullName.isNotEmpty ? profile.cccdFullName : profile.displayName,
        birthDate: bDate,
        gender: profile.gender,
        address: profile.cccdHometown.isNotEmpty ? profile.cccdHometown : profile.address,
        issueDate: profile.cccdIssueDate,
      );
    }
    if (mounted) setState(() {});
  }

  bool get _hasFront => _frontImage != null || (_savedFrontImageUrl != null && _savedFrontImageUrl!.isNotEmpty);
  bool get _hasBack => _backImage != null || (_savedBackImageUrl != null && _savedBackImageUrl!.isNotEmpty);
  bool get _isComplete => _hasFront && _hasBack && _cccdData != null;

  int get _completedCount {
    int count = 0;
    if (_hasFront) count++;
    if (_hasBack) count++;
    if (_cccdData != null) count++;
    return count;
  }

  List<String> get _missingItems {
    final list = <String>[];
    if (!_hasFront) list.add('Ảnh mặt trước');
    if (!_hasBack) list.add('Ảnh mặt sau');
    if (_cccdData == null) list.add('Quét mã QR');
    return list;
  }

  /// Chọn hoặc chụp ảnh mặt trước/sau
  Future<void> _pickImage(bool isFront, ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1600,
      );
      if (picked != null) {
        setState(() {
          if (isFront) {
            _frontImage = picked;
          } else {
            _backImage = picked;
          }
        });

        // Nếu là ảnh mặt trước và chưa có mã QR: tự động phân tích QR trên ảnh mặt trước!
        if (isFront && _cccdData == null) {
          _tryAutoScanQrFromFrontImage(picked.path);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể truy cập camera hoặc thư viện: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  /// Tự động bóc tách mã QR từ ảnh mặt trước CCCD
  Future<void> _tryAutoScanQrFromFrontImage(String imagePath) async {
    try {
      final controller = MobileScannerController();
      final capture = await controller.analyzeImage(imagePath);
      await controller.dispose();

      if (capture != null && capture.barcodes.isNotEmpty) {
        for (final barcode in capture.barcodes) {
          String rawValue = barcode.rawValue ?? '';
          // ignore: deprecated_member_use
          final List<int>? rawBytes = barcode.rawBytes;
          if (rawBytes != null && rawBytes.isNotEmpty) {
            try {
              final decoded = utf8.decode(rawBytes, allowMalformed: true);
              if (decoded.trim().isNotEmpty) {
                rawValue = decoded;
              }
            } catch (_) {}
          } else if (rawValue.isNotEmpty) {
            try {
              final bytes = latin1.encode(rawValue);
              final fixedUtf8 = utf8.decode(bytes);
              if (fixedUtf8.contains('|')) {
                rawValue = fixedUtf8;
              }
            } catch (_) {}
          }

          final trimmed = rawValue.trim().replaceAll('\uFEFF', '');
          if (trimmed.contains('|') || trimmed.replaceAll(RegExp(r'\D'), '').length >= 12) {
            final cccd = CccdData.fromQrString(trimmed);
            if (mounted) {
              setState(() {
                _cccdData = cccd;
              });
              HapticFeedback.heavyImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Tự động trích xuất thông tin từ mã QR mặt trước: ${cccd.fullName} ✓'),
                  backgroundColor: AppColors.primary,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('[_tryAutoScanQrFromFrontImage] Không tìm thấy mã QR trên ảnh: $e');
    }
  }

  /// Dùng ảnh mẫu demo thử nghiệm khi không có thẻ cứng
  void _useDemoImage(bool isFront) {
    // Tạo XFile tạm thời để mô phỏng ảnh CCCD demo
    setState(() {
      if (isFront) {
        _frontImage = XFile(
          'demo_cccd_front.jpg',
          name: 'demo_cccd_front.jpg',
        );
      } else {
        _backImage = XFile(
          'demo_cccd_back.jpg',
          name: 'demo_cccd_back.jpg',
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isFront
              ? 'Đã tải ảnh mẫu CCCD mặt trước (Dành cho thử nghiệm)'
              : 'Đã tải ảnh mẫu CCCD mặt sau (Dành cho thử nghiệm)',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Hiển thị BottomSheet chọn nguồn ảnh
  void _showImagePickerModal(bool isFront) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                isFront ? 'CHỤP / CHỌN ẢNH MẶT TRƯỚC CCCD' : 'CHỤP / CHỌN ẢNH MẶT SAU CCCD',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isFront
                    ? 'Yêu cầu: Rõ nét họ tên, số CCCD, chân dung, không bị lóa'
                    : 'Yêu cầu: Rõ nét chip điện tử, mã MRZ và đặc điểm nhận dạng',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryContainer,
                  child: Icon(Icons.camera_alt, color: AppColors.primary),
                ),
                title: const Text('Chụp ảnh trực tiếp từ Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Mở máy ảnh để chụp thẻ thật'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(isFront, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryContainer,
                  child: Icon(Icons.photo_library, color: AppColors.primary),
                ),
                title: const Text('Chọn ảnh từ Thư viện (Bộ sưu tập)', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Chọn ảnh đã chụp sẵn trong máy'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(isFront, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.amber.shade100,
                  child: const Icon(Icons.science_outlined, color: Colors.amber),
                ),
                title: const Text('Dùng ảnh mẫu thử nghiệm (Demo)', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Tiện lợi để kiểm thử chức năng khi không có thẻ bên cạnh'),
                onTap: () {
                  Navigator.pop(ctx);
                  _useDemoImage(isFront);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Mở màn hình quét mã QR thẻ CCCD
  Future<void> _scanCccdQr() async {
    final result = await Navigator.push<CccdData>(
      context,
      MaterialPageRoute(
        builder: (_) => const CccdScannerScreen(returnDataOnly: true),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _cccdData = result;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã trích xuất thông tin: ${result.fullName} (${result.idNumber}) ✓'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  /// Quét mã QR thẻ CCCD từ ảnh trong Thư viện ảnh
  Future<void> _scanCccdQrFromGallery() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
      if (picked == null) return;

      final controller = MobileScannerController();
      final capture = await controller.analyzeImage(picked.path);
      await controller.dispose();

      if (capture != null && capture.barcodes.isNotEmpty) {
        for (final barcode in capture.barcodes) {
          String rawValue = barcode.rawValue ?? '';
          // ignore: deprecated_member_use
          final List<int>? rawBytes = barcode.rawBytes;
          if (rawBytes != null && rawBytes.isNotEmpty) {
            try {
              final decoded = utf8.decode(rawBytes, allowMalformed: true);
              if (decoded.trim().isNotEmpty) {
                rawValue = decoded;
              }
            } catch (_) {}
          } else if (rawValue.isNotEmpty) {
            try {
              final bytes = latin1.encode(rawValue);
              final fixedUtf8 = utf8.decode(bytes);
              if (fixedUtf8.contains('|')) {
                rawValue = fixedUtf8;
              }
            } catch (_) {}
          }

          final trimmed = rawValue.trim().replaceAll('\uFEFF', '');
          if (trimmed.contains('|') || trimmed.replaceAll(RegExp(r'\D'), '').length >= 12) {
            final cccd = CccdData.fromQrString(trimmed);
            if (mounted) {
              setState(() {
                _cccdData = cccd;
              });
              HapticFeedback.heavyImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã trích xuất thông tin từ ảnh thư viện: ${cccd.fullName} ✓'),
                  backgroundColor: AppColors.primary,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
            return;
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy mã QR CCCD trên ảnh. Vui lòng chọn ảnh chụp rõ nét mã QR góc phải.'),
            backgroundColor: Colors.amber,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi đọc ảnh thư viện: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Hộp thoại chỉnh sửa thông tin CCCD khi cần bổ sung hoặc điều chỉnh
  void _showEditInfoDialog() {
    if (_cccdData == null) return;
    final currentData = _cccdData!;
    final idController = TextEditingController(text: currentData.idNumber);
    final nameController = TextEditingController(text: currentData.fullName);
    final dobController = TextEditingController(text: currentData.birthDate);
    final genderController = TextEditingController(text: currentData.gender);
    final addrController = TextEditingController(text: currentData.address);
    final issueController = TextEditingController(text: currentData.issueDate);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_note, color: AppColors.primary, size: 24),
            SizedBox(width: 8),
            Text('Chỉnh Sửa Thông Tin CCCD', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idController,
                decoration: const InputDecoration(labelText: 'Số CCCD (12 số)', isDense: true),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Họ và tên', isDense: true),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: dobController,
                      decoration: const InputDecoration(labelText: 'Ngày sinh (dd/MM/yyyy)', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: genderController,
                      decoration: const InputDecoration(labelText: 'Giới tính (Nam/Nữ)', isDense: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addrController,
                decoration: const InputDecoration(labelText: 'Nơi thường trú', isDense: true),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: issueController,
                decoration: const InputDecoration(labelText: 'Ngày cấp (dd/MM/yyyy)', isDense: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _cccdData = CccdData(
                  idNumber: idController.text.trim(),
                  oldCmnd: currentData.oldCmnd,
                  fullName: nameController.text.trim(),
                  birthDate: dobController.text.trim(),
                  gender: genderController.text.trim(),
                  address: addrController.text.trim(),
                  issueDate: issueController.text.trim(),
                );
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã cập nhật thông tin CCCD ✓')),
              );
            },
            child: const Text('Lưu Thay Đổi'),
          ),
        ],
      ),
    );
  }

  /// Đồng bộ thông tin CCCD đã quét sang thông tin cá nhân của người dùng
  Future<void> _syncCccdToProfile() async {
    final user = ref.read(currentUserProvider);
    final uid = user?.uid ?? 'guest_uid';

    final success = await syncCccdToUserProfile(uid: uid);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Đã đồng bộ họ tên, ngày sinh, giới tính, quê quán từ CCCD vào hồ sơ tài khoản! ✓'
              : 'Đã lưu và đồng bộ thông tin CCCD vào thiết bị! ✓'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  /// Dùng dữ liệu CCCD mẫu để test nhanh
  void _useDemoCccdData() {
    setState(() {
      _cccdData = CccdData(
        idNumber: '079201012345',
        oldCmnd: '025896321',
        fullName: 'NGUYỄN VĂN AN',
        birthDate: '15/08/2001',
        gender: 'Nam',
        address: 'Số 123 Võ Văn Ngân, Phường Linh Chiểu, TP. Thủ Đức, TP. Hồ Chí Minh',
        issueDate: '25/12/2021',
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã tải thông tin CCCD mẫu (Dành cho thử nghiệm) ✓'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Nhấn nút Xác thực và lưu toàn bộ thông tin
  Future<void> _submitVerification() async {
    if (!_isComplete || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final user = ref.read(currentUserProvider);
      final uid = user?.uid ?? 'guest_uid';

      DateTime? parsedBirth;
      try {
        final parts = _cccdData!.birthDate.split('/');
        if (parts.length == 3) {
          parsedBirth = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      } catch (_) {}

      final frontPath = _frontImage?.path ?? _savedFrontImageUrl ?? '';
      final backPath = _backImage?.path ?? _savedBackImageUrl ?? '';

      await saveCccdVerificationToBackend(
        uid: uid,
        cccdNumber: _cccdData!.idNumber,
        cccdFullName: _cccdData!.fullName,
        cccdIssueDate: _cccdData!.issueDate,
        cccdHometown: _cccdData!.address,
        gender: _cccdData!.gender,
        birthDate: parsedBirth,
        cccdFrontImageUrl: frontPath,
        cccdBackImageUrl: backPath,
      );

      // Tự động đồng bộ các trường cơ bản sang hồ sơ người dùng
      await syncCccdToUserProfile(uid: uid);

      // Nạp lại trực tiếp từ Firebase để cập nhật các URL Cloud mới nhất
      await _fetchAndSyncFromFirebase();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.verified, color: AppColors.primary, size: 28),
                SizedBox(width: 8),
                Text('Xác Thực Thành Công!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tài khoản của bạn đã hoàn tất quy trình eKYC định danh điện tử. Ảnh 2 mặt và thông tin đã được lưu trữ an toàn trên Firebase Cloud:',
                  style: TextStyle(fontSize: 13.5, color: AppColors.textDark),
                ),
                const SizedBox(height: 10),
                const Text('✓ Ảnh mặt trước thẻ CCCD (Đã lưu cloud)', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                const Text('✓ Ảnh mặt sau thẻ CCCD (Đã lưu cloud)', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                Text('✓ Dữ liệu QR: ${_cccdData!.fullName} - ${_cccdData!.idNumber}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Text(
                    'Ảnh và thông tin CCCD được lưu trữ trên Firebase Cloud, tự động đồng bộ sang hồ sơ cá nhân và hợp đồng thuê phòng.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF15803D)),
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(ctx); // Đóng dialog
                  Navigator.pop(context, true); // Trở về màn hình trước
                },
                child: const Text('Hoàn Tất'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Có lỗi xảy ra khi lưu xác thực: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// Banner trạng thái đồng bộ Firebase Cloud
  Widget _buildCloudSyncBanner({required bool isVerified}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isVerified ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isVerified ? const Color(0xFF86EFAC) : const Color(0xFFBFDBFE),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isVerified ? Icons.verified_user : Icons.cloud_sync,
                color: isVerified ? AppColors.primary : const Color(0xFF1D4ED8),
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVerified
                          ? 'ĐÃ ĐỒNG BỘ DỮ LIỆU TỪ FIREBASE CLOUD'
                          : 'KẾT NỐI ĐỒNG BỘ ĐÁM MÂY (FIREBASE)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isVerified ? AppColors.primary : const Color(0xFF1E40AF),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isVerified
                          ? 'Ảnh 2 mặt & thông tin CCCD được lưu trữ an toàn trên Cloud Firestore & Storage.'
                          : 'Toàn bộ ảnh chụp và thông tin quét được sẽ lưu trực tiếp lên Firebase Cloud.',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              if (_isLoadingCloudData)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (isVerified) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.sync, size: 16, color: AppColors.primary),
                    label: const Text('Đồng bộ vào Hồ sơ', style: TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.bold)),
                    onPressed: _syncCccdToProfile,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      side: const BorderSide(color: Color(0xFF0284C7)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF0284C7)),
                    label: const Text('Tải lại từ Cloud', style: TextStyle(fontSize: 11.5, color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
                    onPressed: _fetchAndSyncFromFirebase,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe cập nhật thời gian thực từ Firestore
    ref.listen<AsyncValue<UserProfile?>>(userProfileProvider, (prev, next) {
      final p = next.value;
      if (p != null) {
        _syncFromProfile(p);
      }
    });

    final profile = ref.watch(userProfileProvider).value;
    final bool isVerifiedOnCloud = (profile?.isCccdVerified == true) || (_savedFrontImageUrl != null && _cccdData != null);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Xác thực CCCD (eKYC)'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_sync_outlined),
            tooltip: 'Đồng bộ từ Firebase',
            onPressed: _fetchAndSyncFromFirebase,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner trạng thái đồng bộ Firebase Cloud
            _buildCloudSyncBanner(isVerified: isVerifiedOnCloud),

            // Thanh tiến độ 3 mục
            _buildProgressCard(),

            const SizedBox(height: 16),

            // Mục 1: Ảnh mặt trước CCCD
            _buildImageUploadCard(
              title: 'Mục 1: Lưu ảnh mặt trước CCCD',
              subtitle: 'Chụp rõ nét mặt trước (ảnh chân dung, số CCCD, họ tên, mã QR)',
              image: _frontImage,
              savedImageUrl: _savedFrontImageUrl,
              isFront: true,
            ),

            const SizedBox(height: 16),

            // Mục 2: Ảnh mặt sau CCCD
            _buildImageUploadCard(
              title: 'Mục 2: Lưu ảnh mặt sau CCCD',
              subtitle: 'Chụp rõ nét mặt sau (chip điện tử, mã MRZ)',
              image: _backImage,
              savedImageUrl: _savedBackImageUrl,
              isFront: false,
            ),

            const SizedBox(height: 16),

            // Mục 3: Quét lấy thông tin mã CCCD
            _buildQrScanCard(),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActionBar(),
    );
  }

  /// Card tiến độ hoàn thành các bước
  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quy trình xác thực định danh',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _isComplete ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_completedCount/3 mục',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _isComplete ? AppColors.primary : const Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _completedCount / 3,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(_isComplete ? AppColors.primary : Colors.amber.shade700),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStepIndicator(1, 'Mặt trước', _hasFront),
              const SizedBox(width: 8),
              _buildStepIndicator(2, 'Mặt sau', _hasBack),
              const SizedBox(width: 8),
              _buildStepIndicator(3, 'Quét mã QR', _cccdData != null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, bool isDone) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: isDone ? const Color(0xFFECFDF5) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDone ? const Color(0xFF6EE7B7) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isDone ? Icons.check_circle : Icons.circle_outlined,
              size: 14,
              color: isDone ? AppColors.primary : Colors.grey.shade500,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                  color: isDone ? AppColors.primary : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hộp thoại truy xuất và xem ảnh thẻ CCCD phóng to (Zoom & Pan)
  void _showFullImageDialog({
    required String title,
    XFile? localImage,
    String? imageUrl,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: Color(0xFF38BDF8), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            Container(
              constraints: const BoxConstraints(maxHeight: 380),
              color: Colors.black,
              width: double.infinity,
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: _buildImageWidget(localImage: localImage, imageUrl: imageUrl),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_done_outlined, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Ảnh được lưu trữ an toàn trên Firebase, phục vụ truy xuất đối chiếu danh tính.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Đóng', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget hiển thị ảnh linh hoạt: XFile, URL Firebase, Base64 Data URI
  Widget _buildImageWidget({XFile? localImage, String? imageUrl}) {
    if (localImage != null) {
      if (File(localImage.path).existsSync()) {
        return Image.file(File(localImage.path), fit: BoxFit.contain);
      } else {
        return Container(
          color: const Color(0xFF0369A1),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.badge, size: 56, color: Colors.white),
              const SizedBox(height: 10),
              Text(
                localImage.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              const Text('✓ Tệp demo sẵn sàng lưu trữ', style: TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        );
      }
    }

    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
        return Image.network(
          imageUrl,
          fit: BoxFit.contain,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return const Center(child: CircularProgressIndicator());
          },
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Icon(Icons.broken_image, color: Colors.white, size: 48),
          ),
        );
      } else if (imageUrl.startsWith('data:image')) {
        try {
          final base64Data = imageUrl.split(',').last;
          return Image.memory(base64Decode(base64Data), fit: BoxFit.contain);
        } catch (_) {}
      } else if (File(imageUrl).existsSync()) {
        return Image.file(File(imageUrl), fit: BoxFit.contain);
      }
    }

    return const Center(child: Icon(Icons.image_not_supported, color: Colors.white, size: 48));
  }

  /// Khung tải ảnh mặt trước hoặc mặt sau
  Widget _buildImageUploadCard({
    required String title,
    required String subtitle,
    required XFile? image,
    required String? savedImageUrl,
    required bool isFront,
  }) {
    final bool hasImage = image != null || (savedImageUrl != null && savedImageUrl.isNotEmpty);
    final bool isFromCloud = image == null && (savedImageUrl != null && savedImageUrl.isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasImage ? const Color(0xFF86EFAC) : Colors.grey.shade300,
          width: hasImage ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasImage ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isFromCloud ? 'Đã lưu Cloud ✓' : (hasImage ? 'Đã có ảnh ✓' : 'Bắt buộc'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: hasImage ? AppColors.primary : Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 12),

          // Khung hiển thị ảnh hoặc ô bấm chụp
          if (hasImage)
            _buildImagePreview(localImage: image, savedUrl: savedImageUrl, isFront: isFront)
          else
            _buildEmptyImagePlaceholder(isFront),
        ],
      ),
    );
  }

  /// Placeholder khi chưa có ảnh
  Widget _buildEmptyImagePlaceholder(bool isFront) {
    return InkWell(
      onTap: () => _showImagePickerModal(isFront),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primaryContainer,
                child: Icon(
                  isFront ? Icons.credit_card : Icons.flip_to_back,
                  size: 28,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isFront ? 'Chạm để chụp / tải ảnh mặt trước' : 'Chạm để chụp / tải ảnh mặt sau',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark),
              ),
              const SizedBox(height: 4),
              const Text(
                'Camera, Thư viện ảnh hoặc Ảnh mẫu thử nghiệm',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Preview khi đã có ảnh (Hỗ trợ truy xuất & phóng to ảnh)
  Widget _buildImagePreview({
    required XFile? localImage,
    required String? savedUrl,
    required bool isFront,
  }) {
    final bool isFromCloud = localImage == null && savedUrl != null && savedUrl.isNotEmpty;
    final String cardTitle = isFront ? 'Ảnh mặt trước CCCD' : 'Ảnh mặt sau CCCD';

    return Column(
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: () => _showFullImageDialog(
                title: cardTitle,
                localImage: localImage,
                imageUrl: savedUrl,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 165,
                  width: double.infinity,
                  color: Colors.grey.shade100,
                  child: _buildImageWidget(localImage: localImage, imageUrl: savedUrl),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: InkWell(
                onTap: () => _showFullImageDialog(
                  title: cardTitle,
                  localImage: localImage,
                  imageUrl: savedUrl,
                ),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_in, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Truy xuất / Phóng to',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (isFromCloud)
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_done, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Đã lưu trên Firebase Cloud',
                        style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () => _showImagePickerModal(isFront),
              icon: const Icon(Icons.refresh, size: 16, color: AppColors.primary),
              label: Text(
                isFromCloud ? 'Chụp / Tải ảnh thay thế' : 'Chụp lại / Đổi ảnh',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  if (isFront) {
                    _frontImage = null;
                    _savedFrontImageUrl = null;
                  } else {
                    _backImage = null;
                    _savedBackImageUrl = null;
                  }
                });
              },
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
              label: const Text('Xóa', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ],
    );
  }

  /// Thẻ quét mã QR CCCD
  Widget _buildQrScanCard() {
    final bool hasQr = _cccdData != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasQr ? const Color(0xFF86EFAC) : Colors.grey.shade300,
          width: hasQr ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Mục 3: Quét lấy thông tin mã CCCD',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasQr ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  hasQr ? 'Đã trích xuất ✓' : 'Bắt buộc',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: hasQr ? AppColors.primary : Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Quét mã QR góc trên bên phải thẻ CCCD để lấy thông tin thật 100%',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),

          if (hasQr)
            _buildQrDataPreview(_cccdData!)
          else
            _buildEmptyQrPlaceholder(),
        ],
      ),
    );
  }

  /// Placeholder khi chưa quét QR
  Widget _buildEmptyQrPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _scanCccdQr,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.qr_code_scanner, size: 24, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mở Camera Quét Mã QR CCCD',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.primary),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Hướng camera vào mã QR góc phải mặt trước thẻ',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    side: const BorderSide(color: Color(0xFF0284C7)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.photo_library_outlined, size: 16, color: Color(0xFF0284C7)),
                  label: const Text(
                    'Quét từ Ảnh Thư Viện',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0284C7)),
                  ),
                  onPressed: _scanCccdQrFromGallery,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    side: BorderSide(color: Colors.amber.shade700),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(Icons.science_outlined, size: 16, color: Colors.amber.shade800),
                  label: Text(
                    'Thử Dữ Liệu Mẫu',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
                  ),
                  onPressed: _useDemoCccdData,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Hiển thị thông tin trích xuất từ QR
  Widget _buildQrDataPreview(CccdData cccd) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'THÔNG TIN ĐÃ ĐỒNG BỘ TỪ CCCD',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green.shade900),
                ),
              ),
              InkWell(
                onTap: _showEditInfoDialog,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, size: 11, color: AppColors.primary),
                      SizedBox(width: 2),
                      Text('Sửa', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _scanCccdQr,
                child: const Text('Quét lại', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(height: 16),
          _buildInfoRow('Số CCCD:', cccd.idNumber, isHighlight: true),
          const SizedBox(height: 6),
          _buildInfoRow('Họ và tên:', cccd.fullName, isBold: true),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _buildInfoRow('Ngày sinh:', cccd.birthDate)),
              Expanded(child: _buildInfoRow('Giới tính:', cccd.gender)),
            ],
          ),
          if (cccd.provinceName != null) ...[
            const SizedBox(height: 6),
            _buildInfoRow('Nơi sinh:', cccd.provinceName!),
          ],
          const SizedBox(height: 6),
          _buildInfoRow('Thường trú:', cccd.address),
          const SizedBox(height: 6),
          _buildInfoRow('Ngày cấp:', cccd.issueDate),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlight = false, bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 85,
          child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: (isHighlight || isBold) ? FontWeight.bold : FontWeight.w500,
              color: isHighlight ? AppColors.primary : AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }

  /// Thanh hành động dưới cùng (Khóa nút nếu chưa đủ 3 mục)
  Widget _buildBottomActionBar() {
    final bool hasNewChanges = _frontImage != null || _backImage != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thông báo điều kiện xác thực
            if (!_isComplete)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.red),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Thiếu: ${_missingItems.join(', ')}. Cần đủ cả 3 mục để mở nút xác thực.',
                        style: const TextStyle(fontSize: 11.5, color: Colors.red, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hasNewChanges
                            ? 'Đã đủ 3 mục và có ảnh mới! Nhấn để lưu lên Firebase Cloud.'
                            : 'Đã hoàn tất 3/3 mục! Dữ liệu đã được lưu trữ và đồng bộ trên Cloud.',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

            // NÚT XÁC THỰC: Bị DISABLED (onPressed: null) nếu chưa đủ 3 mục
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isComplete ? AppColors.primary : Colors.grey.shade300,
                foregroundColor: _isComplete ? Colors.white : Colors.grey.shade500,
                elevation: _isComplete ? 2 : 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: (_isComplete && !_isSubmitting) ? _submitVerification : null,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isComplete ? Icons.cloud_upload : Icons.lock_outline,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          !_isComplete
                              ? 'CHƯA ĐỦ ĐIỀU KIỆN XÁC THỰC ($_completedCount/3)'
                              : (hasNewChanges ? 'LƯU & ĐỒNG BỘ LÊN FIREBASE CLOUD' : 'CẬP NHẬT / LƯU LẠI CCCD'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _isComplete ? Colors.white : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
