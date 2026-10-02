import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/user_provider.dart';
import '../../profile/screens/account_settings_screen.dart';

class HostDashboardScreen extends ConsumerWidget {
  const HostDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryContainer,
              child: Text(
                (profile?.displayName.isNotEmpty ?? false)
                    ? profile!.displayName[0].toUpperCase()
                    : 'CB',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      profile?.displayName ?? 'Chú Ba Linh Trung',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Pro',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const Row(
                  children: [
                    Icon(Icons.star, size: 12, color: Colors.amber),
                    SizedBox(width: 2),
                    Text(
                      '4.9 • Đã xác minh CCCD',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Banner Tài chính "Tiền của tôi" chuẩn Figma
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF006948), Color(0xFF004D34)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Tiền của tôi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Sẵn sàng rút',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'SỐ DƯ KHẢ DỤNG',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '32.000.000 đ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(Icons.arrow_forward, color: Colors.white70, size: 20),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Thống kê phòng: 1 hàng 3 ô số liệu tinh tế chuẩn Figma
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                child: Row(
                  children: [
                    _buildStatCol('12', 'Tổng phòng', AppColors.textDark),
                    _buildDivider(),
                    _buildStatCol('10', 'Đang ở', AppColors.primary),
                    _buildDivider(),
                    _buildStatCol('02', 'Còn trống', AppColors.warning),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 3. Tác vụ nhanh & Lối tắt
            const Text(
              'LỐI TẮT QUẢN LÝ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textMuted,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                _buildActionBtn(Icons.add_home_outlined, 'Tạo Nhà/Phòng', Colors.teal),
                _buildActionBtn(Icons.people_outline, 'Người thuê', Colors.blue),
                _buildActionBtn(Icons.handshake_outlined, 'Hợp đồng', Colors.purple),
                _buildActionBtn(Icons.receipt_long_outlined, 'Hóa đơn', Colors.orange),
                _buildActionBtn(Icons.electric_bolt_outlined, 'Điện nước', Colors.amber.shade800),
                _buildActionBtn(Icons.rule_outlined, 'Vi phạm/Phạt', Colors.red),
                _buildActionBtn(Icons.qr_code_scanner_outlined, 'QR nhận khách', Colors.indigo),
                _buildActionBtn(Icons.bar_chart_outlined, 'Báo cáo', Colors.green),
              ],
            ),
            const SizedBox(height: 20),

            // 4. Danh sách phòng tiêu biểu (Cơ sở Đặng Văn Bi)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'CƠ SỞ: ĐẶNG VĂN BI (12 PHÒNG)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('Xem tất cả', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                ),
              ],
            ),
            _buildRoomCard(
              roomNumber: 'Phòng 101',
              type: 'Studio Ban công',
              status: 'Đang ở • Nguyễn Văn Nam',
              price: '3.500.000 đ/tháng',
              isOccupied: true,
            ),
            const SizedBox(height: 10),
            _buildRoomCard(
              roomNumber: 'Phòng 204',
              type: 'Gác lửng thoáng mát',
              status: 'Cần bàn giao & Chốt điện nước',
              price: '3.800.000 đ/tháng',
              isOccupied: false,
              highlight: true,
            ),
            const SizedBox(height: 10),
            _buildRoomCard(
              roomNumber: 'Phòng 302',
              type: 'Phòng đơn cửa sổ lớn',
              status: 'Còn trống • Sẵn sàng nhận khách',
              price: '3.000.000 đ/tháng',
              isOccupied: false,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCol(String number, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            number,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      color: const Color(0xFFE5E7EB),
    );
  }

  Widget _buildActionBtn(IconData icon, String label, Color color) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF0F2F5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomCard({
    required String roomNumber,
    required String type,
    required String status,
    required String price,
    required bool isOccupied,
    bool highlight = false,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: highlight ? AppColors.warning : const Color(0xFFF0F2F5),
          width: highlight ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isOccupied
                    ? AppColors.primaryContainer
                    : (highlight ? AppColors.warningContainer : const Color(0xFFF3F4F6)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.door_front_door_outlined,
                color: isOccupied
                    ? AppColors.primary
                    : (highlight ? AppColors.warning : AppColors.textMuted),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        roomNumber,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        price,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    type,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isOccupied
                          ? AppColors.textSecondary
                          : (highlight ? AppColors.warning : AppColors.primary),
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
