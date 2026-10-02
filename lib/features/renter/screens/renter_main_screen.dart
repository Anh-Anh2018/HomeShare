import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../home/screens/home_screen.dart';
import '../../chat/screens/chat_list_screen.dart';
import 'renter_dashboard_screen.dart';
import 'roommate_community_screen.dart';
import 'create_roommate_post_screen.dart';

class RenterBottomNavIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) => state = index;
}

final renterBottomNavIndexProvider = NotifierProvider<RenterBottomNavIndexNotifier, int>(RenterBottomNavIndexNotifier.new);

class RenterMainScreen extends ConsumerStatefulWidget {
  const RenterMainScreen({super.key});

  @override
  ConsumerState<RenterMainScreen> createState() => _RenterMainScreenState();
}

class _RenterMainScreenState extends ConsumerState<RenterMainScreen> {
  final List<Widget> _screens = const [
    RenterDashboardScreen(),
    ChatListScreen(),
    CreateRoommatePostScreen(),
    RoommateCommunityScreen(),
    HomeScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(renterBottomNavIndexProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        onTap: (index) {
          ref.read(renterBottomNavIndexProvider.notifier).setIndex(index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'Khám phá',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Tin nhắn',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'Đăng tin',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_outlined),
            activeIcon: Icon(Icons.group),
            label: 'Ở ghép',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Cá nhân',
          ),
        ],
      ),
    );
  }
}
