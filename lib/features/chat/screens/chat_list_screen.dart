import 'dart:async';
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
  Timer? _searchDebounce;

  // Quản lý trạng thái tương tác cuộc trò chuyện: Ghim, Tắt thông báo, Xóa
  final Set<String> _pinnedIds = {};
  final Set<String> _mutedIds = {};
  final Set<String> _deletedIds = {};

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 150), () {
      if (mounted) {
        final query = value.trim().toLowerCase();
        if (query != _searchQuery) {
          setState(() {
            _searchQuery = query;
          });
        }
      }
    });
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

    final allConversations = mergedMap.values
        .where((c) => !_deletedIds.contains(c.id))
        .toList()
      ..sort((a, b) {
        final aPinned = _pinnedIds.contains(a.id);
        final bPinned = _pinnedIds.contains(b.id);
        if (aPinned && !bPinned) return -1;
        if (!aPinned && bPinned) return 1;
        return b.lastMessageTime.compareTo(a.lastMessageTime);
      });

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
      if (_selectedFilter == 'unread' && conv.unreadCount <= 0 && conv.isRead) return false;

      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tin nhắn & Trao đổi'),
        actions: [
          IconButton(
            icon: const Badge(
              smallSize: 8,
              backgroundColor: AppColors.danger,
              child: Icon(Icons.notifications_none_outlined),
            ),
            tooltip: 'Thông báo',
            onPressed: () => _showNotificationSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Thanh tìm kiếm hội thoại Real-time (Tc_CHAT)
          RepaintBoundary(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm cuộc trò chuyện, phòng trọ...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchDebounce?.cancel();
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
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
          ),

          // 2. Thanh Filter Chips (Tất cả, Chủ trọ, Ở ghép, Chưa đọc)
          RepaintBoundary(
            child: Container(
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
                              _searchDebounce?.cancel();
                              _searchController.clear();
                              _searchQuery = '';
                              _selectedFilter = 'all';
                            });
                          },
                          child: const Text('Đặt lại bộ lọc'),
                        ),
                      ],
                    ),
                  )
                : RepaintBoundary(
                    child: ListView.separated(
                      physics: const ClampingScrollPhysics(),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: filteredConversations.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, indent: 76),
                      itemBuilder: (context, index) {
                      final item = filteredConversations[index];
                      final isUnread = item.unreadCount > 0 || !item.isRead;
                      final displayUnreadCount = item.unreadCount > 0 ? item.unreadCount : (isUnread ? 1 : 0);
                      final isPinned = _pinnedIds.contains(item.id);
                      final isMuted = _mutedIds.contains(item.id);

                      return _SwipeableConversationItem(
                        key: ValueKey(item.id),
                        isPinned: isPinned,
                        isMuted: isMuted,
                        onDelete: () => _confirmDeleteConversation(context, item.id, item.partnerName),
                        onTogglePin: () => _togglePin(item.id, item.partnerName),
                        onToggleMute: () => _toggleMute(item.id, item.partnerName),
                        child: Material(
                          color: isPinned
                              ? const Color(0xFFF0FDF4)
                              : (isUnread ? const Color(0xFFF8FAFC) : Colors.white),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: isUnread ? AppColors.primary : AppColors.primaryContainer,
                                  child: Text(
                                    item.partnerName.isNotEmpty ? item.partnerName[0] : 'U',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isUnread ? Colors.white : AppColors.primary,
                                      fontSize: 18,
                                    ),
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
                                      if (isPinned) ...[
                                        const Icon(Icons.push_pin_rounded, color: Color(0xFF2563EB), size: 14),
                                        const SizedBox(width: 4),
                                      ],
                                      Flexible(
                                        child: Text(
                                          item.partnerName,
                                          style: TextStyle(
                                            fontWeight: isUnread ? FontWeight.w900 : FontWeight.w600,
                                            fontSize: isUnread ? 15.5 : 14,
                                            color: isUnread ? const Color(0xFF0F172A) : AppColors.textDark,
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
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isMuted) ...[
                                      const Icon(Icons.notifications_off_outlined, size: 13, color: Color(0xFF94A3B8)),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      _formatTime(item.lastMessageTime),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isUnread ? AppColors.primary : AppColors.textMuted,
                                        fontWeight: isUnread ? FontWeight.w900 : FontWeight.normal,
                                      ),
                                    ),
                                  ],
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
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.lastMessage,
                                      style: TextStyle(
                                        fontSize: isUnread ? 14 : 13,
                                        color: isUnread ? const Color(0xFF0F172A) : AppColors.textMuted,
                                        fontWeight: isUnread ? FontWeight.w900 : FontWeight.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isUnread)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444),
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        displayUnreadCount > 99 ? '99+' : '$displayUnreadCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () {
                            final currentUserId = user?.uid ?? 'guest_uid';
                            final currentUserName = profile?.displayName ?? user?.displayName ?? 'Khách thuê';

                            // Đánh dấu đã đọc cuộc trò chuyện
                            if (isUnread && user != null) {
                              ref.read(chatServiceProvider).markAsRead(currentUserId, item.partnerId);
                            }

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
                      ),
                    ),
                  );
                },
                ),
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

  // --- CÁC HÀM THAO TÁC HỘI THOẠI: GHIM, TẮT THÔNG BÁO, XÓA ---
  void _togglePin(String id, String name) {
    final isPinned = _pinnedIds.contains(id);
    setState(() {
      if (isPinned) {
        _pinnedIds.remove(id);
      } else {
        _pinnedIds.add(id);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(isPinned ? 'Đã bỏ ghim cuộc trò chuyện với $name' : 'Đã ghim cuộc trò chuyện với $name lên đầu'),
      ),
    );
  }

  void _toggleMute(String id, String name) {
    final isMuted = _mutedIds.contains(id);
    setState(() {
      if (isMuted) {
        _mutedIds.remove(id);
      } else {
        _mutedIds.add(id);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(isMuted ? 'Đã bật thông báo cho $name' : 'Đã tắt thông báo cho $name'),
      ),
    );
  }

  void _confirmDeleteConversation(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 22),
            SizedBox(width: 8),
            Text('Xóa cuộc trò chuyện?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa cuộc trò chuyện với "$name"? Lịch sử trò chuyện sẽ được ẩn khỏi danh sách của bạn.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _deletedIds.add(id);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã xóa cuộc trò chuyện với $name'),
                  action: SnackBarAction(
                    label: 'Hoàn tác',
                    textColor: Colors.amber,
                    onPressed: () {
                      setState(() {
                        _deletedIds.remove(id);
                      });
                    },
                  ),
                ),
              );
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  // --- MODAL BOTTOM SHEET: TRUNG TÂM THÔNG BÁO ---
  void _showNotificationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.notifications_outlined, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thông báo',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Cập nhật tin nhắn & lịch xem phòng mới nhất',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '3 mới',
                      style: TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildNotificationItem(
                    icon: Icons.calendar_month_rounded,
                    iconBg: const Color(0xFFDCFCE7),
                    iconColor: const Color(0xFF16A34A),
                    title: 'Xác nhận lịch hẹn xem phòng',
                    content: 'Cô Lan Nhà Trọ đã đồng ý lịch hẹn xem phòng #LT-104 vào lúc 15:00 ngày mai.',
                    time: '15 phút trước',
                    isUnread: true,
                  ),
                  _buildNotificationItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    iconBg: const Color(0xFFDBEAFE),
                    iconColor: const Color(0xFF2563EB),
                    title: 'Tin nhắn mới từ Chú Ba Linh Trung',
                    content: 'Phòng 101 còn trống nha cháu, cháu qua xem lúc mấy giờ?',
                    time: '45 phút trước',
                    isUnread: true,
                  ),
                  _buildNotificationItem(
                    icon: Icons.verified_user_outlined,
                    iconBg: AppColors.primarySurface,
                    iconColor: AppColors.primary,
                    title: 'Bảo vệ tiền cọc an toàn',
                    content: 'Giao dịch đặt cọc giữ phòng của bạn được bảo vệ 100% qua HomeShare Escrow.',
                    time: '2 giờ trước',
                    isUnread: true,
                  ),
                  _buildNotificationItem(
                    icon: Icons.people_outline_rounded,
                    iconBg: const Color(0xFFF3E8FF),
                    iconColor: const Color(0xFF7C3AED),
                    title: 'Gợi ý bạn ở ghép phù hợp',
                    content: 'Nguyễn Văn Nam có lối sống và ngân sách tương thích 95% vừa gửi lời kết nối.',
                    time: '1 ngày trước',
                    isUnread: false,
                  ),
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã đánh dấu đọc tất cả thông báo')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Đánh dấu đọc tất cả', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String content,
    required String time,
    required bool isUnread,
  }) {
    return Container(
      color: isUnread ? const Color(0xFFF8FAFC) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(time, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  content,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.35),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isUnread) ...[
            const SizedBox(width: 8),
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Widget hỗ trợ trượt sang trái (Swipe Left) để lộ các nút tính năng: Ghim, Tắt TB, Xóa
class _SwipeableConversationItem extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleMute;
  final bool isPinned;
  final bool isMuted;

  const _SwipeableConversationItem({
    super.key,
    required this.child,
    required this.onDelete,
    required this.onTogglePin,
    required this.onToggleMute,
    required this.isPinned,
    required this.isMuted,
  });

  @override
  State<_SwipeableConversationItem> createState() => _SwipeableConversationItemState();
}

class _SwipeableConversationItemState extends State<_SwipeableConversationItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _dragExtent = 0.0;
  static const double _maxDragDistance = 210.0; // 3 nút x 70dp

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    )..addListener(() {
        setState(() {
          _dragExtent = _animation.value;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _animation = Tween<double>(begin: _dragExtent, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.reset();
    _controller.forward();
  }

  void _open() => _animateTo(-_maxDragDistance);
  void _close() => _animateTo(0.0);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) {
          setState(() {
            _dragExtent = (_dragExtent + (details.primaryDelta ?? 0.0)).clamp(-_maxDragDistance, 0.0);
          });
        },
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0.0;
          if (_dragExtent < -(_maxDragDistance / 3) || velocity < -300) {
            _open();
          } else {
            _close();
          }
        },
        child: Stack(
          children: [
            // Các nút chức năng xuất hiện khi kéo sang trái (chỉ hiển thị khi đang kéo sang trái)
            if (_dragExtent < 0)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: _maxDragDistance,
                    height: double.infinity,
                    child: Row(
                      children: [
                        // 1. Ghim / Bỏ ghim
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              _close();
                              widget.onTogglePin();
                            },
                            child: Container(
                              color: const Color(0xFF2563EB),
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    widget.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    widget.isPinned ? 'Bỏ ghim' : 'Ghim',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // 2. Tắt / Bật thông báo
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              _close();
                              widget.onToggleMute();
                            },
                            child: Container(
                              color: const Color(0xFF7C3AED),
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    widget.isMuted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    widget.isMuted ? 'Bật TB' : 'Tắt TB',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // 3. Xóa cuộc trò chuyện
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              _close();
                              widget.onDelete();
                            },
                            child: Container(
                              color: const Color(0xFFEF4444),
                              alignment: Alignment.center,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
                                  SizedBox(height: 3),
                                  Text(
                                    'Xóa',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Lớp giao diện cuộc trò chuyện phía trước (đảm bảo 100% đục để không bị nhìn xuyên)
            Transform.translate(
              offset: Offset(_dragExtent, 0),
              child: Material(
                color: widget.isPinned ? const Color(0xFFF0FDF4) : Colors.white,
                child: GestureDetector(
                  onTap: () {
                    if (_dragExtent < -10) {
                      _close();
                    }
                  },
                  behavior: _dragExtent < -10 ? HitTestBehavior.opaque : HitTestBehavior.translucent,
                  child: widget.child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
