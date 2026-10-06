import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'core/services/call_push_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/renter/screens/renter_main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Tạo kênh chuông "Cuộc gọi" và đăng ký handler khi app ở nền hoặc đã tắt.
  await CallPushService.prepare();
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HomeShare',
      debugShowCheckedModeBanner: false,
      // Để thông báo cuộc gọi mở IncomingCallScreen dù người dùng đang ở trang nào.
      navigatorKey: navigatorKey,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          // Bọc màn hình chính để lưu fcmToken ngay sau khi đăng nhập.
          return _SignedInShell(uid: user.uid);
        }
        return const LoginScreen();
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Text('Lỗi xác thực: $error'),
        ),
      ),
    );
  }
}

/// Giữ RenterMainScreen và gắn mã thông báo của máy vào user đang đăng nhập.
/// Chờ frame đầu tiên để navigatorKey đã sẵn sàng trước khi mở cuộc gọi từ thông báo.
class _SignedInShell extends StatefulWidget {
  final String uid;

  const _SignedInShell({required this.uid});

  @override
  State<_SignedInShell> createState() => _SignedInShellState();
}

class _SignedInShellState extends State<_SignedInShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CallPushService.bindUser(widget.uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const RenterMainScreen();
  }
}
