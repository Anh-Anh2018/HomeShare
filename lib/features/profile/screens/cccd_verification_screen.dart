import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../models/cccd_data.dart';
import '../models/cccd_validation_models.dart';
import '../services/cccd_image_evidence_extractor.dart';
import '../services/cccd_image_evidence_validator.dart';

/// Trạng thái thẩm định On-Device cho từng mặt của thẻ CCCD
enum CccdSideValidationStatus { idle, validating, valid, invalid }

/// Màn hình Xác thực CCCD (eKYC) với cơ chế thẩm định On-Device Fail-Closed:
/// 1. Ảnh mặt trước CCCD (Bắt buộc nhận diện markers mặt trước + QR strict)
/// 2. Ảnh mặt sau CCCD (Bắt buộc nhận diện markers mặt sau / chip / MRZ)
/// 3. Dữ liệu trích xuất tự động từ mã QR strict của mặt trước
/// 4. Xây dựng Proof xác thực đầy đủ trước khi cho phép lưu lên Firebase Cloud
class CccdVerificationScreen extends ConsumerStatefulWidget {
  const CccdVerificationScreen({super.key});

  @override
  ConsumerState<CccdVerificationScreen> createState() => _CccdVerificationScreenState();
}

class _CccdVerificationScreenState extends ConsumerState<CccdVerificationScreen> {
  static const CccdImageEvidenceValidator _validator = CccdImageEvidenceValidator();
  static const CccdImageEvidenceExtractor _extractor = CccdImageEvidenceExtractor();

  final ImagePicker _picker = ImagePicker();

  XFile? _frontImage;
  XFile? _backImage;
  String? _savedFrontImageUrl;
  String? _savedBackImageUrl;
  CccdData? _cccdData;

  CccdImageEvidence? _frontEvidence;
  CccdImageEvidence? _backEvidence;
  CccdValidationProof? _proof;

  CccdSideValidationStatus _frontStatus = CccdSideValidationStatus.idle;
  CccdSideValidationStatus _backStatus = CccdSideValidationStatus.idle;

  String? _frontError;
  String? _backError;

  bool _isSubmitting = false;
  bool _isLoadingCloudData = false;

  @override
  void initState() {
    super.initState();
    _fetchAndSyncFromFirebase();
  }

  /// Nạp thông tin và ảnh CCCD lịch sử trên Firebase để hiển thị tham khảo
  /// Tuyệt đối không tạo evidence, proof hoặc gán status valid từ URL lịch sử
  Future<void> _fetchAndSyncFromFirebase() async {
    final user = ref.read(currentUserProvider);
    final uid = user?.uid;
    if (uid == null || uid.isEmpty) return;

    setState(() => _isLoadingCloudData = true);

    // 1. Nạp từ cache SharedPreferences
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

    // 2. Fetch từ Cloud Firestore
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
          if (cccdNum.isNotEmpty && _cccdData == null) {
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
    } catch (_) {
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

  /// Điều kiện hoàn thành bắt buộc phải có Proof hợp lệ từ Validator
  /// URL legacy hoặc _cccdData không bao giờ làm _isComplete thành true
  bool get _isComplete =>
      _validator.canSave(_proof) &&
      _frontStatus != CccdSideValidationStatus.validating &&
      _backStatus != CccdSideValidationStatus.validating &&
      !_isSubmitting;

  int get _completedCount {
    int count = 0;
    if (_frontStatus == CccdSideValidationStatus.valid) count++;
    if (_backStatus == CccdSideValidationStatus.valid) count++;
    if (_cccdData != null) count++;
    return count;
  }

  List<String> get _missingItems {
    final list = <String>[];
    if (_frontStatus != CccdSideValidationStatus.valid) list.add('Ảnh mặt trước hợp lệ');
    if (_backStatus != CccdSideValidationStatus.valid) list.add('Ảnh mặt sau hợp lệ');
    if (_proof == null) list.add('Bằng chứng xác minh 2 mặt');
    return list;
  }

  /// Chuyển đổi mã lỗi sang thông điệp tiếng Việt thân thiện, bảo mật (không lộ raw OCR/path/PII)
  String _safeReasonToVietnamese(String? code) {
    switch (code) {
      case CccdValidationReasonCodes.fileNotFound:
        return 'Không tìm thấy tệp ảnh.';
      case CccdValidationReasonCodes.demoImageRejected:
        return 'Ảnh thử nghiệm không được phép sử dụng để xác thực.';
      case CccdValidationReasonCodes.imageFormatInvalid:
        return 'Định dạng ảnh không hợp lệ (hỗ trợ JPEG, PNG, WebP).';
      case CccdValidationReasonCodes.imageTooSmall:
        return 'Dung lượng ảnh quá nhỏ (tối thiểu 20KB). Vui lòng chụp rõ nét hơn.';
      case CccdValidationReasonCodes.imageTooLarge:
        return 'Dung lượng ảnh vượt quá giới hạn (tối đa 15MB).';
      case CccdValidationReasonCodes.resolutionTooLow:
        return 'Độ phân giải ảnh quá thấp (tối thiểu 600x400). Vui lòng chụp cận cảnh thẻ.';
      case CccdValidationReasonCodes.qrMissingOrInvalid:
      case CccdValidationReasonCodes.qrMissingRequiredFields:
        return 'Không tìm thấy mã QR hoặc mã QR trên mặt trước CCCD không đúng định dạng.';
      case CccdValidationReasonCodes.invalidIdNumber:
      case CccdValidationReasonCodes.invalidDate:
        return 'Thông tin trên thẻ hoặc mã QR không hợp lệ.';
      case CccdValidationReasonCodes.frontMarkersMissing:
        return 'Ảnh không có đủ dấu hiệu nhận diện của mặt trước CCCD.';
      case CccdValidationReasonCodes.backMarkersInsufficient:
        return 'Ảnh không có đủ dấu hiệu nhận diện của mặt sau CCCD (chip/MRZ).';
      case CccdValidationReasonCodes.wrongSideDetected:
        return 'Ảnh tải lên sai mặt thẻ CCCD. Vui lòng kiểm tra lại.';
      case CccdValidationReasonCodes.duplicateImageHash:
        return 'Ảnh mặt trước và mặt sau bị trùng lặp. Vui lòng chụp riêng từng mặt.';
      case CccdValidationReasonCodes.proofIncomplete:
        return 'Thông tin bằng chứng xác thực chưa đầy đủ 2 mặt.';
      case CccdValidationReasonCodes.legacyUrlNotAllowed:
        return 'Không được sử dụng ảnh cũ để xác thực.';
      default:
        return 'Ảnh không đạt chuẩn xác thực CCCD. Vui lòng chụp lại rõ nét.';
    }
  }

  /// Chọn và thẩm định ảnh CCCD on-device (Fail-Closed)
  Future<void> _pickImage(bool isFront, ImageSource source) async {
    final currentStatus = isFront ? _frontStatus : _backStatus;
    if (currentStatus == CccdSideValidationStatus.validating) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 95,
        maxWidth: 1600,
      );
      if (picked == null) return;
      if (!mounted) return;

      // Đặt trạng thái validating nhưng giữ nguyên ảnh/evidence hợp lệ cũ
      setState(() {
        if (isFront) {
          _frontStatus = CccdSideValidationStatus.validating;
          _frontError = null;
        } else {
          _backStatus = CccdSideValidationStatus.validating;
          _backError = null;
        }
      });

      final validation = await _extractor.extractAndValidate(
        filePath: picked.path,
        side: isFront ? CccdImageSide.front : CccdImageSide.back,
      );

      if (!mounted) return;

      if (validation.result.isValid && validation.evidence != null) {
        setState(() {
          if (isFront) {
            _frontImage = picked;
            _frontEvidence = validation.evidence;
            _frontStatus = CccdSideValidationStatus.valid;
            _frontError = null;
            _cccdData = validation.result.strictData;
          } else {
            _backImage = picked;
            _backEvidence = validation.evidence;
            _backStatus = CccdSideValidationStatus.valid;
            _backError = null;
          }

          // Kiểm tra tạo Proof nếu cả 2 mặt đều đã có evidence
          if (_frontEvidence != null && _backEvidence != null) {
            final proofCandidate = _validator.createProof(
              frontEvidence: _frontEvidence!,
              backEvidence: _backEvidence!,
            );
            if (_validator.canSave(proofCandidate)) {
              _proof = proofCandidate;
            } else {
              _proof = null;
              final errMsg = _safeReasonToVietnamese(proofCandidate.rejectionReasonCode);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(errMsg), backgroundColor: Colors.red),
              );
            }
          }
        });
      } else {
        // Thẩm định không đạt: giữ nguyên ảnh/evidence hợp lệ cũ, thông báo lỗi an toàn
        final errMsg = _safeReasonToVietnamese(validation.result.reasonCode);
        setState(() {
          if (isFront) {
            _frontStatus = CccdSideValidationStatus.invalid;
            _frontError = errMsg;
          } else {
            _backStatus = CccdSideValidationStatus.invalid;
            _backError = errMsg;
          }
          if (_frontEvidence == null || _backEvidence == null) {
            _proof = null;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errMsg), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (!mounted) return;
      const genericErr = 'Có lỗi xảy ra khi xử lý ảnh CCCD. Vui lòng thử lại.';
      setState(() {
        if (isFront) {
          _frontStatus = CccdSideValidationStatus.invalid;
          _frontError = genericErr;
        } else {
          _backStatus = CccdSideValidationStatus.invalid;
          _backError = genericErr;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(genericErr), backgroundColor: Colors.red),
      );
    }
  }

  /// Xóa ảnh và bằng chứng của một mặt
  void _clearSide(bool isFront) {
    setState(() {
      if (isFront) {
        _frontImage = null;
        _frontEvidence = null;
        _frontStatus = CccdSideValidationStatus.idle;
        _frontError = null;
        _cccdData = null;
      } else {
        _backImage = null;
        _backEvidence = null;
        _backStatus = CccdSideValidationStatus.idle;
        _backError = null;
      }
      _proof = null;
    });
  }

  /// Hiển thị BottomSheet chọn nguồn ảnh (Camera / Gallery thật, không có Demo)
  void _showImagePickerModal(bool isFront) {
    final isValidating = (isFront ? _frontStatus : _backStatus) == CccdSideValidationStatus.validating;
    if (isValidating) return;

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
                    ? 'Yêu cầu: Rõ nét họ tên, số CCCD, chân dung, mã QR, không bị lóa'
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
            ],
          ),
        ),
      ),
    );
  }

  /// Nhấn nút Xác thực và lưu toàn bộ thông tin qua Save Boundary
  Future<void> _submitVerification() async {
    if (!_isComplete || _isSubmitting || _proof == null) return;

    final user = ref.read(currentUserProvider);
    final uid = user?.uid;
    if (uid == null || uid.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      await saveCccdVerificationToBackend(
        uid: uid,
        proof: _proof!,
      );

      // Tự động đồng bộ sang hồ sơ người dùng
      await syncCccdToUserProfile(uid: uid);

      // Nạp lại trực tiếp từ Firebase để cập nhật URL Cloud mới nhất
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
                  'Tài khoản của bạn đã hoàn tất quy trình eKYC định danh điện tử. Ảnh 2 mặt và bằng chứng xác thực đã được lưu trữ an toàn trên Firebase Cloud:',
                  style: TextStyle(fontSize: 13.5, color: AppColors.textDark),
                ),
                const SizedBox(height: 10),
                const Text('✓ Ảnh mặt trước thẻ CCCD (Đã xác thực & lưu cloud)', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                const Text('✓ Ảnh mặt sau thẻ CCCD (Đã xác thực & lưu cloud)', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                const Text('✓ Bằng chứng xác thực bảo mật eKYC v1', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
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
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
                },
                child: const Text('Hoàn Tất'),
              ),
            ],
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Có lỗi xảy ra khi lưu xác thực CCCD. Vui lòng thử lại.'),
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
                          : 'Toàn bộ ảnh chụp và thông tin hợp lệ sẽ lưu trực tiếp lên Firebase Cloud.',
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

            // Thanh tiến độ
            _buildProgressCard(),

            const SizedBox(height: 16),

            // Mục 1: Ảnh mặt trước CCCD
            _buildImageUploadCard(
              title: 'Mục 1: Ảnh mặt trước CCCD',
              subtitle: 'Chụp rõ nét mặt trước (ảnh chân dung, số CCCD, họ tên, mã QR)',
              image: _frontImage,
              savedImageUrl: _savedFrontImageUrl,
              isFront: true,
            ),

            const SizedBox(height: 16),

            // Mục 2: Ảnh mặt sau CCCD
            _buildImageUploadCard(
              title: 'Mục 2: Ảnh mặt sau CCCD',
              subtitle: 'Chụp rõ nét mặt sau (chip điện tử, mã MRZ)',
              image: _backImage,
              savedImageUrl: _savedBackImageUrl,
              isFront: false,
            ),

            const SizedBox(height: 16),

            // Mục 3: Thông tin định danh từ QR CCCD
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
              _buildStepIndicator(1, 'Mặt trước', _frontStatus == CccdSideValidationStatus.valid),
              const SizedBox(width: 8),
              _buildStepIndicator(2, 'Mặt sau', _backStatus == CccdSideValidationStatus.valid),
              const SizedBox(width: 8),
              _buildStepIndicator(3, 'Dữ liệu QR', _cccdData != null),
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

  /// Hộp thoại xem ảnh thẻ CCCD phóng to (Zoom & Pan)
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

  /// Widget hiển thị ảnh: XFile hoặc URL Firebase
  Widget _buildImageWidget({XFile? localImage, String? imageUrl}) {
    if (localImage != null && File(localImage.path).existsSync()) {
      return Image.file(File(localImage.path), fit: BoxFit.contain);
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
      } else if (File(imageUrl).existsSync()) {
        return Image.file(File(imageUrl), fit: BoxFit.contain);
      }
    }

    return const Center(child: Icon(Icons.image_not_supported, color: Colors.grey, size: 48));
  }

  /// Khung tải ảnh mặt trước hoặc mặt sau
  Widget _buildImageUploadCard({
    required String title,
    required String subtitle,
    required XFile? image,
    required String? savedImageUrl,
    required bool isFront,
  }) {
    final status = isFront ? _frontStatus : _backStatus;
    final bool isValidating = status == CccdSideValidationStatus.validating;
    final bool isValid = status == CccdSideValidationStatus.valid;
    final bool hasImage = image != null || (savedImageUrl != null && savedImageUrl.isNotEmpty);
    final bool isFromCloud = image == null && (savedImageUrl != null && savedImageUrl.isNotEmpty);

    Color badgeBg;
    Color badgeText;
    String badgeLabel;

    if (isValidating) {
      badgeBg = const Color(0xFFEFF6FF);
      badgeText = const Color(0xFF1D4ED8);
      badgeLabel = 'Đang kiểm tra...';
    } else if (isValid) {
      badgeBg = const Color(0xFFD1FAE5);
      badgeText = AppColors.primary;
      badgeLabel = 'Đã xác nhận ✓';
    } else if (status == CccdSideValidationStatus.invalid) {
      badgeBg = const Color(0xFFFEE2E2);
      badgeText = Colors.red.shade700;
      badgeLabel = 'Chưa đạt';
    } else if (isFromCloud) {
      badgeBg = const Color(0xFFF1F5F9);
      badgeText = const Color(0xFF475569);
      badgeLabel = 'Ảnh lịch sử';
    } else {
      badgeBg = const Color(0xFFFEE2E2);
      badgeText = Colors.red.shade700;
      badgeLabel = 'Bắt buộc';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isValid
              ? const Color(0xFF86EFAC)
              : (status == CccdSideValidationStatus.invalid ? const Color(0xFFFCA5A5) : Colors.grey.shade300),
          width: (isValid || status == CccdSideValidationStatus.invalid) ? 1.5 : 1,
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
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: badgeText,
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
            _buildImagePreview(
              localImage: image,
              savedUrl: savedImageUrl,
              isFront: isFront,
              isValidating: isValidating,
            )
          else
            _buildEmptyImagePlaceholder(isFront, isValidating: isValidating),

          // Trạng thái thẩm định On-Device cho từng mặt
          _buildSideStatusBanner(isFront),
        ],
      ),
    );
  }

  /// Widget thông báo trạng thái kiểm tra từng mặt
  Widget _buildSideStatusBanner(bool isFront) {
    final status = isFront ? _frontStatus : _backStatus;
    final error = isFront ? _frontError : _backError;
    final sideName = isFront ? 'mặt trước' : 'mặt sau';

    switch (status) {
      case CccdSideValidationStatus.validating:
        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1D4ED8)),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đang kiểm tra ảnh CCCD...',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      case CccdSideValidationStatus.valid:
        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đã xác nhận đúng $sideName',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      case CccdSideValidationStatus.invalid:
        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, size: 16, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  error ?? 'Ảnh không hợp lệ. Vui lòng chọn lại.',
                  style: const TextStyle(fontSize: 11.5, color: Colors.red, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        );
      case CccdSideValidationStatus.idle:
        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 15, color: AppColors.textMuted),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cần chọn ảnh mới để xác nhận',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        );
    }
  }

  /// Placeholder khi chưa có ảnh
  Widget _buildEmptyImagePlaceholder(bool isFront, {required bool isValidating}) {
    return InkWell(
      onTap: isValidating ? null : () => _showImagePickerModal(isFront),
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
                'Camera hoặc Thư viện ảnh',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Preview khi đã có ảnh
  Widget _buildImagePreview({
    required XFile? localImage,
    required String? savedUrl,
    required bool isFront,
    required bool isValidating,
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
                    color: const Color(0xFF475569).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Ảnh lịch sử (Cloud)',
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
              onPressed: isValidating ? null : () => _showImagePickerModal(isFront),
              icon: const Icon(Icons.refresh, size: 16, color: AppColors.primary),
              label: Text(
                isFromCloud ? 'Chụp / Tải ảnh thay thế' : 'Chụp lại / Đổi ảnh',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton.icon(
              onPressed: isValidating ? null : () => _clearSide(isFront),
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
              label: const Text('Xóa', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ],
    );
  }

  /// Thẻ hiển thị dữ liệu QR CCCD trích xuất từ mặt trước
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
                  'Mục 3: Thông tin định danh từ QR CCCD',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasQr ? const Color(0xFFD1FAE5) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  hasQr ? 'Đã trích xuất ✓' : 'Tự động',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: hasQr ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Hệ thống tự động trích xuất mã QR bảo mật từ ảnh mặt trước CCCD.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),

          if (hasQr)
            _buildQrDataPreview(_cccdData!)
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.qr_code_2, size: 28, color: AppColors.textMuted),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Vui lòng chụp ảnh mặt trước CCCD rõ nét mã QR để tự động trích xuất thông tin đối soát.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.3),
                    ),
                  ),
                ],
              ),
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
                  'THÔNG TIN XÁC THỰC TỪ MÃ QR THẺ THẬT',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green.shade900),
                ),
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

  /// Thanh hành động dưới cùng
  Widget _buildBottomActionBar() {
    final bool isValidatingAny =
        _frontStatus == CccdSideValidationStatus.validating || _backStatus == CccdSideValidationStatus.validating;

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
                        isValidatingAny
                            ? 'Đang kiểm tra tính hợp lệ của ảnh CCCD. Vui lòng chờ...'
                            : 'Thiếu: ${_missingItems.join(', ')}. Cần đủ bằng chứng hợp lệ để mở nút xác thực.',
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
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: AppColors.primary),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Bằng chứng 2 mặt CCCD đã được thẩm định hợp lệ! Bạn có thể lưu lên Firebase Cloud.',
                        style: TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

            // Nút xác thực: Bị disabled nếu !_isComplete hoặc đang validating / submitting
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isComplete ? AppColors.primary : Colors.grey.shade300,
                foregroundColor: _isComplete ? Colors.white : Colors.grey.shade500,
                elevation: _isComplete ? 2 : 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isComplete ? _submitVerification : null,
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
                              : 'LƯU & ĐỒNG BỘ LÊN FIREBASE CLOUD',
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
