import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/chat_service.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/models/room_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import 'chat_detail_screen.dart';

/// Màn hình Danh sách Cuộc trò chuyện & Trao đổi (Feature #10 theo SRS & Tc_CHAT)
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'landlord', 'roommate', 'unread'

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(userProfileProvider).value;

    final firestoreConversationsAsync = user != null
        ? ref.watch(userConversationsStreamProvider(user.uid))
        : const AsyncValue<List<ConversationModel>>.data([]);

    // Danh sách cuộc trò chuyện mẫu thực tế để luôn sẵn sàng hiển thị và trải nghiệm
    final sampleConversations = [
      ConversationModel(
        id: 'host_chu_ba_101',
        partnerId: 'host_chu_ba_101',
        partnerName: 'Chú Ba Linh Trung (Chủ trọ)',
        partnerPhone: '0903888999',
        isLandlord: true,
        lastMessage: 'Phòng 101 còn trống nha cháu, cháu qua xem lúc mấy giờ?',
        lastMessageTime: DateTime.now().subtract(const Duration(minutes: 15)),
        unreadCount: 1,
        roomCode: '#LT-802',
        roomTitle: 'Phòng trọ cao cấp gần ĐH Sư Phạm Kỹ Thuật',
        roomPrice: 3500000,
        roomImage: 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=600',
      ),
      ConversationModel(
        id: 'host_linhtrung_99',
        partnerId: 'host_linhtrung_99',
        partnerName: 'Cô Lan Nhà Trọ',
        partnerPhone: '0912345678',
        isLandlord: true,
        lastMessage: 'Dạ cô đã nhận được thông tin hẹn xem phòng rồi nhé.',
        lastMessageTime: DateTime.now().subtract(const Duration(hours: 3)),
        unreadCount: 0,
        roomCode: '#LT-104',
        roomTitle: 'Phòng ban công thoáng mát ĐH Nông Lâm',
        roomPrice: 2800000,
        roomImage: 'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=600',
      ),
      ConversationModel(
        id: 'user_nam_99',
        partnerId: 'user_nam_99',
        partnerName: 'Nguyễn Văn Nam (Tìm ở ghép)',
        partnerPhone: '0987654321',
        isLandlord: false,
        lastMessage: 'Chào bạn, bạn đã tìm được ai ở ghép cùng chưa?',
        lastMessageTime: DateTime.now().subtract(const Duration(days: 1)),
        unreadCount: 0,
        roomCode: '#OG-302',
        roomTitle: 'Căn hộ mini 2 phòng ngủ ghép đôi',
        roomPrice: 1800000,
      ),
      ConversationModel(
        id: 'host_hoang_quan',
        partnerId: 'host_hoang_quan',
        partnerName: 'Anh Hoàng Quản Lý Trọ',
        partnerPhone: '0933221100',
        isLandlord: true,
        lastMessage: 'Bạn có thể xem phòng vào sáng mai lúc 9h nhé.',
        lastMessageTime: DateTime.now().subtract(const Duration(days: 2)),
        unreadCount: 0,
        roomCode: '#HQ-201',
        roomTitle: 'Phòng trọ đầy đủ nội thất gần KTX Khu B',
        roomPrice: 3200000,
      ),
    ];

    // Kết hợp dữ liệu từ Firestore và danh sách mẫu
    final liveConversations = firestoreConversationsAsync.value ?? [];
    final Map<String, ConversationModel> mergedMap = {};

    // 1. Nạp từ Firestore trước (nếu có cuộc trò chuyện mới)
    for (final c in liveConversations) {
      mergedMap[c.id] = c;
    }
    // 2. Bổ sung các cuộc trò chuyện mẫu nếu chưa có
    for (final s in sampleConversations) {
      if (!mergedMap.containsKey(s.id)) {
        mergedMap[s.id] = s;
      }
    }

    final allConversations = mergedMap.values.toList()
      ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

    // Lọc theo tìm kiếm và tab phân loại
    final filteredConversations = allConversations.where((conv) {
      // 1. Lọc theo từ khóa tìm kiếm
      if (_searchQuery.isNotEmpty) {
        final matchName = conv.partnerName.toLowerCase().contains(_searchQuery);
        final matchMsg = conv.lastMessage.toLowerCase().contains(_searchQuery);
        final matchRoom = conv.roomTitle?.toLowerCase().contains(_searchQuery) ?? false;
        final matchCode = conv.roomCode?.toLowerCase().contains(_searchQuery) ?? false;
        if (!matchName && !matchMsg && !matchRoom && !matchCode) {
          return false;
        }
      }

      // 2. Lọc theo danh mục tab
      if (_selectedFilter == 'landlord' && !conv.isLandlord) return false;
      if (_selectedFilter == 'roommate' && conv.isLandlord) return false;
      if (_selectedFilter == 'unread' && conv.unreadCount <= 0) return false;

      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tin nhắn & Trao đổi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Đánh dấu tất cả đã đọc',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã đánh dấu tất cả tin nhắn là đã đọc')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Thanh tìm kiếm hội thoại Real-time (Tc_CHAT)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm cuộc trò chuyện, phòng trọ...',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),

          // 2. Thanh Filter Chips (Tất cả, Chủ trọ, Ở ghép, Chưa đọc)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _buildFilterChip('all', 'Tất cả'),
                const SizedBox(width: 8),
                _buildFilterChip('landlord', 'Chủ trọ'),
                const SizedBox(width: 8),
                _buildFilterChip('roommate', 'Ở ghép'),
                const SizedBox(width: 8),
                _buildFilterChip('unread', 'Chưa đọc'),
              ],
            ),
          ),
          const Divider(height: 1),

          // 3. Danh sách cuộc trò chuyện
          Expanded(
            child: filteredConversations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mark_chat_read_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text(
                          'Không tìm thấy cuộc trò chuyện nào phù hợp',
                          style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Hãy thử thay đổi từ khóa hoặc bộ lọc danh mục.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _selectedFilter = 'all';
                            });
                          },
                          child: const Text('Đặt lại bộ lọc'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    primary: false,
                    itemCount: filteredConversations.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 76),
                    itemBuilder: (context, index) {
                      final item = filteredConversations[index];
                      final isUnread = item.unreadCount > 0;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: AppColors.primaryContainer,
                              child: Text(
                                item.partnerName.isNotEmpty ? item.partnerName[0] : 'U',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 18),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      item.partnerName,
                                      style: TextStyle(
                                        fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (item.isLandlord) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified, color: AppColors.primary, size: 14),
                                  ],
                                ],
                              ),
                            ),
                            Text(
                              _formatTime(item.lastMessageTime),
                              style: TextStyle(
                                fontSize: 11,
                                color: isUnread ? AppColors.primary : AppColors.textMuted,
                                fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.roomCode != null || item.roomTitle != null) ...[
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${item.roomCode ?? ''} ${item.roomTitle ?? ''}'.trim(),
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.lastMessage,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isUnread ? AppColors.textDark : AppColors.textMuted,
                                      fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isUnread)
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${item.unreadCount}',
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () {
                          final currentUserId = user?.uid ?? 'guest_uid';
                          final currentUserName = profile?.displayName ?? user?.displayName ?? 'Khách thuê';

                          // Khởi tạo RoomModel nếu cuộc trò chuyện liên kết với phòng
                          RoomModel? pinnedRoom;
                          if (item.roomTitle != null && item.roomPrice != null) {
                            pinnedRoom = RoomModel(
                              id: item.roomCode ?? 'room_sample',
                              title: item.roomTitle!,
                              description: 'Phòng trọ tiện nghi, an ninh 24/7.',
                              price: item.roomPrice!,
                              deposit: item.roomPrice!,
                              address: 'Linh Trung, TP. Thủ Đức, TP. Hồ Chí Minh',
                              district: 'TP. Thủ Đức',
                              city: 'TP. Hồ Chí Minh',
                              area: 25,
                              roomType: 'Phòng trọ',
                              amenities: ['Máy lạnh', 'Gác lửng', 'Wifi'],
                              images: item.roomImage != null ? [item.roomImage!] : [],
                              hostId: item.partnerId,
                              hostName: item.partnerName,
                              hostPhone: item.partnerPhone,
                              hostAvatar: item.partnerAvatar,
                              rating: 4.8,
                              reviewCount: 16,
                              createdAt: DateTime.now(),
                            );
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatDetailScreen(
                                receiverId: item.partnerId,
                                receiverName: item.partnerName,
                                receiverAvatar: item.partnerAvatar,
                                receiverPhone: item.partnerPhone,
                                isLandlord: item.isLandlord,
                                currentUserId: currentUserId,
                                currentUserName: currentUserName,
                                pinnedRoom: pinnedRoom,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = key),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return DateFormat('HH:mm').format(time);
    } else if (difference.inHours < 24 && time.day == now.day) {
      return DateFormat('HH:mm').format(time);
    } else if (difference.inDays < 2) {
      return 'Hôm qua';
    } else {
      return DateFormat('dd/MM').format(time);
    }
  }
}
