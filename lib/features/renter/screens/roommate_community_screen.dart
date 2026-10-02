import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/roommate_service.dart';
import '../../../data/models/roommate_post_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../chat/screens/chat_detail_screen.dart';
import 'create_roommate_post_screen.dart';
import 'roommate_lifestyle_filter_sheet.dart';
import 'roommate_post_detail_screen.dart';

/// Màn hình Tìm Ở Ghép chuẩn Figma 100% (Hình 1)
/// Tích hợp Bộ lọc Lifestyle & Ở ghép AI Match (Hình 2)
class RoommateCommunityScreen extends ConsumerStatefulWidget {
  const RoommateCommunityScreen({super.key});

  @override
  ConsumerState<RoommateCommunityScreen> createState() => _RoommateCommunityScreenState();
}

class _RoommateCommunityScreenState extends ConsumerState<RoommateCommunityScreen> {
  // Bộ lọc hiện tại (Mặc định: Toàn quốc, Tất cả giới tính, Đã có phòng)
  RoommateFilterParams _currentFilters = const RoommateFilterParams(
    district: 'Tất cả',
    targetGender: 'Tất cả',
    hasRoom: true, // Mặc định: Đang tìm người ghép (Có phòng)
    occupation: 'Tất cả',
    minMatchRate: 0,
  );

  final TextEditingController _searchController = TextEditingController();
  final Set<String> _bookmarkedPostIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Mở Bottom Sheet "Bộ lọc Lifestyle & Ở ghép AI Match" (Hình 2)
  void _openLifestyleFilterSheet(int matchingCount) {
    RoommateLifestyleFilterSheet.show(
      context,
      initialFilters: _currentFilters,
      matchingCount: matchingCount,
      onApply: (updated) {
        setState(() {
          _currentFilters = updated;
        });
      },
    );
  }

  /// Format thời gian hiển thị tương đối
  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      final mins = diff.inMinutes.clamp(1, 59);
      return '$mins phút trước';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} giờ trước';
    } else {
      return '${diff.inDays} ngày trước';
    }
  }

  /// Visual metadata cho các nhãn thói quen sinh hoạt
  Map<String, dynamic> _getHabitVisual(String habit) {
    final lower = habit.toLowerCase();
    if (lower.contains('thuốc')) {
      return {'icon': Icons.smoke_free_rounded, 'color': const Color(0xFFEF4444), 'bg': const Color(0xFFFEE2E2)};
    } else if (lower.contains('yên tĩnh')) {
      return {'icon': Icons.nightlight_round, 'color': const Color(0xFF3B82F6), 'bg': const Color(0xFFEFF6FF)};
    } else if (lower.contains('sạch sẽ')) {
      return {'icon': Icons.cleaning_services_rounded, 'color': const Color(0xFF10B981), 'bg': const Color(0xFFECFDF5)};
    } else if (lower.contains('thân thiện') || lower.contains('vui vẻ')) {
      return {'icon': Icons.sentiment_satisfied_alt_rounded, 'color': const Color(0xFFF59E0B), 'bg': const Color(0xFFFEF3C7)};
    } else if (lower.contains('giờ giấc')) {
      return {'icon': Icons.access_time_rounded, 'color': const Color(0xFF3B82F6), 'bg': const Color(0xFFEFF6FF)};
    } else if (lower.contains('xe máy')) {
      return {'icon': Icons.two_wheeler_rounded, 'color': const Color(0xFF0284C7), 'bg': const Color(0xFFE0F2FE)};
    } else if (lower.contains('thể thao')) {
      return {'icon': Icons.sports_soccer_rounded, 'color': const Color(0xFFD97706), 'bg': const Color(0xFFFEF3C7)};
    } else if (lower.contains('ồn ào') || lower.contains('tụ tập')) {
      return {'icon': Icons.volume_off_rounded, 'color': const Color(0xFFEF4444), 'bg': const Color(0xFFFEE2E2)};
    } else if (lower.contains('chăm học')) {
      return {'icon': Icons.menu_book_rounded, 'color': const Color(0xFF3B82F6), 'bg': const Color(0xFFEFF6FF)};
    } else if (lower.contains('nấu ăn')) {
      return {'icon': Icons.restaurant_rounded, 'color': const Color(0xFF0284C7), 'bg': const Color(0xFFE0F2FE)};
    } else if (lower.contains('dậy sớm')) {
      return {'icon': Icons.wb_sunny_rounded, 'color': const Color(0xFFF59E0B), 'bg': const Color(0xFFFEF3C7)};
    } else if (lower.contains('thú cưng') || lower.contains('pet')) {
      return {'icon': Icons.pets_rounded, 'color': const Color(0xFFF59E0B), 'bg': const Color(0xFFFEF3C7)};
    } else if (lower.contains('dẫn bạn')) {
      return {'icon': Icons.people_alt_rounded, 'color': const Color(0xFF2563EB), 'bg': const Color(0xFFEFF6FF)};
    }
    return {'icon': Icons.check_circle_outline, 'color': const Color(0xFF475569), 'bg': const Color(0xFFF1F5F9)};
  }

  void _onToggleBookmark(String postId) {
    setState(() {
      if (_bookmarkedPostIds.contains(postId)) {
        _bookmarkedPostIds.remove(postId);
      } else {
        _bookmarkedPostIds.add(postId);
      }
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_bookmarkedPostIds.contains(postId) ? 'Đã lưu bài đăng vào mục yêu thích ✓' : 'Đã bỏ lưu bài đăng'),
        backgroundColor: const Color(0xFF2563EB),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _navigateToChat(RoommatePostModel post) {
    final currentUser = ref.read(currentUserProvider);
    final profile = ref.read(userProfileProvider).value;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để gửi tin nhắn')),
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
          currentUserId: currentUser.uid,
          currentUserName: profile?.displayName ?? 'Khách thuê',
        ),
      ),
    );
  }

  /// Mở Màn Hình Chi Tiết Bài Đăng Ở Ghép
  void _openPostDetailModal(RoommatePostModel post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoommatePostDetailScreen(post: post),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final postsAsync = ref.watch(roommatePostsStreamProvider(_currentFilters));

    final count = postsAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 18,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateRoommatePostScreen()),
          );
        },
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Đăng tin ở ghép',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. App Bar chuẩn Figma
            _buildFigmaAppBar(profile),

            // 2. Search & Filter Bar
            _buildSearchAndFilterBar(count),

            // 3. Quick Filter Chips
            _buildQuickFilterChips(count),

            // 4. Segment Tab Switcher: "Đang tìm người ghép (Có phòng)" vs "Người cần tìm phòng ghép"
            _buildSegmentTabSwitcher(),

            // 5. Danh sách bài đăng & Banner AI Matching
            Expanded(
              child: postsAsync.when(
                data: (posts) => _buildPostsList(posts, count),
                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text('Lỗi tải dữ liệu: $err', textAlign: TextAlign.center),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// App Bar chuẩn Figma
  Widget _buildFigmaAppBar(UserProfile? profile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.home_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Tìm Ở Ghép',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          Row(
            children: [
              // Notification Bell with Badge Dot
              Stack(
                alignment: Alignment.topRight,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF334155), size: 24),
                    onPressed: () {},
                  ),
                  Positioned(
                    top: 10,
                    right: 12,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              // Profile Avatar
              CircleAvatar(
                radius: 17,
                backgroundColor: const Color(0xFFE2E8F0),
                backgroundImage: profile?.avatarUrl.isNotEmpty == true
                    ? NetworkImage(profile!.avatarUrl)
                    : const NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Search & Filter Row
  Widget _buildSearchAndFilterBar(int matchingCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 20, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Tìm người ghép theo trường học, quận...',
                        hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                      onChanged: (val) {
                        setState(() {
                          _currentFilters = _currentFilters.copyWith(searchQuery: val);
                        });
                      },
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    InkWell(
                      onTap: () {
                        _searchController.clear();
                        setState(() {
                          _currentFilters = _currentFilters.copyWith(searchQuery: '');
                        });
                      },
                      child: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Nút Bộ Lọc (Icon Filter Tune tròn) -> Mở Hình 2
          InkWell(
            onTap: () => _openLifestyleFilterSheet(matchingCount),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: const Icon(Icons.tune_rounded, size: 20, color: Color(0xFF334155)),
            ),
          ),
        ],
      ),
    );
  }

  /// Quick Filter Chips
  Widget _buildQuickFilterChips(int matchingCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Chip Khu vực
            _buildFilterPill(
              label: _currentFilters.district == 'Tất cả' ? 'Khu vực: Toàn quốc' : 'Khu vực: ${_currentFilters.district}',
              hasDropdown: true,
              isSelected: _currentFilters.district != 'Tất cả',
              onTap: () => _openLifestyleFilterSheet(matchingCount),
            ),
            const SizedBox(width: 8),
            // Chip Giới tính
            _buildFilterPill(
              label: 'Giới tính: ${_currentFilters.targetGender}',
              hasDropdown: true,
              isSelected: _currentFilters.targetGender != 'Tất cả',
              onTap: () => _openLifestyleFilterSheet(matchingCount),
            ),
            const SizedBox(width: 8),
            // Chip Ngân sách
            _buildFilterPill(
              label: 'Ngân sách...',
              hasDropdown: false,
              isSelected: _currentFilters.budgetMin != null,
              onTap: () => _openLifestyleFilterSheet(matchingCount),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool hasDropdown,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
            if (hasDropdown) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Segment Tab Switcher: "Đang tìm người ghép (Có phòng)" vs "Người cần tìm phòng ghép"
  Widget _buildSegmentTabSwitcher() {
    final isHasRoom = _currentFilters.hasRoom == true;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Container(
        height: 40,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _currentFilters = _currentFilters.copyWith(hasRoom: true);
                  });
                },
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  decoration: BoxDecoration(
                    color: isHasRoom ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: isHasRoom
                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Đang tìm người ghép (Có phòng)',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isHasRoom ? FontWeight.bold : FontWeight.w500,
                      color: isHasRoom ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _currentFilters = _currentFilters.copyWith(hasRoom: false);
                  });
                },
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  decoration: BoxDecoration(
                    color: !isHasRoom ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: !isHasRoom
                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Người cần tìm phòng ghép',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: !isHasRoom ? FontWeight.bold : FontWeight.w500,
                      color: !isHasRoom ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Danh sách bài đăng & Banner AI Matching
  Widget _buildPostsList(List<RoommatePostModel> posts, int matchingCount) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        // Banner AI Matching
        _buildAiMatchBanner(matchingCount),

        const SizedBox(height: 12),

        // Danh sách thẻ bài đăng
        if (posts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.feed_outlined, size: 54, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text(
                    'Chưa có bài đăng nào',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hãy là người đầu tiên đăng tin tìm bạn ở ghép!',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          )
        else
          ...posts.map((post) => _buildPostCard(post)),

        const SizedBox(height: 8),

        // Banner CTA Tạo bài đăng cuối danh sách
        _buildBottomCtaBanner(),
      ],
    );
  }

  /// Banner Gợi ý AI Lifestyle Matching
  Widget _buildAiMatchBanner(int matchingCount) {
    return InkWell(
      onTap: () => _openLifestyleFilterSheet(matchingCount),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDBEAFE)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFF2563EB),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Độ tương thích lối sống',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Hệ thống gợi ý bạn cùng phòng hợp gu 94%',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF3B82F6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF2563EB), size: 22),
          ],
        ),
      ),
    );
  }

  /// Thẻ Bài Đăng Chuẩn Figma 100% (Khớp thiết kế ảnh người dùng)
  Widget _buildPostCard(RoommatePostModel post) {
    final currencyFmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final isBookmarked = _bookmarkedPostIds.contains(post.id);

    // Format giá hiển thị
    String priceText;
    if (post.hasRoom && post.pricePerPerson > 0) {
      priceText = '~${currencyFmt.format(post.pricePerPerson)}';
    } else if (post.pricePerPerson > 0) {
      priceText = '~${currencyFmt.format(post.pricePerPerson)}';
    } else {
      priceText = '${(post.budgetMin / 1000000).toStringAsFixed(1)} - ${(post.budgetMax / 1000000).toStringAsFixed(0)} triệu';
    }

    return InkWell(
      onTap: () => _openPostDetailModal(post),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Tag trạng thái + Thời gian đăng
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Badge Tình trạng phòng
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: post.hasRoom ? const Color(0xFFDCEEFE) : const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: post.hasRoom ? const Color(0xFF0284C7) : const Color(0xFFEA580C),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      post.hasRoom ? 'Đã có phòng sẵn' : 'Chưa có phòng',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: post.hasRoom ? const Color(0xFF0369A1) : const Color(0xFFC2410C),
                      ),
                    ),
                  ],
                ),
              ),

              // Thời gian
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    _formatTimeAgo(post.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Thông tin Tác giả: Avatar có tick xanh, Tên, Tuổi, Trường/Nghề + Bookmark
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFFEFF6FF),
                    backgroundImage: post.authorAvatar.isNotEmpty
                        ? (post.authorAvatar.startsWith('http')
                            ? NetworkImage(post.authorAvatar) as ImageProvider
                            : FileImage(File(post.authorAvatar)))
                        : null,
                    child: post.authorAvatar.isEmpty
                        ? Text(
                            post.authorName.isNotEmpty ? post.authorName[0] : 'U',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          )
                        : null,
                  ),
                  if (post.isVerified)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          width: 17,
                          height: 17,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2563EB),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, size: 11, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: post.authorName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          TextSpan(
                            text: ' • ${post.authorAge} tuổi',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          post.authorOccupation.contains('SV') || post.authorOccupation.contains('Sinh viên')
                              ? Icons.school_outlined
                              : Icons.work_outline_rounded,
                          size: 15,
                          color: const Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            post.authorOccupation,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2563EB),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Nút Bookmark tròn bên phải
              InkWell(
                onTap: () => _onToggleBookmark(post.id),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: isBookmarked ? const Color(0xFF2563EB) : const Color(0xFF475569),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 3. Khung nội dung xám xanh nhạt bo góc (Tiêu đề, Giá, Địa chỉ)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FD),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: priceText,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      TextSpan(
                        text: post.hasRoom ? ' /người/tháng' : ' /tháng',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1.0),
                      child: Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        post.address,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF475569),
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 4. Hàng 2 ảnh căn phòng có nhãn chú thích
          _buildPhotosRow(post),

          const SizedBox(height: 12),

          // 5. Tiêu chí sinh hoạt (Lifestyle tags chuẩn Figma)
          Text(
            post.hasRoom ? 'TIÊU CHÍ SINH HOẠT:' : 'LỐI SỐNG & THÓI QUEN:',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (post.habits.isNotEmpty
                    ? post.habits
                    : ['Không hút thuốc', 'Yên tĩnh sau 23h', 'Sạch sẽ ngăn nắp', 'Thân thiện vui vẻ'])
                .take(4)
                .map((h) {
              final visual = _getHabitVisual(h);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(visual['icon'] as IconData, size: 14, color: visual['color'] as Color),
                    const SizedBox(width: 5),
                    Text(
                      h,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          // 6. Nút Hành Động: [💬 Nhắn tin trao đổi] + [Xem hồ sơ]
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToChat(post),
                    icon: const Icon(Icons.chat_bubble_outline, size: 17),
                    label: const Text(
                      'Nhắn tin trao đổi',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => _openPostDetailModal(post),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEFF6FF),
                      foregroundColor: const Color(0xFF0F172A),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      post.hasRoom ? 'Xem hồ sơ' : 'Xem chi tiết',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  /// Hiển thị 2 ảnh song song có chú thích chuẩn Figma
  Widget _buildPhotosRow(RoommatePostModel post) {
    List<String> images = post.images;
    if (images.isEmpty && post.hasRoom) {
      images = [
        'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=600',
        'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?w=600',
      ];
    }
    if (images.isEmpty) return const SizedBox.shrink();

    final captions = post.imageCaptions;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: 116,
        child: Row(
          children: [
            Expanded(
              child: _buildPhotoItem(
                images[0],
                captions.isNotEmpty ? captions[0] : 'Phòng ngủ máy lạnh',
              ),
            ),
            if (images.length > 1) ...[
              const SizedBox(width: 10),
              Expanded(
                child: _buildPhotoItem(
                  images[1],
                  captions.length > 1 ? captions[1] : 'Bếp chung rộng',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoItem(String imagePath, String caption) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildRoomImage(imagePath),
          if (caption.isNotEmpty)
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xCC1E293B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  caption,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoomImage(String imgUrl) {
    if (imgUrl.isEmpty) {
      return Container(
        color: const Color(0xFFF1F5F9),
        child: const Icon(Icons.image_outlined, color: Color(0xFF94A3B8), size: 28),
      );
    }
    if (imgUrl.startsWith('http://') || imgUrl.startsWith('https://')) {
      return Image.network(
        imgUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xFFF1F5F9),
          child: const Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8), size: 28),
        ),
      );
    }
    try {
      final file = File(imgUrl);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: const Color(0xFFF1F5F9),
            child: const Icon(Icons.image_outlined, color: Color(0xFF94A3B8), size: 28),
          ),
        );
      }
    } catch (_) {}
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Icon(Icons.image_outlined, color: Color(0xFF94A3B8), size: 28),
    );
  }

  /// Banner Kêu gọi Đăng tin cuối trang
  Widget _buildBottomCtaBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chưa tìm được bạn ghép ưng ý?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 3),
                Text(
                  'Tạo bài tìm người ghép miễn phí trong 1 phút',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateRoommatePostScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Đăng ngay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
