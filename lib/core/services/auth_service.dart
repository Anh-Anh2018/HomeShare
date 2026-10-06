import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/auth/providers/user_provider.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream theo dõi trạng thái đăng nhập
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Lấy user hiện tại
  User? get currentUser => _auth.currentUser;

  // Đăng nhập bằng Email & Mật khẩu
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Đã có lỗi xảy ra: $e';
    }
  }

  // Đăng ký tài khoản mới bằng Email & Mật khẩu
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    String? phoneNumber,
    String role = 'renter', // 'renter' (người thuê) hoặc 'host' (chủ trọ)
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(displayName);

        // Sinh mã người dùng 5 ký tự (3 số đầu + 2 chữ sau)
        final userCode = UserProfile.generateUserCode(seed: user.uid);

        // Lưu thông tin người dùng vào Firestore collection 'users'
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'userCode': userCode,
          'maNguoiDung': userCode,
          'idNguoiDung': userCode,
          'email': email.trim(),
          'displayName': displayName.trim(),
          'hoTen': displayName.trim(),
          'phoneNumber': phoneNumber ?? '',
          'soDienThoai': phoneNumber ?? '',
          'role': role,
          'vaiTro': role,
          'vaiTro_id': role == 'host' ? 2 : 1,
          'diemUyTin': 100,
          'avatarUrl': '',
          'anhDaiDien': '',
          'createdAt': FieldValue.serverTimestamp(),
          'ngayTao': FieldValue.serverTimestamp(),
        });
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Đã có lỗi xảy ra: $e';
    }
  }

  // Đăng xuất. Xóa fcmToken trước để máy này không còn nhận chuông của tài khoản vừa thoát.
  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _firestore.collection('users').doc(uid).set({
        'fcmToken': FieldValue.delete(),
      }, SetOptions(merge: true));
    }
    await _auth.signOut();
  }

  // Xử lý thông báo lỗi tiếng Việt dễ hiểu
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Không tìm thấy tài khoản với email này.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Mật khẩu hoặc thông tin đăng nhập không chính xác.';
      case 'email-already-in-use':
        return 'Email này đã được sử dụng cho tài khoản khác.';
      case 'invalid-email':
        return 'Định dạng email không hợp lệ.';
      case 'weak-password':
        return 'Mật khẩu quá yếu (tối thiểu 6 ký tự).';
      case 'user-disabled':
        return 'Tài khoản này đã bị khóa.';
      default:
        return e.message ?? 'Lỗi xác thực: ${e.code}';
    }
  }
}
