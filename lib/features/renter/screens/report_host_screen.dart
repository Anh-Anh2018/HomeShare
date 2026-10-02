import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/room_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';

/// Màn hình Báo cáo chủ nhà & phòng trọ vi phạm tiêu chuẩn cộng đồng
class ReportHostScreen extends ConsumerStatefulWidget {
  final RoomModel room;

  const ReportHostScreen({super.key, required this.room});

  @override
  ConsumerState<ReportHostScreen> createState() => _ReportHostScreenState();
}

class _ReportHostScreenState extends ConsumerState<ReportHostScreen> {
  final List<String> _reportReasons = [
    'Thông tin phòng sai sự thật hoặc hình ảnh giả mạo',
    'Giá thuê / tiền cọc thực tế khác xa giá đăng trên ứng dụng',
    'Chủ nhà có dấu hiệu lừa đảo, yêu cầu chuyển cọc bất thường',
    'Phòng đã có người thuê nhưng không gỡ bài đăng',
    'Thái độ ứng xử thiếu văn minh, quấy rối hoặc đe dọa',
    'Nhà trọ không đảm bảo PCCC hoặc điều kiện sống tối thiểu',
    'Lý do khác',
  ];

  late String _selectedReason;
  final TextEditingController _detailController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _evidenceImage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedReason = _reportReasons.first;
  }

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _pickEvidence() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _evidenceImage = picked);
    }
  }

  Future<void> _submitReport() async {
    final detail = _detailController.text.trim();
    if (detail.isEmpty && _selectedReason == 'Lý do khác') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập mô tả chi tiết lý do báo cáo'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = ref.read(currentUserProvider);
      final profile = ref.read(userProfileProvider).value;

      final reportData = {
        'roomId': widget.room.id,
        'roomTitle': widget.room.title,
        'hostId': widget.room.hostId,
        'hostName': widget.room.hostName,
        'hostPhone': widget.room.hostPhone,
        'reporterId': user?.uid ?? 'guest',
        'reporterName': profile?.displayName ?? user?.displayName ?? 'Khách thuê',
        'reason': _selectedReason,
        'detail': detail,
        'hasEvidenceImage': _evidenceImage != null,
        'status': 'pending', // pending, reviewed, resolved
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('reports').add(reportData);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.shield_outlined, color: AppColors.primary, size: 26),
                SizedBox(width: 8),
                Text('Đã Tiếp Nhận Báo Cáo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: const Text(
              'Cảm ơn bạn đã phản ánh! Ban quản trị HomeShare sẽ nhanh chóng xác minh và xử lý nghiêm các hành vi vi phạm trong vòng 24 giờ để đảm bảo môi trường an toàn.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('Đã Hiểu'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Có lỗi xảy ra: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Báo Cáo Chủ Nhà / Phòng'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thẻ tóm tắt phòng bị báo cáo
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey.shade200,
                      child: widget.room.images.isNotEmpty
                          ? Image.network(widget.room.images.first, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.home))
                          : const Icon(Icons.home, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.room.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Chủ nhà: ${widget.room.hostName}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'LÝ DO BÁO CÁO VI PHẠM (*)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark),
            ),
            const SizedBox(height: 8),

            // Danh sách các lý do
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: _reportReasons.map((reason) {
                  return RadioListTile<String>(
                    value: reason,
                    groupValue: _selectedReason,
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedReason = val);
                    },
                    title: Text(
                      reason,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _selectedReason == reason ? FontWeight.bold : FontWeight.normal,
                        color: _selectedReason == reason ? AppColors.textDark : AppColors.textSecondary,
                      ),
                    ),
                    activeColor: AppColors.primary,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'MÔ TẢ CHI TIẾT NỘI DUNG VI PHẠM',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _detailController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Cung cấp thêm chi tiết cụ thể (thời gian, hành vi, tin nhắn...) để HomeShare xử lý nhanh nhất...',
                hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Đính kèm bằng chứng
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'HÌNH ẢNH BẰNG CHỨNG (TÙY CHỌN)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark),
                ),
                TextButton.icon(
                  onPressed: _pickEvidence,
                  icon: const Icon(Icons.add_photo_alternate, size: 16),
                  label: const Text('Thêm ảnh', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),

            if (_evidenceImage != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.image, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _evidenceImage!.name,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Xóa ảnh bằng chứng',
                      icon: const Icon(Icons.close, size: 18, color: Colors.red),
                      onPressed: () => setState(() => _evidenceImage = null),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        color: Colors.white,
        child: SafeArea(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isSubmitting ? null : _submitReport,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.report_problem_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Gửi Báo Cáo Vi Phạm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
