import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/booking_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../profile/screens/account_settings_screen.dart';
import '../../profile/screens/cccd_verification_screen.dart';
import '../../renter/screens/renter_bookings_screen.dart';
import '../models/profile_overview.dart';
import '../widgets/personal_profile_content.dart';


class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
    } catch (e) {
      debugPrint('HomeScreen sign out error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể đăng xuất. Vui lòng thử lại sau.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text(
                'Trang cá nhân',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.white,
              elevation: 0,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.person_off_outlined,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Không tìm thấy thông tin hồ sơ tài khoản.',
                      style: TextStyle(fontSize: 15, color: AppColors.textDark),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => _handleSignOut(context, ref),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Đăng xuất'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Lấy thống kê đơn thuê thật của người dùng
        final currentUser = ref.watch(currentUserProvider);
        final bookingsAsync = currentUser != null
            ? ref.watch(renterBookingsStreamProvider(currentUser.uid))
            : null;

        final bookingsList = bookingsAsync?.asData?.value;
        final stats = ProfileOverviewHelper.calculateStats(bookingsList);
        final isBookingsLoading = bookingsAsync?.isLoading ?? false;
        final hasBookingsError = bookingsAsync?.hasError ?? false;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text(
              'Trang cá nhân',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Cài đặt tài khoản',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AccountSettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          body: SafeArea(
            child: PersonalProfileContent(
              profile: profile,
              stats: stats,
              isBookingsLoading: isBookingsLoading,
              hasBookingsError: hasBookingsError,
              onOpenAccountSettings: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AccountSettingsScreen(),
                  ),
                );
              },
              onOpenCccdVerification: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CccdVerificationScreen(),
                  ),
                );
              },
              onOpenBookings: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RenterBookingsScreen(),
                  ),
                );
              },
              onSignOut: () => _handleSignOut(context, ref),
            ),
          ),
        );
      },
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Trang cá nhân',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) {
        debugPrint('HomeScreen userProfileProvider load error');
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text(
              'Trang cá nhân',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppColors.danger,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Không thể tải thông tin hồ sơ. Vui lòng kiểm tra kết nối mạng và thử lại.',
                    style: TextStyle(fontSize: 15, color: AppColors.textDark),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _handleSignOut(context, ref),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Đăng xuất'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
