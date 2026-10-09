import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/screens/admin_dashboard_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/providers/user_provider.dart';
import 'features/auth/screens/invalid_role_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/services/role_resolver.dart';
import 'features/host/screens/host_main_screen.dart';
import 'features/renter/screens/renter_main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HomeShare',
      debugShowCheckedModeBanner: false,
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
        if (user == null) {
          return const LoginScreen();
        }

        // Đã xác thực Firebase Auth -> Lắng nghe hồ sơ người dùng từ Firestore
        final profileAsync = ref.watch(userProfileProvider);

        return profileAsync.when(
          data: (profile) {
            final destination = resolveAuthDestination(
              isAuthenticated: true,
              isProfileLoading: false,
              role: profile?.role,
            );

            switch (destination) {
              case AuthDestination.renter:
                return const RenterMainScreen();
              case AuthDestination.host:
                return const HostMainScreen();
              case AuthDestination.admin:
                return const AdminDashboardScreen();
              case AuthDestination.invalidRole:
              default:
                // Fail-closed: Role không hợp lệ hoặc thiếu -> Màn hình cảnh báo + Đăng xuất
                return InvalidRoleScreen(role: profile?.role);
            }
          },
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, stack) {
            debugPrint('UserProfile load error');
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Không thể tải thông tin tài khoản. Vui lòng thử lại sau.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () =>
                            ref.read(authServiceProvider).signOut(),
                        child: const Text('Đăng xuất'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) {
        debugPrint('Auth state error');
        return const Scaffold(
          body: Center(
            child: Text('Không thể xác thực tài khoản. Vui lòng thử lại sau.'),
          ),
        );
      },
    );
  }
}
