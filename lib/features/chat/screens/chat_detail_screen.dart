import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/models/room_model.dart';
import '../../../core/services/chat_service.dart';
import '../../renter/screens/room_detail_screen.dart';

/// Màn hình Chi tiết Tin nhắn & Trao đổi (Feature #10 theo chuẩn SRS CDLTDD & Tc_CHAT_01 -> 50)
class ChatDetailScreen extends ConsumerStatefulWidget {
  final String receiverId;
  final String receiverName;
  final String receiverAvatar;
  final String receiverPhone;
  final bool isLandlord;
  final String currentUserId;
  final String currentUserName;
  final RoomModel? pinnedRoom;

  const ChatDetailScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    this.receiverAvatar = '',
    this.receiverPhone = '0903888999',
    this.isLandlord = true,
    required this.currentUserId,
    required this.currentUserName,
    this.pinnedRoom,
  });

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  bool _isBlocked = false;
  bool _showPinnedRoom = true;
  bool _showScrollToBottom = false;
  bool _isRecordingAudio = false;
  final Set<String> _deletedForMeIds = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final show = _scrollController.offset > 150;
    if (show != _showScrollToBottom) {
      setState(() => _showScrollToBottom = show);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // Gửi tin nhắn văn bản (Tc_CHAT_21 -> 25)
  Future<void> _sendMessage([String? overrideText]) async {
    final text = (overrideText ?? _messageController.text).trim();
    if (text.isEmpty) {
      // Chặn gửi tin nhắn rỗng hoặc chỉ có khoảng trắng (Tc_CHAT_24)
      return;
    }

    if (_isBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể gửi tin nhắn do đối phương đã bị chặn.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    // Kiểm tra bộ lọc từ ngữ vi phạm tiêu chuẩn cộng đồng (Tc_CHAT_49)
    if (ChatService.checkProfanity(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tin nhắn vi phạm tiêu chuẩn cộng đồng về an toàn thông tin.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (overrideText == null) {
      _messageController.clear();
    }

    final message = ChatMessageModel(
      id: '',
      senderId: widget.currentUserId,
      senderName: widget.currentUserName,
      receiverId: widget.receiverId,
      text: text,
      timestamp: DateTime.now(),
      status: 'sent',
    );

    try {
      final roomMeta = widget.pinnedRoom != null
          ? {
              'roomCode': '#LT-${widget.pinnedRoom!.id.hashCode.abs() % 1000}',
              'roomTitle': widget.pinnedRoom!.title,
              'roomPrice': widget.pinnedRoom!.price,
              'roomImage': widget.pinnedRoom!.images.isNotEmpty ? widget.pinnedRoom!.images.first : '',
            }
          : null;

      await ref.read(chatServiceProvider).sendMessage(message, roomMetadata: roomMeta);
      _scrollToBottom();
    } catch (e) {
      if (overrideText == null) {
        _messageController.text = text;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi gửi tin: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  // Gửi thẻ đa phương tiện (Lịch hẹn, Lời mời ở ghép, Vị trí, Ảnh)
  Future<void> _sendRichMessage({
    required String text,
    required String messageType,
    String attachmentUrl = '',
    Map<String, dynamic> extraData = const {},
  }) async {
    final message = ChatMessageModel(
      id: '',
      senderId: widget.currentUserId,
      senderName: widget.currentUserName,
      receiverId: widget.receiverId,
      text: text,
      messageType: messageType,
      attachmentUrl: attachmentUrl,
      extraData: extraData,
      timestamp: DateTime.now(),
      status: 'sent',
    );

    try {
      await ref.read(chatServiceProvider).sendMessage(message);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  // Gọi điện thoại trực tiếp (Tc_CHAT_04 & SRS 2.10)
  void _makeAudioCall() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.primaryContainer,
              child: Icon(Icons.phone, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Gọi cho ${widget.receiverName}', style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Số điện thoại liên hệ trực tiếp:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.receiverPhone,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20, color: AppColors.textMuted),
                    tooltip: 'Sao chép số',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.receiverPhone));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã sao chép số điện thoại')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hệ thống hỗ trợ gọi trực tiếp qua mạng di động của thiết bị.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.call, size: 18),
            label: const Text('Bắt Đầu Gọi'),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đang kết nối cuộc gọi tới ${widget.receiverPhone}...'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Gọi video trực tuyến (Tc_CHAT_05 & SRS 2.10)
  void _makeVideoCall() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.primaryContainer,
              child: Icon(Icons.videocam, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Cuộc gọi Video HomeShare', style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey.shade700,
                    child: Text(
                      widget.receiverName.isNotEmpty ? widget.receiverName[0] : 'U',
                      style: const TextStyle(fontSize: 24, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Đang kết nối tới ${widget.receiverName}...',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tính năng xem phòng và trò chuyện mặt đối mặt trực tuyến.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Hủy'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            icon: const Icon(Icons.videocam, size: 18),
            label: const Text('Kết Nối'),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đang khởi tạo kênh video bảo mật...')),
              );
            },
          ),
        ],
      ),
    );
  }

  // Menu tùy chọn ba chấm (Tc_CHAT_06 -> 08)
  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline, color: AppColors.primary),
              title: const Text('Xem hồ sơ đối tác'),
              onTap: () {
                Navigator.pop(ctx);
                _showPartnerProfileDialog();
              },
            ),
            ListTile(
              leading: Icon(_isBlocked ? Icons.lock_open : Icons.block, color: AppColors.danger),
              title: Text(_isBlocked ? 'Bỏ chặn người dùng này' : 'Chặn người dùng này (Block)'),
              subtitle: Text(
                _isBlocked ? 'Cho phép nhận và gửi tin nhắn trở lại' : 'Người này sẽ không thể gửi tin nhắn cho bạn',
                style: const TextStyle(fontSize: 11),
              ),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _isBlocked = !_isBlocked);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_isBlocked ? 'Đã chặn người dùng' : 'Đã bỏ chặn người dùng'),
                    backgroundColor: _isBlocked ? AppColors.danger : AppColors.primary,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_problem_outlined, color: Colors.orange),
              title: const Text('Báo cáo vi phạm (Report)'),
              subtitle: const Text('Báo cáo hành vi lừa đảo, quấy rối hoặc thông tin giả', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                _showReportDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.textMuted),
              title: const Text('Xóa lịch sử cuộc trò chuyện'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã làm trống lịch sử trò chuyện cục bộ')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPartnerProfileDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primaryContainer,
              child: Text(
                widget.receiverName.isNotEmpty ? widget.receiverName[0] : 'U',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(widget.receiverName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      if (widget.isLandlord) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: AppColors.primary, size: 16),
                      ],
                    ],
                  ),
                  Text(
                    widget.isLandlord ? 'Chủ nhà trọ đã xác thực' : 'Người thuê / Tìm ở ghép',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phone_outlined, size: 20),
              title: Text(widget.receiverPhone, style: const TextStyle(fontSize: 14)),
              subtitle: const Text('Số điện thoại liên hệ', style: TextStyle(fontSize: 11)),
            ),
            const ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.shield_outlined, size: 20, color: AppColors.primary),
              title: Text('Điểm uy tín: 100/100', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              subtitle: Text('Đã xác thực CCCD & Căn cước công dân', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
        ],
      ),
    );
  }

  void _showReportDialog() {
    final reasons = ['Lừa đảo tiền đặt cọc', 'Thông tin phòng không đúng sự thật', 'Quấy rối / Từ ngữ thô tục', 'Lý do khác'];
    String selected = reasons[0];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: const Text('Báo cáo vi phạm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons
                .map(
                  (r) => ListTile(
                    dense: true,
                    leading: Icon(
                      selected == r ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: selected == r ? AppColors.primary : AppColors.textMuted,
                      size: 20,
                    ),
                    title: Text(r, style: const TextStyle(fontSize: 13)),
                    onTap: () => setDState(() => selected = r),
                  ),
                )
                .toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã gửi báo cáo vi phạm tới Ban Quản Trị HomeShare')),
                );
              },
              child: const Text('Gửi Báo Cáo'),
            ),
          ],
        ),
      ),
    );
  }

  // Menu đính kèm phương tiện (+) (Tc_CHAT_29)
  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const Text('Đính kèm phương tiện & hành động', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAttachOption(
                    icon: Icons.photo_library_outlined,
                    label: 'Gửi ảnh (1-5)',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(ctx);
                      _sendSampleImage();
                    },
                  ),
                  _buildAttachOption(
                    icon: Icons.location_on_outlined,
                    label: 'Vị trí hiện tại',
                    color: Colors.red,
                    onTap: () {
                      Navigator.pop(ctx);
                      _sendLocationMessage();
                    },
                  ),
                  _buildAttachOption(
                    icon: Icons.calendar_today_outlined,
                    label: 'Hẹn xem phòng',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(ctx);
                      _showAppointmentDialog();
                    },
                  ),
                  _buildAttachOption(
                    icon: Icons.group_add_outlined,
                    label: 'Mời ở ghép',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(ctx);
                      _showRoommateInviteDialog();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _sendSampleImage() {
    _sendRichMessage(
      text: '[Hình ảnh đính kèm]',
      messageType: 'image',
      attachmentUrl: 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=600',
    );
  }

  void _sendLocationMessage() {
    _sendRichMessage(
      text: 'Vị trí phòng: Số 8, Đường Linh Trung, Phường Linh Trung, TP. Thủ Đức',
      messageType: 'location',
      extraData: {
        'address': 'Số 8, Đường Linh Trung, TP. Thủ Đức',
        'latitude': 10.8654,
        'longitude': 106.7725,
      },
    );
  }

  void _showAppointmentDialog() {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 16, minute: 0);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.calendar_month, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Hẹn lịch xem phòng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Phòng: ${widget.pinnedRoom?.title ?? 'Phòng trọ cao cấp Linh Trung'}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 12),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.date_range, color: AppColors.primary),
                title: Text('Ngày: ${DateFormat('dd/MM/yyyy').format(selectedDate)}'),
                trailing: const Text('Đổi', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null) {
                    setDState(() => selectedDate = picked);
                  }
                },
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time, color: AppColors.primary),
                title: Text('Giờ hẹn: ${selectedTime.format(context)}'),
                trailing: const Text('Đổi', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (picked != null) {
                    setDState(() => selectedTime = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                final formattedDate = DateFormat('dd/MM/yyyy').format(selectedDate);
                final formattedTime = selectedTime.format(context);

                _sendRichMessage(
                  text: 'Lịch hẹn xem phòng vào lúc $formattedTime ngày $formattedDate',
                  messageType: 'appointment',
                  extraData: {
                    'date': formattedDate,
                    'time': formattedTime,
                    'status': 'pending',
                    'roomTitle': widget.pinnedRoom?.title ?? 'Phòng trọ cao cấp',
                    'address': widget.pinnedRoom?.address ?? 'Linh Trung, TP. Thủ Đức',
                  },
                );
              },
              child: const Text('Gửi Thẻ Hẹn Lịch'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRoommateInviteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.handshake_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Mời vào ở ghép', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gửi lời mời ghép phòng tới: ${widget.receiverName}'),
            const SizedBox(height: 8),
            Text(
              'Phòng: ${widget.pinnedRoom?.title ?? 'Căn hộ mini 2 phòng ngủ'}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              'Chi phí dự kiến chia sẻ: 1.800.000 đ/tháng/người',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _sendRichMessage(
                text: 'Lời mời cùng ở ghép phòng tại HomeShare',
                messageType: 'roommate_invitation',
                extraData: {
                  'status': 'pending',
                  'roomTitle': widget.pinnedRoom?.title ?? 'Căn hộ mini 2 phòng ngủ',
                  'pricePerPerson': 1800000,
                  'senderName': widget.currentUserName,
                },
              );
            },
            child: const Text('Gửi Lời Mời'),
          ),
        ],
      ),
    );
  }

  // Ghi âm tin nhắn thoại (Tc_CHAT_34 -> 37)
  void _toggleAudioRecording() {
    setState(() => _isRecordingAudio = !_isRecordingAudio);
    if (!_isRecordingAudio) {
      _sendRichMessage(
        text: 'Tin nhắn thoại (0:05)',
        messageType: 'audio',
        extraData: {
          'duration': '0:05',
          'isPlaying': false,
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi tin nhắn âm thanh thoại')),
      );
    }
  }

  // Sao chép tin nhắn (Tc_CHAT_40)
  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã sao chép vào bộ nhớ tạm')),
    );
  }

  // Xóa tin nhắn phía tôi (Tc_CHAT_41)
  void _deleteForMe(String messageId) {
    setState(() {
      _deletedForMeIds.add(messageId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã xóa tin nhắn ở phía bạn')),
    );
  }

  // Menu thao tác khi nhấn giữ tin nhắn (Long Press Context Menu - TC 40, 41)
  void _showMessageContextMenu(ChatMessageModel msg, bool isMe) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_outlined, color: AppColors.primary),
              title: const Text('Sao chép nội dung tin nhắn'),
              onTap: () {
                Navigator.pop(ctx);
                _copyMessage(msg.text);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text('Xóa ở phía tôi (Delete for Me)'),
              onTap: () {
                Navigator.pop(ctx);
                _deleteForMe(msg.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesStreamProvider(ChatParams(
      userA: widget.currentUserId,
      userB: widget.receiverId,
    )));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        leading: Semantics(
          label: 'Quay lại danh sách tin nhắn',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Quay lại',
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: InkWell(
          onTap: _showPartnerProfileDialog,
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primaryContainer,
                    child: Text(
                      widget.receiverName.isNotEmpty ? widget.receiverName[0] : 'U',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.receiverName,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.isLandlord) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: AppColors.primary, size: 15),
                        ],
                      ],
                    ),
                    const Row(
                      children: [
                        CircleAvatar(radius: 3, backgroundColor: Colors.green),
                        SizedBox(width: 4),
                        Text('Đang trực tuyến', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Nút Gọi thoại (Tc_CHAT_04)
          Semantics(
            label: 'Gọi điện thoại cho ${widget.receiverName}',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.phone_outlined, color: AppColors.primary),
              tooltip: 'Gọi thoại',
              onPressed: _makeAudioCall,
            ),
          ),
          // Nút Gọi video (Tc_CHAT_05)
          Semantics(
            label: 'Gọi video với ${widget.receiverName}',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.videocam_outlined, color: AppColors.primary),
              tooltip: 'Gọi video',
              onPressed: _makeVideoCall,
            ),
          ),
          // Nút tùy chọn ba chấm (Tc_CHAT_06)
          Semantics(
            label: 'Tùy chọn cuộc trò chuyện',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Tùy chọn',
              onPressed: _showOptionsMenu,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 1. Thẻ bảo vệ giao dịch an toàn (SRS 2.10)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: const Color(0xFFFEF3C7),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 16, color: Color(0xFFB45309)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bảo vệ an toàn: Tuyệt đối không cọc tiền trước khi đến xem phòng trực tiếp.',
                        style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Thẻ phòng trọ ghim trên đầu khung chat (Tc_CHAT_09 -> 11 & SRS 2.10)
              if (_showPinnedRoom && widget.pinnedRoom != null)
                _buildPinnedRoomCard(widget.pinnedRoom!),

              // 3. Danh sách tin nhắn Realtime
              Expanded(
                child: messagesAsync.when(
                  data: (rawMessages) {
                    final messages = rawMessages.where((m) => !_deletedForMeIds.contains(m.id)).toList();

                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'Bắt đầu cuộc trò chuyện với ${widget.receiverName}',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Nhấn vào các câu hỏi nhanh bên dưới để gửi ngay',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe = msg.senderId == widget.currentUserId;
                        return _buildMessageItem(msg, isMe);
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Lỗi tải tin nhắn: $err')),
                ),
              ),

              // 4. Thanh câu hỏi gợi ý nhanh (Quick Action Chips - Tc_CHAT_12 -> 14 & SRS 2.10)
              _buildQuickChipsBar(),

              // 5. Thanh nhập tin nhắn và đính kèm
              _buildInputArea(),
            ],
          ),

          // Nút nổi cuộn xuống đáy khi cuộn ngược lên (Tc_CHAT_43)
          if (_showScrollToBottom)
            Positioned(
              right: 16,
              bottom: 120,
              child: FloatingActionButton.small(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                tooltip: 'Cuộn xuống tin mới nhất',
                onPressed: _scrollToBottom,
                child: const Icon(Icons.arrow_downward, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  // Widget Thẻ phòng trọ ghim trên đầu khung chat (Tc_CHAT_09 -> 11)
  Widget _buildPinnedRoomCard(RoomModel room) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Ảnh thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 58,
              height: 58,
              color: AppColors.primaryContainer,
              child: room.images.isNotEmpty
                  ? Image.network(
                      room.images.first,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.home, color: AppColors.primary),
                    )
                  : const Icon(Icons.home, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 10),
          // Thông tin phòng
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RoomDetailScreen(room: room)),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#LT-${room.id.hashCode.abs() % 1000} • ${room.title}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(room.price)}/tháng',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Text(
                    room.address,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Nút Xem phòng & Đóng
          Column(
            children: [
              InkWell(
                onTap: () => setState(() => _showPinnedRoom = false),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.close, size: 16, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 4),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => RoomDetailScreen(room: room)),
                  );
                },
                child: const Text('Xem phòng', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget Thanh câu hỏi gợi ý nhanh (Tc_CHAT_12 -> 14)
  Widget _buildQuickChipsBar() {
    final chips = [
      'Phòng này còn trống không?',
      'Có chỗ để xe không?',
      'Giờ giấc như thế nào?',
      'Hẹn lịch xem phòng',
      '+ Mời vào ở ghép',
    ];

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chip = chips[index];
          final isInviteChip = chip == '+ Mời vào ở ghép';

          return ActionChip(
            backgroundColor: isInviteChip ? AppColors.primaryContainer : Colors.white,
            side: BorderSide(color: isInviteChip ? AppColors.primary : AppColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            label: Text(
              chip,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isInviteChip ? FontWeight.bold : FontWeight.w500,
                color: isInviteChip ? AppColors.primary : AppColors.textDark,
              ),
            ),
            onPressed: () {
              if (isInviteChip) {
                _showRoommateInviteDialog();
              } else if (chip == 'Hẹn lịch xem phòng') {
                _showAppointmentDialog();
              } else {
                _sendMessage(chip);
              }
            },
          );
        },
      ),
    );
  }

  // Widget Thanh nhập tin nhắn và đính kèm
  Widget _buildInputArea() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, -2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            // Nút Thêm đính kèm (+) (Tc_CHAT_29)
            IconButton(
              tooltip: 'Đính kèm',
              icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 26),
              onPressed: _showAttachmentMenu,
            ),

            // Ô nhập liệu văn bản (Tc_CHAT_21, 22)
            Expanded(
              child: Semantics(
                label: 'Nội dung tin nhắn',
                textField: true,
                child: TextField(
                  controller: _messageController,
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: _isRecordingAudio ? 'Đang ghi âm (0:05)...' : 'Nhập tin nhắn...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: _isRecordingAudio ? AppColors.danger : AppColors.textMuted,
                      fontWeight: _isRecordingAudio ? FontWeight.bold : FontWeight.normal,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Nút Micro ghi âm (Tc_CHAT_34 -> 36)
            IconButton(
              tooltip: 'Ghi âm tin nhắn',
              icon: Icon(
                _isRecordingAudio ? Icons.stop_circle : Icons.mic_none,
                color: _isRecordingAudio ? AppColors.danger : AppColors.textMuted,
                size: 24,
              ),
              onPressed: _toggleAudioRecording,
            ),

            // Nút Gửi (Tc_CHAT_23 -> 25)
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                tooltip: 'Gửi tin nhắn',
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: () => _sendMessage(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Builder cho từng loại bong bóng tin nhắn (Văn bản, Lịch hẹn, Lời mời ở ghép, Vị trí, Ảnh, Audio)
  Widget _buildMessageItem(ChatMessageModel msg, bool isMe) {
    return GestureDetector(
      onLongPress: () => _showMessageContextMenu(msg, isMe),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              _buildMessageBubbleBody(msg, isMe),
              const SizedBox(height: 2),
              // Nhãn thời gian và trạng thái (Tc_CHAT_26)
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('HH:mm').format(msg.timestamp),
                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      msg.isRead ? Icons.done_all : Icons.check,
                      size: 13,
                      color: msg.isRead ? Colors.blue : AppColors.textMuted,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubbleBody(ChatMessageModel msg, bool isMe) {
    // 1. Thẻ Lịch hẹn xem phòng (Appointment Card - SRS 2.10 line 1090)
    if (msg.messageType == 'appointment') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary, width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.event_available, color: AppColors.primary, size: 20),
                SizedBox(width: 6),
                Text('LỊCH HẸN XEM PHÒNG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
              ],
            ),
            const Divider(height: 16),
            Text(msg.text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    msg.extraData['address'] ?? 'Số 8, Linh Trung, TP. Thủ Đức',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lịch hẹn xem phòng đã được lưu vào hệ thống')),
                );
              },
              child: const Text('Xem Chi Tiết Lịch Hẹn', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    // 2. Thẻ Lời mời vào ở ghép (Tc_CHAT_14 -> 20 & Figma Node: 3346:3226)
    if (msg.messageType == 'roommate_invitation') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.shade300, width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.handshake, color: Colors.orange, size: 20),
                SizedBox(width: 6),
                Text('LỜI MỜI VÀO Ở GHÉP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange)),
              ],
            ),
            const Divider(height: 16),
            Text(
              msg.extraData['roomTitle'] ?? 'Căn hộ mini 2 phòng ngủ',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text('Chi phí: 1.800.000 đ/tháng/người', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            if (!isMe)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        minimumSize: const Size.fromHeight(32),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã từ chối lời mời ở ghép')),
                        );
                      },
                      child: const Text('Từ chối', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(32),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã chấp nhận lời mời ở ghép thành công!')),
                        );
                      },
                      child: const Text('Chấp nhận', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                ],
              )
            else
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  minimumSize: const Size.fromHeight(32),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã thu hồi lời mời ở ghép')),
                  );
                },
                child: const Text('Thu hồi lời mời', style: TextStyle(fontSize: 11)),
              ),
          ],
        ),
      );
    }

    // 3. Thẻ Vị trí bản đồ thu nhỏ (Tc_CHAT_38, 39)
    if (msg.messageType == 'location') {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_pin, color: Colors.red, size: 36),
                    Text('Bản đồ Google Maps', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(msg.text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.directions, size: 16),
              label: const Text('Mở Chỉ Đường', style: TextStyle(fontSize: 12)),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đang mở ứng dụng Bản đồ dẫn đường...')),
                );
              },
            ),
          ],
        ),
      );
    }

    // 4. Thẻ Tin nhắn Âm thanh Thoại (Tc_CHAT_36, 37)
    if (msg.messageType == 'audio') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: isMe ? Colors.white24 : AppColors.primaryContainer,
              child: Icon(
                Icons.play_arrow,
                color: isMe ? Colors.white : AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '||| | |||| | |||',
              style: TextStyle(
                color: isMe ? Colors.white : AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              msg.extraData['duration'] ?? '0:05',
              style: TextStyle(
                color: isMe ? Colors.white70 : AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    // 5. Thẻ Hình ảnh đính kèm (Tc_CHAT_30 -> 33)
    if (msg.messageType == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () {
            // Xem ảnh phóng to toàn màn hình (Tc_CHAT_33)
            showDialog(
              context: context,
              builder: (ctx) => Dialog(
                backgroundColor: Colors.transparent,
                child: InteractiveViewer(
                  child: Image.network(
                    msg.attachmentUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.black54,
                      height: 200,
                      child: const Center(child: Icon(Icons.broken_image, color: Colors.white, size: 48)),
                    ),
                  ),
                ),
              ),
            );
          },
          child: Container(
            constraints: const BoxConstraints(maxHeight: 180, maxWidth: 220),
            color: Colors.grey.shade200,
            child: Image.network(
              msg.attachmentUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
              ),
            ),
          ),
        ),
      );
    }

    // 6. Bong bóng tin nhắn văn bản thông thường (Tc_CHAT_25 & SRS 2.10 link detect)
    final containsPhone = RegExp(r'\b(0\d{9,10})\b').hasMatch(msg.text);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMe ? 16 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            msg.text,
            style: TextStyle(
              color: isMe ? Colors.white : AppColors.textDark,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          if (containsPhone) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: _makeAudioCall,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isMe ? Colors.white24 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.phone, size: 13, color: isMe ? Colors.white : Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      'Bấm để gọi nhanh',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isMe ? Colors.white : Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
