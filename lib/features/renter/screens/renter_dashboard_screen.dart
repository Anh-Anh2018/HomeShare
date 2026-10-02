import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/room_model.dart';
import '../../../data/models/roommate_post_model.dart';
import '../../../core/services/room_service.dart';
import '../../../core/services/roommate_service.dart';
import '../../auth/providers/user_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'room_detail_screen.dart';
import 'search_filter_screen.dart';
import 'roommate_community_screen.dart';
import '../../chat/screens/chat_detail_screen.dart';

class RenterDashboardScreen extends ConsumerStatefulWidget {
  const RenterDashboardScreen({super.key});

  @override
  ConsumerState<RenterDashboardScreen> createState() => _RenterDashboardScreenState();
}

class _RenterDashboardScreenState extends ConsumerState<RenterDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Tự động nạp dữ liệu mẫu vào Cloud Firestore nếu database trống
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(roomServiceProvider).seedInitialRoomsIfEmpty();
      ref.read(roommateServiceProvider).deleteSampleRoommatePosts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final currencyFormatter = NumberFormat('#,###', 'vi_VN');

    final roomsAsync = ref.watch(roomsStreamProvider(const RoomFilterParams()));
    final roommatePostsAsync = ref.watch(roommatePostsStreamProvider(const RoommateFilterParams()));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.home_work_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Home',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Share',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const Text(
                  'Tìm phòng & Ở ghép thông minh',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Badge(
              smallSize: 8,
              backgroundColor: AppColors.danger,
              child: Icon(Icons.notifications_none_outlined),
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(roomsStreamProvider);
          ref.invalidate(roommatePostsStreamProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Greeting row
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  'Xin chào, ${profile?.displayName.isNotEmpty == true ? profile!.displayName : "bạn"} 👋',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),

              // 1. Search Bar with Filter Button
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SearchFilterScreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.search, color: AppColors.textMuted, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Tìm phòng, căn hộ, bạn ở ghép...',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SearchFilterScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.tune, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Banner Tìm ở ghép thông minh
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RoommateCommunityScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF006948), Color(0xFF00855D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'TÍNH NĂNG Ở GHÉP',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tìm bạn cùng phòng uy tín & hợp tính',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tiết kiệm 50% chi phí sinh hoạt. Đã xác thực CCCD.',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.group_add, color: Colors.white, size: 28),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 3. Danh mục tìm kiếm nhanh
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCategoryItem(Icons.home_work_outlined, 'Phòng trọ', AppColors.primary, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchFilterScreen(initialCategory: 'Phòng trọ')));
                  }),
                  _buildCategoryItem(Icons.apartment_outlined, 'Căn hộ mini', Colors.blue, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchFilterScreen(initialCategory: 'Căn hộ mini')));
                  }),
                  _buildCategoryItem(Icons.groups_outlined, 'Tìm ở ghép', Colors.purple, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RoommateCommunityScreen()));
                  }),
                  _buildCategoryItem(Icons.school_outlined, 'Gần trường ĐH', Colors.orange, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchFilterScreen()));
                  }),
                ],
              ),
              const SizedBox(height: 24),

              // 4. Phòng trọ gợi ý hôm nay (Realtime Firestore)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'GỢI Ý DÀNH CHO BẠN',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted,
                      letterSpacing: 0.8,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchFilterScreen()));
                    },
                    child: const Text('Xem thêm', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                  ),
                ],
              ),
              roomsAsync.when(
                data: (rooms) {
                  if (rooms.isEmpty) {
                    return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                  }
                  return Column(
                    children: rooms.take(3).map((room) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _buildRoomCard(room, currencyFormatter),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                error: (err, _) => Text('Lỗi tải phòng: $err'),
              ),
              const SizedBox(height: 20),

              // 5. Bài đăng tìm ở ghép mới nhất (Realtime Firestore)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'BẠN Ở GHÉP ĐANG TÌM PHÒNG',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted,
                      letterSpacing: 0.8,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const RoommateCommunityScreen()));
                    },
                    child: const Text('Xem tất cả', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                  ),
                ],
              ),
              roommatePostsAsync.when(
                data: (posts) {
                  if (posts.isEmpty) {
                    return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                  }
                  return Column(
                    children: posts.take(2).map((post) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _buildRoommateCard(post, currencyFormatter),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                error: (err, _) => Text('Lỗi tải bài ở ghép: $err'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF0F2F5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDark),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(RoomModel room, NumberFormat formatter) {
    final priceStr = '${formatter.format(room.price)} đ';

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFF0F2F5)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RoomDetailScreen(room: room)),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with badges
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: room.images.isNotEmpty
                        ? Image.network(
                            room.images.first,
                            width: double.infinity,
                            height: 140,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.apartment, size: 48, color: Colors.grey)),
                          )
                        : const Center(child: Icon(Icons.apartment, size: 48, color: Colors.grey)),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        room.roomType,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$priceStr/tháng',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            '${room.rating}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    room.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          '${room.address}, ${room.district}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '• ${room.area} m²',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoommateCard(RoommatePostModel post, NumberFormat formatter) {
    final budgetStr = '${formatter.format(post.budgetMin)} - ${formatter.format(post.budgetMax)} đ';

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFF0F2F5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primaryContainer,
                  child: Text(
                    post.authorName.isNotEmpty ? post.authorName[0] : 'N',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            post.authorName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, size: 14, color: AppColors.primary),
                        ],
                      ),
                      Text(
                        '${post.authorGender} • ${post.authorAge} tuổi • ${post.authorOccupation}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: post.hasRoom ? AppColors.primaryContainer : AppColors.infoContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    post.hasRoom ? 'Đã có phòng' : 'Tìm ở ghép',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: post.hasRoom ? AppColors.primary : AppColors.info,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              post.title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Ngân sách: $budgetStr/tháng',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            const SizedBox(height: 2),
            Text(
              'Tiêu chí: ${post.habits.join(', ')}',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () {
                  final currentUser = ref.read(currentUserProvider);
                  final profile = ref.read(userProfileProvider).value;
                  if (currentUser == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vui lòng đăng nhập để gửi tin nhắn'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                    return;
                  }
                  if (currentUser.uid == post.authorId) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đây là bài đăng của chính bạn')),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatDetailScreen(
                        receiverId: post.authorId,
                        receiverName: post.authorName,
                        receiverAvatar: post.authorAvatar,
                        receiverPhone: post.contactPhone,
                        isLandlord: false,
                        currentUserId: currentUser.uid,
                        currentUserName: profile?.displayName ?? currentUser.displayName ?? 'Khách thuê',
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('Liên hệ ở ghép', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
