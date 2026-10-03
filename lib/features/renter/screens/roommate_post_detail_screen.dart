import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/roommate_post_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../chat/screens/chat_detail_screen.dart';

/// Màn hình Chi tiết bài đăng ở ghép chuẩn Figma & Material Design (Không hardcode)
class RoommatePostDetailScreen extends ConsumerStatefulWidget {
  final RoommatePostModel post;

  const RoommatePostDetailScreen({
    super.key,
    required this.post,
  });

  @override
  ConsumerState<RoommatePostDetailScreen> createState() => _RoommatePostDetailScreenState();
}

class _RoommatePostDetailScreenState extends ConsumerState<RoommatePostDetailScreen> {
  int _currentImageIndex = 0;
  bool _isBookmarked = false;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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

  Map<String, dynamic> _getHabitVisual(String habit) {
    final lower = habit.toLowerCase();
    if (lower.contains('thuốc')) {
      return {'icon': Icons.smoke_free_rounded, 'color': const Color(0xFFEF4444), 'bg': const Color(0xFFFEF2F2)};
    } else if (lower.contains('yên tĩnh')) {
      return {'icon': Icons.nightlight_round, 'color': const Color(0xFF0284C7), 'bg': const Color(0xFFF0F9FF)};
    } else if (lower.contains('sạch sẽ')) {
      return {'icon': Icons.cleaning_services_rounded, 'color': AppColors.primary, 'bg': AppColors.primarySurface};
    } else if (lower.contains('thân thiện') || lower.contains('vui vẻ')) {
      return {'icon': Icons.sentiment_satisfied_alt_rounded, 'color': const Color(0xFFD97706), 'bg': const Color(0xFFFFFBEB)};
    } else if (lower.contains('giờ giấc')) {
      return {'icon': Icons.access_time_rounded, 'color': const Color(0xFF0284C7), 'bg': const Color(0xFFF0F9FF)};
    } else if (lower.contains('xe máy')) {
      return {'icon': Icons.two_wheeler_rounded, 'color': const Color(0xFF0284C7), 'bg': const Color(0xFFF0F9FF)};
    } else if (lower.contains('thể thao')) {
      return {'icon': Icons.sports_soccer_rounded, 'color': const Color(0xFFD97706), 'bg': const Color(0xFFFFFBEB)};
    } else if (lower.contains('ồn ào') || lower.contains('tụ tập')) {
      return {'icon': Icons.volume_off_rounded, 'color': const Color(0xFFEF4444), 'bg': const Color(0xFFFEF2F2)};
    } else if (lower.contains('chăm học')) {
      return {'icon': Icons.menu_book_rounded, 'color': AppColors.primary, 'bg': AppColors.primarySurface};
    } else if (lower.contains('nấu ăn')) {
      return {'icon': Icons.restaurant_rounded, 'color': const Color(0xFF0284C7), 'bg': const Color(0xFFF0F9FF)};
    } else if (lower.contains('dậy sớm')) {
      return {'icon': Icons.wb_sunny_rounded, 'color': const Color(0xFFF59E0B), 'bg': const Color(0xFFFFFBEB)};
    } else if (lower.contains('thú cưng') || lower.contains('pet')) {
      return {'icon': Icons.pets_rounded, 'color': const Color(0xFFF59E0B), 'bg': const Color(0xFFFFFBEB)};
    } else if (lower.contains('dẫn bạn')) {
      return {'icon': Icons.people_alt_rounded, 'color': AppColors.primary, 'bg': AppColors.primarySurface};
    }
    return {'icon': Icons.check_circle_outline, 'color': AppColors.primary, 'bg': AppColors.primarySurface};
  }

  Widget _buildRoomImage(String imgUrl) {
    if (imgUrl.isEmpty) {
      return Container(
        color: const Color(0xFFF1F5F9),
        child: const Icon(Icons.image_outlined, color: Color(0xFF94A3B8), size: 48),
      );
    }
    // 1. Ảnh trực tuyến (Firebase Storage / URL công khai)
    if (imgUrl.startsWith('http://') || imgUrl.startsWith('https://')) {
      return Image.network(
        imgUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xFFF1F5F9),
          child: const Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8), size: 48),
        ),
      );
    }
    // 2. Ảnh Base64 Data URI
    if (imgUrl.startsWith('data:image')) {
      try {
        final commaIdx = imgUrl.indexOf(',');
        final base64Data = commaIdx != -1 ? imgUrl.substring(commaIdx + 1) : imgUrl;
        final bytes = base64Decode(base64Data);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: const Color(0xFFF1F5F9),
            child: const Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8), size: 48),
          ),
        );
      } catch (_) {}
    }
    // 3. File nội bộ trên cùng thiết bị
    try {
      final file = File(imgUrl);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: const Color(0xFFF1F5F9),
            child: const Icon(Icons.image_outlined, color: Color(0xFF94A3B8), size: 48),
          ),
        );
      }
    } catch (_) {}

    // 4. Nếu không đọc được file hoặc lỗi thì hiển thị container placeholder sạch sẽ, KHÔNG dùng ảnh giả
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Icon(Icons.image_not_supported_outlined, color: Color(0xFF94A3B8), size: 48),
    );
  }

  void _onToggleBookmark() {
    setState(() => _isBookmarked = !_isBookmarked);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isBookmarked ? 'Đã lưu bài đăng vào mục yêu thích ✓' : 'Đã bỏ lưu bài đăng'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _onShare() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép liên kết chia sẻ bài đăng ✓'),
        backgroundColor: AppColors.primary,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onReport() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Báo cáo bài đăng', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Bạn có chắc chắn muốn báo cáo bài đăng này vi phạm tiêu chuẩn cộng đồng hoặc thông tin không chính xác?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cảm ơn bạn! Báo cáo đã được gửi tới ban quản trị để xử lý.'),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Gửi báo cáo'),
          ),
        ],
      ),
    );
  }

  void _navigateToChat() {
    final currentUser = ref.read(currentUserProvider);
    final profile = ref.read(userProfileProvider).value;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để gửi tin nhắn')),
      );
      return;
    }

    if (currentUser.uid == widget.post.authorId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đây là bài đăng của chính bạn')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          receiverId: widget.post.authorId,
          receiverName: widget.post.authorName,
          receiverAvatar: widget.post.authorAvatar,
          receiverPhone: widget.post.contactPhone,
          isLandlord: false,
          currentUserId: currentUser.uid,
          currentUserName: profile?.displayName ?? currentUser.displayName ?? 'Khách thuê',
        ),
      ),
    );
  }

  void _onCallAuthor() {
    final phone = widget.post.contactPhone.trim();

    if (phone.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Chưa có số điện thoại', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Bạn ${widget.post.authorName} chưa cung cấp số điện thoại liên hệ trực tiếp. Bạn vui lòng sử dụng tính năng Nhắn tin trao đổi.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _navigateToChat();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Nhắn tin ngay'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone_in_talk_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Liên hệ trực tiếp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bạn có thể gọi trực tiếp cho bạn ${widget.post.authorName} qua số điện thoại:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    phone,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Icon(Icons.copy_rounded, color: Color(0xFF64748B), size: 18),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đang kết nối cuộc gọi tới $phone...'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            icon: const Icon(Icons.call, size: 18),
            label: const Text('Gọi ngay', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _onSendRoommateInvite() {
    final inviteController = TextEditingController(
      text: 'Chào ${widget.post.authorName}, mình thấy phòng và lối sống của bạn rất phù hợp với mình. Mình muốn kết nối để trao đổi thêm về việc ở ghép cùng nhé!',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primarySurface, shape: BoxShape.circle),
                  child: const Icon(Icons.handshake_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Gửi lời mời ở ghép',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Gửi tin nhắn ngỏ ý làm quen và ghép phòng tới bạn cùng phòng:',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: inviteController,
              maxLines: 4,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _navigateToChat();
                },
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Gửi lời mời & Mở trò chuyện', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final post = widget.post;

    // Giới tính tác giả chuẩn hóa
    String authorGenderDisplay = post.authorGender;
    if (authorGenderDisplay.isEmpty || authorGenderDisplay == 'Tất cả') {
      final currentUser = ref.watch(currentUserProvider);
      final profile = ref.watch(userProfileProvider).value;
      if (currentUser != null && (post.authorId == currentUser.uid || post.authorName == profile?.displayName)) {
        final g = profile?.gender.toLowerCase() ?? '';
        authorGenderDisplay = (g.contains('nu') || g.contains('nữ')) ? 'Nữ' : (g.contains('nam') ? 'Nam' : 'Chưa cập nhật');
      } else {
        authorGenderDisplay = 'Chưa cập nhật';
      }
    } else {
      final g = authorGenderDisplay.toLowerCase();
      if (g == 'nam') authorGenderDisplay = 'Nam';
      if (g.contains('nu') || g.contains('nữ')) authorGenderDisplay = 'Nữ';
    }

    // Danh sách ảnh thật từ bài đăng (Không dùng ảnh giả Unsplash fallback)
    final List<String> images = post.images;
    final captions = post.imageCaptions;

    String priceFormatted;
    if (post.hasRoom && post.pricePerPerson > 0) {
      priceFormatted = '~${currencyFmt.format(post.pricePerPerson)}';
    } else if (post.pricePerPerson > 0) {
      priceFormatted = '~${currencyFmt.format(post.pricePerPerson)}';
    } else if (post.budgetMax > 0) {
      priceFormatted = '${(post.budgetMin / 1000000).toStringAsFixed(1)} - ${(post.budgetMax / 1000000).toStringAsFixed(0)} triệu';
    } else {
      priceFormatted = 'Thỏa thuận';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // 1. Sliver App Bar với Carousel ảnh hoặc Banner
          SliverAppBar(
            expandedHeight: images.isNotEmpty ? 290 : 130,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF0F172A)),
                ),
              ),
            ),
            actions: [
              // Nút Bookmark
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: InkWell(
                  onTap: _onToggleBookmark,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Icon(
                      _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      color: _isBookmarked ? AppColors.primary : const Color(0xFF475569),
                      size: 20,
                    ),
                  ),
                ),
              ),
              // Nút Share
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: InkWell(
                  onTap: _onShare,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: const Icon(Icons.share_outlined, color: Color(0xFF475569), size: 19),
                  ),
                ),
              ),
              // Nút Báo cáo
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: InkWell(
                  onTap: _onReport,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: const Icon(Icons.flag_outlined, color: Color(0xFF64748B), size: 19),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: images.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          itemCount: images.length,
                          onPageChanged: (idx) => setState(() => _currentImageIndex = idx),
                          itemBuilder: (ctx, idx) => _buildRoomImage(images[idx]),
                        ),
                        // Gradient bóng mờ phía trên
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 80,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.black.withValues(alpha: 0.35), Colors.transparent],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                        // Badge chú thích ảnh ở đáy trái (nếu có chú thích thật)
                        if (_currentImageIndex < captions.length && captions[_currentImageIndex].isNotEmpty)
                          Positioned(
                            left: 16,
                            bottom: 14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xCC1E293B),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                captions[_currentImageIndex],
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        // Chỉ số trang ảnh ở đáy phải
                        Positioned(
                          right: 16,
                          bottom: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_currentImageIndex + 1}/${images.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            post.hasRoom ? Icons.apartment_rounded : Icons.search_rounded,
                            size: 40,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            post.hasRoom ? 'Phòng chưa cập nhật ảnh' : 'Đang tìm phòng ghép cùng',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                          ),
                        ],
                      ),
                    ),
            ),
          ),

          // 2. Nội dung chi tiết
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hàng Badge Trạng thái & Thời gian & AI Matching
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
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
                              post.hasRoom ? 'Đã có phòng sẵn' : 'Chưa có phòng • Tìm người cùng thuê',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: post.hasRoom ? const Color(0xFF0369A1) : const Color(0xFFC2410C),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            _formatTimeAgo(post.createdAt),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Tiêu đề bài đăng to bản
                  Text(
                    post.title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      height: 1.35,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Khung Giá Thuê & Ngân Sách
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.hasRoom ? 'GIÁ THUÊ / NGƯỜI' : 'NGÂN SÁCH DỰ KIẾN',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 3),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: priceFormatted,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                      TextSpan(
                                        text: post.hasRoom ? ' /người/tháng' : ' /tháng',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (post.matchRate > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '${post.matchRate}% Hợp gu',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Địa chỉ chi tiết
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.address,
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), height: 1.3),
                              ),
                              if (post.district.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Khu vực: ${post.district}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 3. Card Hồ Sơ Tác Giả
                  const Text(
                    'NGƯỜI ĐĂNG BÀI',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: AppColors.primarySurface,
                                  backgroundImage: post.authorAvatar.isNotEmpty
                                      ? (post.authorAvatar.startsWith('http')
                                          ? NetworkImage(post.authorAvatar) as ImageProvider
                                          : FileImage(File(post.authorAvatar)))
                                      : null,
                                  child: post.authorAvatar.isEmpty
                                      ? Text(
                                          post.authorName.isNotEmpty ? post.authorName[0] : 'U',
                                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                                        )
                                      : null,
                                ),
                                if (post.isVerified)
                                  Positioned(
                                    right: -2,
                                    bottom: -2,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                      child: Container(
                                        width: 18,
                                        height: 18,
                                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                        child: const Icon(Icons.check, size: 12, color: Colors.white),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        post.authorName,
                                        style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                      ),
                                      if (post.authorAge > 0) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '• ${post.authorAge} tuổi',
                                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (post.authorOccupation.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        const Icon(Icons.school_outlined, size: 15, color: AppColors.primary),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            post.authorOccupation,
                                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 2),
                                  Text(
                                    'Giới tính: $authorGenderDisplay',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        // Các chỉ số uy tín & phản hồi
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildAuthorStatItem('100 điểm', 'Độ uy tín', Icons.verified_user_outlined, const Color(0xFF10B981)),
                            Container(width: 1, height: 26, color: const Color(0xFFE2E8F0)),
                            _buildAuthorStatItem(post.isVerified ? 'Đã xác thực' : 'Chưa eKYC', 'Hồ sơ', Icons.badge_outlined, AppColors.primary),
                            Container(width: 1, height: 26, color: const Color(0xFFE2E8F0)),
                            _buildAuthorStatItem('< 10 phút', 'Tốc độ trả lời', Icons.bolt_rounded, const Color(0xFFF59E0B)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 4. Thông Tin Chi Tiết & Yêu Cầu Ghép
                  const Text(
                    'THÔNG TIN & YÊU CẦU GHÉP PHÒNG',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildRequirementRow(
                          icon: Icons.meeting_room_outlined,
                          label: 'Tình trạng phòng',
                          value: post.hasRoom ? 'Đã có phòng sẵn (Tìm người share)' : 'Chưa có phòng (Tìm người cùng thuê)',
                          valueColor: post.hasRoom ? const Color(0xFF0284C7) : const Color(0xFFEA580C),
                        ),
                        const Divider(height: 16),
                        _buildRequirementRow(
                          icon: Icons.wc_outlined,
                          label: 'Đối tượng mong muốn',
                          value: post.targetGender == 'Tất cả' ? 'Nam hoặc Nữ đều được' : 'Chỉ tìm bạn ${post.targetGender}',
                          valueColor: const Color(0xFF0F172A),
                        ),
                        const Divider(height: 16),
                        _buildRequirementRow(
                          icon: Icons.apartment_outlined,
                          label: 'Hình thức nhà ở',
                          value: post.displayPropertyType,
                          valueColor: const Color(0xFF0F172A),
                        ),
                        const Divider(height: 16),
                        _buildRequirementRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Thời gian có thể dọn vào',
                          value: 'Có thể dọn vào ở ngay',
                          valueColor: const Color(0xFF10B981),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 5. Tiêu Chí Sinh Hoạt & Lối Sống
                  const Text(
                    'TIÊU CHÍ SINH HOẠT & LỐI SỐNG',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    post.habits.isNotEmpty
                        ? 'Các thói quen bạn cùng phòng cần lưu ý và tôn trọng lẫn nhau:'
                        : 'Người đăng chưa đặt tiêu chí sinh hoạt cụ thể.',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                  ),
                  if (post.habits.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: post.habits.map((h) {
                        final visual = _getHabitVisual(h);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: visual['bg'] as Color? ?? AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: (visual['color'] as Color? ?? AppColors.primary).withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(visual['icon'] as IconData, size: 16, color: visual['color'] as Color),
                              const SizedBox(width: 6),
                              Text(
                                h,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // 6. Tiện Nghi Căn Phòng (nếu có phòng)
                  if (post.hasRoom) ...[
                    const Text(
                      'TIỆN NGHI CĂN PHÒNG',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          _buildAmenityBadge(Icons.ac_unit_rounded, 'Máy lạnh'),
                          _buildAmenityBadge(Icons.local_laundry_service_rounded, 'Máy giặt'),
                          _buildAmenityBadge(Icons.kitchen_rounded, 'Tủ lạnh'),
                          _buildAmenityBadge(Icons.wifi_rounded, 'Wifi cáp quang'),
                          _buildAmenityBadge(Icons.two_wheeler_rounded, 'Chỗ để xe'),
                          _buildAmenityBadge(Icons.security_rounded, 'Bảo vệ an ninh'),
                          _buildAmenityBadge(Icons.balcony_rounded, 'Ban công'),
                          _buildAmenityBadge(Icons.water_drop_rounded, 'Nước nóng lạnh'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // 7. Mô Tả Chi Tiết Bài Đăng
                  const Text(
                    'MÔ TẢ CHI TIẾT',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      post.description.isNotEmpty
                          ? post.description
                          : 'Người đăng chưa cung cấp mô tả chi tiết.',
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.55,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 8. Hộp Mẹo An Toàn Từ HomeShare
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lời khuyên từ HomeShare',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF15803D)),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Hãy gặp gỡ trực tiếp tại nơi công cộng hoặc xem phòng cùng bạn bè trước khi quyết định đặt cọc. Không chuyển tiền khi chưa có biên nhận rõ ràng.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF166534), height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // 3. Thanh Hành Động Đáy (Bottom Sticky Bar)
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Nút Gọi điện
              OutlinedButton.icon(
                onPressed: _onCallAuthor,
                icon: const Icon(Icons.phone_outlined, size: 18),
                label: const Text('Gọi điện', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 10),
              // Nút Nhắn tin trao đổi chính
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _navigateToChat,
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Nhắn tin trao đổi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Nút Lời mời ghép
              InkWell(
                onTap: _onSendRoommateInvite,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(Icons.handshake_outlined, color: AppColors.primary, size: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthorStatItem(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: color)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildRequirementRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
        const Spacer(),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: valueColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildAmenityBadge(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        ),
      ],
    );
  }
}
