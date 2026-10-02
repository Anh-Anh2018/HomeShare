import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../home/screens/home_screen.dart';
import 'host_dashboard_screen.dart';

class HostMainScreen extends StatefulWidget {
  const HostMainScreen({super.key});

  @override
  State<HostMainScreen> createState() => _HostMainScreenState();
}

class _HostMainScreenState extends State<HostMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HostDashboardScreen(),
    _PlaceholderScreen(title: 'Tin nhắn với người thuê', icon: Icons.chat_bubble_outline),
    HostDashboardScreen(), // Nút tròn giữa kích hoạt BottomSheet tạo mới
    _PlaceholderScreen(title: 'Quản lý phòng & Hợp đồng', icon: Icons.assignment_outlined),
    HomeScreen(), // Trang cá nhân & Đăng xuất
  ];

  void _showCreateBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tạo Mới & Đăng Tin',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.apartment, color: AppColors.primary),
              ),
              title: const Text('Tạo Cơ Sở / Nhà Mới', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Thêm tòa nhà, chung cư mini, dãy nhà trọ'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(ctx),
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.infoContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bedroom_parent_outlined, color: AppColors.info),
              ),
              title: const Text('Thêm Phòng Trọ / Căn Hộ', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Đăng tải phòng mới kèm giá, hình ảnh, diện tích'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        onTap: (index) {
          if (index == 2) {
            _showCreateBottomSheet();
          } else {
            setState(() => _currentIndex = index);
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Tổng quan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Tin nhắn',
          ),
          BottomNavigationBarItem(
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.add, color: Colors.white, size: 18),
            ),
            label: 'Tạo mới',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Quản lý',
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

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;

  const _PlaceholderScreen({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
          ],
        ),
      ),
    );
  }
}
