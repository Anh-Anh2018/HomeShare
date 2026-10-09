import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/image_storage_service.dart';
import '../../profile/models/cccd_validation_models.dart';
import '../../profile/services/cccd_image_evidence_validator.dart';
import '../services/role_resolver.dart';
import 'auth_provider.dart';

/// Model thông tin người dùng HomeShare chuẩn hóa theo Database homeShare (DrawIO pkg_0: Tài khoản)
/// Bảng: Người dùng, Sở thích (soDienThoai, email, hoTen, anhDaiDien, gioiTinh, ngaySinh, diaChi, diemUyTin, ngheNghiep)
class UserProfile {
  final String uid; // id
  final String?
  _userCode; // maNguoiDung 5 ký tự (3 số đầu + 2 chữ sau, vd: 382AN)
  final String email; // email
  final String displayName; // hoTen
  final String phoneNumber; // soDienThoai
  final String role; // vaiTro ('renter' / 'nguoiDung')
  final String avatarUrl; // anhDaiDien
  final String gender; // gioiTinh: nam | nu | khac
  final String address; // diaChi
  final String hometown; // queQuan
  final int reputationScore; // diemUyTin
  final String occupation; // ngheNghiep
  final List<String> hobbies; // soThich
  final DateTime? birthDate; // ngaySinh
  final DateTime? createdAt; // ngayTao
  final bool isCccdVerified; // daXacThucCccd / trangThaiXacMinh_id
  final String cccdNumber; // soGiayTo / soCccd
  final String cccdFullName; // hoTenCccd
  final String cccdIssueDate; // ngayCap
  final String cccdHometown; // queQuanCccd
  final DateTime? cccdVerifiedAt; // ngayXacMinh
  final String cccdFrontImageUrl; // anhMatTruoc / anhGiayTo_id
  final String cccdBackImageUrl; // anhMatSau

  // Vietnamese DrawIO Alias Getters
  String get id => uid;
  String get userCode => (_userCode != null && isValidUserCode(_userCode))
      ? _userCode
      : generateUserCode(seed: uid);
  String get maNguoiDung => userCode;
  String get idNguoiDung => userCode;
  String get maDinhDanh => userCode;
  String get hoTen => displayName;
  String get soDienThoai => phoneNumber;
  String get anhDaiDien => avatarUrl;
  String get gioiTinh => gender;
  String get diaChi => address;
  String get queQuan => hometown;
  int get diemUyTin => reputationScore;
  String get ngheNghiep => occupation;
  List<String> get soThich => hobbies;
  String get vaiTro => role;
  bool get isRenter => role == 'renter';
  bool get isHost => role == 'host';
  bool get isAdmin => role == 'admin';
  bool get hasValidRole => RoleResolver.isValidRole(role);
  DateTime? get ngaySinh => birthDate;
  DateTime? get ngayTao => createdAt;
  bool get daXacThucCccd => isCccdVerified;
  String get soCccd => cccdNumber;
  String get soGiayTo => cccdNumber;
  String get hoTenCccd => cccdFullName;
  String get anhMatTruoc => cccdFrontImageUrl;
  String get anhMatSau => cccdBackImageUrl;

  /// Kiểm tra mã người dùng có đúng chuẩn 5 ký tự (3 số đầu + 2 chữ sau) hay không
  static bool isValidUserCode(String code) {
    return RegExp(r'^\d{3}[A-Z]{2}$').hasMatch(code.trim().toUpperCase());
  }

  /// Sinh mã người dùng chuẩn 5 ký tự gồm 3 số đầu và 2 chữ cái sau (vd: 382AN, 825TO)
  /// - Nếu truyền seed (UID), thuật toán băm tất định (deterministic) đảm bảo mã luôn cố định
  /// - Nếu không có seed, sinh ngẫu nhiên chuẩn 3 số (100-999) + 2 chữ in hoa (A-Z)
  static String generateUserCode({String? seed}) {
    if (seed != null && seed.isNotEmpty) {
      var hash = 0;
      for (var i = 0; i < seed.length; i++) {
        hash = (hash * 31 + seed.codeUnitAt(i)) & 0x7FFFFFFF;
      }
      final digits = (100 + (hash % 900)).toString();
      const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
      final char1 = letters[(hash ~/ 900) % 26];
      final char2 = letters[(hash ~/ 23400) % 26];
      return '$digits$char1$char2';
    } else {
      final rand = Random();
      final digits = (100 + rand.nextInt(900)).toString();
      const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
      final char1 = letters[rand.nextInt(letters.length)];
      final char2 = letters[rand.nextInt(letters.length)];
      return '$digits$char1$char2';
    }
  }

  UserProfile({
    required this.uid,
    String? userCode,
    required this.email,
    required this.displayName,
    required this.phoneNumber,
    this.role = '',
    this.avatarUrl = '',
    this.gender = 'Nam',
    this.address = '',
    this.hometown = '',
    this.reputationScore = 100,
    this.occupation = 'Sinh viên',
    this.hobbies = const [],
    this.birthDate,
    this.createdAt,
    this.isCccdVerified = false,
    this.cccdNumber = '',
    this.cccdFullName = '',
    this.cccdIssueDate = '',
    this.cccdHometown = '',
    this.cccdVerifiedAt,
    this.cccdFrontImageUrl = '',
    this.cccdBackImageUrl = '',
  }) : _userCode = (userCode != null && isValidUserCode(userCode))
           ? userCode.trim().toUpperCase()
           : generateUserCode(seed: uid);

  factory UserProfile.fromMap(Map<String, dynamic> data, String uid) {
    final rawHobbies = (data['hobbies'] ?? data['soThich']) as List<dynamic>?;
    final parsedHobbies =
        rawHobbies
            ?.map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];

    final rawUserCode =
        (data['userCode'] ?? data['maNguoiDung'] ?? data['idNguoiDung'])
            ?.toString();
    final userCode = (rawUserCode != null && isValidUserCode(rawUserCode))
        ? rawUserCode.trim().toUpperCase()
        : generateUserCode(seed: uid);

    final parsedRole = RoleResolver.extractRoleFromMap(data) ?? '';

    return UserProfile(
      uid: uid,
      userCode: userCode,
      email: data['email'] ?? '',
      displayName:
          data['displayName'] ?? data['hoTen'] ?? 'Người dùng HomeShare',
      phoneNumber: data['phoneNumber'] ?? data['soDienThoai'] ?? '',
      role: parsedRole,
      avatarUrl: data['avatarUrl'] ?? data['anhDaiDien'] ?? '',
      gender: data['gender'] ?? data['gioiTinh'] ?? 'Nam',
      address: data['address'] ?? data['diaChi'] ?? '',
      hometown: data['hometown'] ?? data['queQuan'] ?? '',
      reputationScore:
          ((data['reputationScore'] ?? data['diemUyTin']) as num?)?.toInt() ??
          100,
      occupation: data['occupation'] ?? data['ngheNghiep'] ?? 'Sinh viên',
      hobbies: parsedHobbies,
      birthDate: (data['birthDate'] is Timestamp)
          ? (data['birthDate'] as Timestamp).toDate()
          : (data['ngaySinh'] is Timestamp)
          ? (data['ngaySinh'] as Timestamp).toDate()
          : null,
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['ngayTao'] is Timestamp)
          ? (data['ngayTao'] as Timestamp).toDate()
          : null,
      isCccdVerified:
          (data['isCccdVerified'] ??
              data['daXacThucCccd'] ??
              (data['trangThaiXacMinh_id'] == 'daXacThuc')) ??
          false,
      cccdNumber:
          (data['cccdNumber'] ?? data['soGiayTo'] ?? data['soCccd'] ?? '')
              .toString(),
      cccdFullName: (data['cccdFullName'] ?? data['hoTenCccd'] ?? '')
          .toString(),
      cccdIssueDate: (data['cccdIssueDate'] ?? data['ngayCap'] ?? '')
          .toString(),
      cccdHometown:
          (data['cccdHometown'] ??
                  data['queQuan'] ??
                  data['diaChiThuongTru'] ??
                  data['cccdAddress'] ??
                  '')
              .toString(),
      cccdVerifiedAt: (data['cccdVerifiedAt'] is Timestamp)
          ? (data['cccdVerifiedAt'] as Timestamp).toDate()
          : (data['ngayXacMinh'] is Timestamp)
          ? (data['ngayXacMinh'] as Timestamp).toDate()
          : null,
      cccdFrontImageUrl:
          (data['cccdFrontImageUrl'] ??
                  data['anhMatTruoc'] ??
                  data['anhGiayTo_id'] ??
                  '')
              .toString(),
      cccdBackImageUrl: (data['cccdBackImageUrl'] ?? data['anhMatSau'] ?? '')
          .toString(),
    );
  }

  Map<String, dynamic> toMap() {
    final normalizedRole = RoleResolver.normalizeRole(role);
    final int? vaiTroId = normalizedRole == RoleResolver.renter
        ? 1
        : normalizedRole == RoleResolver.host
        ? 2
        : normalizedRole == RoleResolver.admin
        ? 3
        : null;

    return {
      'uid': uid,
      'userCode': userCode,
      'maNguoiDung': userCode,
      'idNguoiDung': userCode,
      'email': email,
      'displayName': displayName,
      'hoTen': displayName,
      'phoneNumber': phoneNumber,
      'soDienThoai': phoneNumber,
      'role': role,
      'vaiTro': role,
      'vaiTro_id': ?vaiTroId,
      'avatarUrl': avatarUrl,
      'anhDaiDien': avatarUrl,
      'gender': gender,
      'gioiTinh': gender,
      'address': address,
      'diaChi': address,
      'hometown': hometown,
      'queQuan': hometown,
      'reputationScore': reputationScore,
      'diemUyTin': reputationScore,
      'occupation': occupation,
      'ngheNghiep': occupation,
      'hobbies': hobbies,
      'soThich': hobbies,
      'isCccdVerified': isCccdVerified,
      'daXacThucCccd': isCccdVerified,
      'trangThaiXacMinh_id': isCccdVerified ? 'daXacThuc' : 'chuaXacThuc',
      'cccdNumber': cccdNumber,
      'soGiayTo': cccdNumber,
      'soCccd': cccdNumber,
      'cccdFullName': cccdFullName,
      'hoTenCccd': cccdFullName,
      'cccdIssueDate': cccdIssueDate,
      'ngayCap': cccdIssueDate,
      'cccdHometown': cccdHometown,
      'cccdFrontImageUrl': cccdFrontImageUrl,
      'anhMatTruoc': cccdFrontImageUrl,
      'cccdBackImageUrl': cccdBackImageUrl,
      'anhMatSau': cccdBackImageUrl,
      if (birthDate != null) 'birthDate': Timestamp.fromDate(birthDate!),
      if (birthDate != null) 'ngaySinh': Timestamp.fromDate(birthDate!),
      if (cccdVerifiedAt != null)
        'cccdVerifiedAt': Timestamp.fromDate(cccdVerifiedAt!),
      if (cccdVerifiedAt != null)
        'ngayXacMinh': Timestamp.fromDate(cccdVerifiedAt!),
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'ngayTao': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  UserProfile copyWith({
    String? uid,
    String? userCode,
    String? email,
    String? displayName,
    String? phoneNumber,
    String? role,
    String? avatarUrl,
    String? gender,
    String? address,
    String? hometown,
    int? reputationScore,
    String? occupation,
    List<String>? hobbies,
    DateTime? birthDate,
    DateTime? createdAt,
    bool? isCccdVerified,
    String? cccdNumber,
    String? cccdFullName,
    String? cccdIssueDate,
    String? cccdHometown,
    DateTime? cccdVerifiedAt,
    String? cccdFrontImageUrl,
    String? cccdBackImageUrl,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      userCode: userCode ?? this.userCode,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      gender: gender ?? this.gender,
      address: address ?? this.address,
      hometown: hometown ?? this.hometown,
      reputationScore: reputationScore ?? this.reputationScore,
      occupation: occupation ?? this.occupation,
      hobbies: hobbies ?? this.hobbies,
      birthDate: birthDate ?? this.birthDate,
      createdAt: createdAt ?? this.createdAt,
      isCccdVerified: isCccdVerified ?? this.isCccdVerified,
      cccdNumber: cccdNumber ?? this.cccdNumber,
      cccdFullName: cccdFullName ?? this.cccdFullName,
      cccdIssueDate: cccdIssueDate ?? this.cccdIssueDate,
      cccdHometown: cccdHometown ?? this.cccdHometown,
      cccdVerifiedAt: cccdVerifiedAt ?? this.cccdVerifiedAt,
      cccdFrontImageUrl: cccdFrontImageUrl ?? this.cccdFrontImageUrl,
      cccdBackImageUrl: cccdBackImageUrl ?? this.cccdBackImageUrl,
    );
  }
}

/// Hàm lưu kết quả xác thực CCCD eKYC vào Firestore và SharedPreferences
/// Bắt buộc kiểm tra CccdValidationProof hợp lệ thông qua Save Boundary trước khi thực hiện side-effects
Future<void> saveCccdVerificationToBackend({
  required String uid,
  required CccdValidationProof proof,
  CccdImageEvidenceValidator validator = const CccdImageEvidenceValidator(),
  ImageStorageService? imageStorageService,
  FirebaseFirestore? firestoreInstance,
  SharedPreferences? preferencesInstance,
}) async {
  // SAVE BOUNDARY: Tái thẩm định toàn diện bằng chứng trước khi lưu (Fail-closed)
  if (!validator.canSave(proof)) {
    throw const CccdValidationException(
      'Bằng chứng xác thực ảnh CCCD không hợp lệ hoặc không đủ điều kiện lưu trữ.',
    );
  }

  final verifiedData = proof.verifiedData!;
  final cccdNumber = verifiedData.idNumber;
  final cccdFullName = verifiedData.fullName;
  final cccdIssueDate = verifiedData.issueDate;
  final cccdHometown = verifiedData.address;
  final gender = verifiedData.gender;

  DateTime? parsedBirth;
  try {
    final parts = verifiedData.birthDate.split('/');
    if (parts.length == 3) {
      parsedBirth = DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
    }
  } catch (_) {}

  final firestore = firestoreInstance ?? FirebaseFirestore.instance;
  final imageStorage = imageStorageService ?? ImageStorageService();

  final frontPath = proof.frontEvidence!.filePath ?? '';
  final backPath = proof.backEvidence!.filePath ?? '';

  // Chỉ upload đúng local paths từ proof/evidence đã validate thành công
  final uploadedFrontUrl = await imageStorage.uploadCccdImage(
    filePath: frontPath,
    uid: uid,
    isFront: true,
  );

  final uploadedBackUrl = await imageStorage.uploadCccdImage(
    filePath: backPath,
    uid: uid,
    isFront: false,
  );

  final updateData = <String, dynamic>{
    'isCccdVerified': true,
    'daXacThucCccd': true,
    'trangThaiXacMinh_id': 'daXacThuc',
    'cccdNumber': cccdNumber,
    'soGiayTo': cccdNumber,
    'soCccd': cccdNumber,
    'cccdFullName': cccdFullName,
    'hoTenCccd': cccdFullName,
    'displayName': cccdFullName,
    'hoTen': cccdFullName,
    'cccdIssueDate': cccdIssueDate,
    'ngayCap': cccdIssueDate,
    'cccdHometown': cccdHometown,
    'queQuan': cccdHometown,
    'gender': gender,
    'gioiTinh': gender,
    if (parsedBirth != null) 'birthDate': Timestamp.fromDate(parsedBirth),
    if (parsedBirth != null) 'ngaySinh': Timestamp.fromDate(parsedBirth),
    if (uploadedFrontUrl.isNotEmpty) ...{
      'cccdFrontImageUrl': uploadedFrontUrl,
      'anhMatTruoc': uploadedFrontUrl,
    },
    if (uploadedBackUrl.isNotEmpty) ...{
      'cccdBackImageUrl': uploadedBackUrl,
      'anhMatSau': uploadedBackUrl,
    },
    'cccdVerifiedAt': FieldValue.serverTimestamp(),
    'ngayXacMinh': FieldValue.serverTimestamp(),
    'cccdValidationVersion': proof.version,
    'cccdFrontValidated': true,
    'cccdBackValidated': true,
    'isProfileSyncedWithCccd': true,
    'lastSyncedAt': FieldValue.serverTimestamp(),
  };

  try {
    // 1. Cập nhật hồ sơ người dùng trong Firestore
    await firestore
        .collection('users')
        .doc(uid)
        .set(updateData, SetOptions(merge: true));

    // 2. Ghi nhận vào bảng Xác minh danh tính chuẩn Database DrawIO (pkg_0: Tài khoản)
    await firestore.collection('xac_minh_danh_tinh').doc(uid).set({
      'id': uid,
      'nguoiDung_Id': uid,
      'loaiGiayTo_id': 'cccd',
      'soGiayTo': cccdNumber,
      'soCccd': cccdNumber,
      'hoTen': cccdFullName,
      'anhMatTruoc': uploadedFrontUrl,
      'anhMatSau': uploadedBackUrl,
      'trangThai_Id': 'daXacThuc',
      'ngayXacMinh': FieldValue.serverTimestamp(),
      'ngayCap': cccdIssueDate,
      'queQuan': cccdHometown,
      'gioiTinh': gender,
      'cccdValidationVersion': proof.version,
      'cccdFrontValidated': true,
      'cccdBackValidated': true,
      if (parsedBirth != null) 'ngaySinh': Timestamp.fromDate(parsedBirth),
    }, SetOptions(merge: true));
  } catch (e) {
    debugPrint('[saveCccdVerificationToBackend] Lỗi ghi dữ liệu Firestore.');
    throw const CccdValidationException('Không thể lưu thông tin xác thực CCCD lên cơ sở dữ liệu.');
  }

  // 3. Lưu vào SharedPreferences để hỗ trợ truy xuất tức thì ngay cả khi offline
  try {
    final prefs = preferencesInstance ?? await SharedPreferences.getInstance();
    await prefs.setBool('cccd_verified_$uid', true);
    await prefs.setString('cccd_number_$uid', cccdNumber);
    await prefs.setString('cccd_name_$uid', cccdFullName);
    await prefs.setString('cccd_issue_date_$uid', cccdIssueDate);
    await prefs.setString('cccd_hometown_$uid', cccdHometown);
    await prefs.setString('cccd_gender_$uid', gender);
    await prefs.setString('cccd_validation_version_$uid', proof.version);
    await prefs.setBool('cccd_front_validated_$uid', true);
    await prefs.setBool('cccd_back_validated_$uid', true);
    if (parsedBirth != null) {
      await prefs.setString('cccd_birth_$uid', parsedBirth.toIso8601String());
    }
    if (uploadedFrontUrl.isNotEmpty) {
      await prefs.setString('cccd_front_$uid', uploadedFrontUrl);
    }
    if (uploadedBackUrl.isNotEmpty) {
      await prefs.setString('cccd_back_$uid', uploadedBackUrl);
    }
  } catch (_) {}
}

/// Lấy thông tin xác thực CCCD trực tiếp từ Cloud Firestore
Future<Map<String, dynamic>?> fetchCccdDataFromFirestore({
  required String uid,
}) async {
  try {
    final firestore = FirebaseFirestore.instance;
    final doc = await firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      final cccdNum =
          (data['cccdNumber'] ?? data['soGiayTo'] ?? data['soCccd'] ?? '')
              .toString();
      if (cccdNum.isNotEmpty) {
        return data;
      }
    }

    // Kiểm tra bảng xac_minh_danh_tinh
    final verifyDoc = await firestore
        .collection('xac_minh_danh_tinh')
        .doc(uid)
        .get();
    if (verifyDoc.exists && verifyDoc.data() != null) {
      return verifyDoc.data();
    }
    return null;
  } catch (e) {
    debugPrint('[fetchCccdDataFromFirestore] Lỗi đọc CCCD từ Firestore: $e');
    return null;
  }
}

/// Đồng bộ thông tin từ thẻ CCCD đã quét sang các trường thông tin cơ bản của hồ sơ tài khoản
Future<bool> syncCccdToUserProfile({required String uid}) async {
  try {
    final firestore = FirebaseFirestore.instance;
    final doc = await firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return false;
    final data = doc.data()!;

    final cccdName =
        (data['cccdFullName'] ?? data['hoTenCccd'] ?? data['hoTen'] ?? '')
            .toString()
            .trim();
    final cccdGender = (data['gender'] ?? data['gioiTinh'] ?? '')
        .toString()
        .trim();
    final cccdAddress =
        (data['cccdHometown'] ?? data['queQuan'] ?? data['cccdAddress'] ?? '')
            .toString()
            .trim();
    final cccdBirth = data['birthDate'] ?? data['ngaySinh'];

    final syncData = <String, dynamic>{
      if (cccdName.isNotEmpty) ...{'displayName': cccdName, 'hoTen': cccdName},
      if (cccdGender.isNotEmpty) ...{
        'gender': cccdGender,
        'gioiTinh': cccdGender,
      },
      if (cccdAddress.isNotEmpty) ...{
        'hometown': cccdAddress,
        'queQuan': cccdAddress,
      },
      if (cccdBirth != null) ...{'birthDate': cccdBirth, 'ngaySinh': cccdBirth},
      'isProfileSyncedWithCccd': true,
      'lastSyncedAt': FieldValue.serverTimestamp(),
    };

    if (syncData.isNotEmpty) {
      await firestore
          .collection('users')
          .doc(uid)
          .set(syncData, SetOptions(merge: true));
      return true;
    }
    return false;
  } catch (e) {
    debugPrint('[syncCccdToUserProfile] Lỗi đồng bộ: $e');
    return false;
  }
}

// StreamProvider lấy thông tin chi tiết user từ Cloud Firestore
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          final code = UserProfile.generateUserCode(seed: user.uid);
          return UserProfile(
            uid: user.uid,
            userCode: code,
            email: user.email ?? '',
            displayName: user.displayName ?? 'Người dùng HomeShare',
            phoneNumber: '',
            role: '',
          );
        }
        final data = snapshot.data()!;
        // Đảm bảo mã người dùng 5 ký tự luôn được lưu trong Firestore để Admin tìm kiếm
        if (data['userCode'] == null || data['maNguoiDung'] == null) {
          final code = UserProfile.generateUserCode(seed: user.uid);
          FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'userCode': code,
            'maNguoiDung': code,
            'idNguoiDung': code,
          }, SetOptions(merge: true));
        }
        return UserProfile.fromMap(data, user.uid);
      });
});

// Notifier quản lý Role hoạt động
class ActiveRoleNotifier extends Notifier<String> {
  @override
  String build() {
    return 'renter';
  }

  void switchRole(String role) {
    final normalized = RoleResolver.normalizeRole(role);
    if (normalized != null) {
      state = normalized;
    }
  }
}

final activeRoleProvider = NotifierProvider<ActiveRoleNotifier, String>(
  ActiveRoleNotifier.new,
);
