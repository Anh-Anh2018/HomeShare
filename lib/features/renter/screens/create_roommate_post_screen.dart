import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/vietnam_locations.dart';
import '../../../data/models/roommate_post_model.dart';
import '../../../core/services/roommate_service.dart';
import '../../../core/services/image_storage_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import 'renter_main_screen.dart';

/// Màn hình Đăng Bài Tìm Ở Ghép chuẩn Figma 100%
/// - Nếu ĐÃ CÓ PHÒNG (Đã có nhà): Tiến trình 3 bước (1. Thông tin -> 2. Hình ảnh -> 3. Hoàn tất)
/// - Nếu CHƯA CÓ PHÒNG (Chưa có nhà): Tiến trình 2 bước (1. Thông tin -> 2. Hoàn tất, không cần ảnh)
class CreateRoommatePostScreen extends ConsumerStatefulWidget {
  const CreateRoommatePostScreen({super.key});

  @override
  ConsumerState<CreateRoommatePostScreen> createState() => _CreateRoommatePostScreenState();
}

class _CreateRoommatePostScreenState extends ConsumerState<CreateRoommatePostScreen> {
  final _formKey = GlobalKey<FormState>();

  // Current Step: 0 = Thông tin, 1 = Hình ảnh (nếu có phòng) hoặc Hoàn tất, 2 = Hoàn tất
  int _currentStep = 0;

  // Controllers thông tin người đăng (chuẩn thẻ Figma Minh Trang)
  final _authorNameController = TextEditingController();
  final _authorAgeController = TextEditingController();
  final _authorOccupationController = TextEditingController();
  String _authorGender = 'Nữ';

  // Controllers thông tin bài đăng
  final _addressController = TextEditingController();
  final _streetController = TextEditingController();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  final _phoneController = TextEditingController();

  // Trạng thái phòng (true: Đã có nhà / phòng, false: Chưa có nhà / phòng)
  bool _hasRoom = true;

  // Lựa chọn địa giới hành chính toàn quốc 34 Tỉnh/TP mới
  String _selectedProvince = 'TP. Hồ Chí Minh';
  String? _selectedDistrict;
  String? _selectedWard;

  String _selectedPropertyType = 'Căn hộ chung cư';
  String _targetGender = 'Nữ';
  final List<String> _selectedHabits = [];
  final TextEditingController _customHabitController = TextEditingController();

  // Danh sách hình ảnh nhà & chú thích ảnh
  final List<String> _selectedImages = [];
  final List<String> _selectedCaptions = [];

  final ImagePicker _imagePicker = ImagePicker();
  bool _isSubmitting = false;
  RoommatePostModel? _createdPost;

  final List<String> _propertyTypes = [
    'Nhà trọ / Phòng trọ / Căn hộ mini',
    'Căn hộ chung cư',
    'Nhà nguyên căn',
    'Ký túc xá / Sleepbox',
  ];

  final List<String> _commonHabits = [
    'Không hút thuốc',
    'Yên tĩnh sau 23h',
    'Sạch sẽ ngăn nắp',
    'Giờ giấc tự do 24/7',
    'Có xe máy riêng',
    'Nấu ăn tại phòng',
    'Thân thiện vui vẻ',
    'Thú cưng (Chó/Mèo)',
    'Dậy sớm (Trước 7h)',
  ];

  void _syncFromProfile(UserProfile? profile, {bool force = false}) {
    if (profile == null) return;
    if (force || _authorNameController.text.isEmpty || _authorNameController.text == 'Minh Trang') {
      if (profile.displayName.isNotEmpty) _authorNameController.text = profile.displayName;
    }
    if (force || _phoneController.text.isEmpty) {
      if (profile.phoneNumber.isNotEmpty) _phoneController.text = profile.phoneNumber;
    }
    if (force || _authorOccupationController.text.isEmpty || _authorOccupationController.text == 'SV Đại học Ngoại Thương CS2') {
      if (profile.occupation.isNotEmpty) _authorOccupationController.text = profile.occupation;
    }
    if (force || _authorAgeController.text.isEmpty || _authorAgeController.text == '21') {
      if (profile.birthDate != null) {
        _authorAgeController.text = (DateTime.now().year - profile.birthDate!.year).toString();
      }
    }
    final g = profile.gender.trim().toLowerCase();
    if (g == 'nam') _authorGender = 'Nam';
    if (g.contains('nu') || g.contains('nữ')) _authorGender = 'Nữ';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(userProfileProvider).value;
      if (profile != null) {
        _syncFromProfile(profile, force: true);
      } else {
        if (_authorNameController.text.isEmpty) _authorNameController.text = 'Minh Trang';
        if (_authorAgeController.text.isEmpty) _authorAgeController.text = '21';
        if (_authorOccupationController.text.isEmpty) _authorOccupationController.text = 'SV Đại học Ngoại Thương CS2';
      }
      if (_titleController.text.isEmpty) _titleController.text = 'Cần tìm 1 bạn nữ ở ghép căn hộ Sunview Town (Đã có phòng)';
      if (_priceController.text.isEmpty) _priceController.text = '1.800.000';
      if (_selectedHabits.isEmpty) {
        _selectedHabits.addAll(['Không hút thuốc', 'Yên tĩnh sau 23h', 'Sạch sẽ ngăn nắp', 'Thân thiện vui vẻ']);
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authorNameController.dispose();
    _authorAgeController.dispose();
    _authorOccupationController.dispose();
    _addressController.dispose();
    _streetController.dispose();
    _titleController.dispose();
    _priceController.dispose();
    _descController.dispose();
    _phoneController.dispose();
    _customHabitController.dispose();
    super.dispose();
  }

  void _resetForm() {
    setState(() {
      _currentStep = 0;
      _createdPost = null;
      _selectedImages.clear();
      _selectedCaptions.clear();
      _selectedHabits.clear();
      _selectedHabits.addAll(['Không hút thuốc', 'Yên tĩnh sau 23h', 'Sạch sẽ ngăn nắp', 'Thân thiện vui vẻ']);
      _streetController.clear();
      _addressController.clear();
      _selectedDistrict = null;
      _selectedWard = null;
    });
  }

  /// Tổng hợp chuỗi địa chỉ đầy đủ từ 3 cấp hành chính và số nhà
  void _composeAddress() {
    final parts = <String>[];
    final street = _streetController.text.trim();
    if (street.isNotEmpty) parts.add(street);
    if (_selectedWard != null && _selectedWard!.isNotEmpty) parts.add(_selectedWard!);
    if (_selectedDistrict != null && _selectedDistrict!.isNotEmpty) parts.add(_selectedDistrict!);
    if (_selectedProvince.isNotEmpty) parts.add(_selectedProvince);
    _addressController.text = parts.join(', ');
  }

  /// Mở BottomSheet tìm kiếm và chọn địa giới hành chính
  Future<String?> _showSearchablePicker({
    required BuildContext context,
    required String title,
    required List<String> items,
    String? selectedItem,
    bool allowCustom = false,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SearchablePickerSheet(
        title: title,
        items: items,
        selectedItem: selectedItem,
        allowCustom: allowCustom,
      ),
    );
  }

  /// Thêm tiêu chí sinh hoạt tùy chỉnh do người dùng nhập
  void _addCustomHabit() {
    final text = _customHabitController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      if (!_commonHabits.contains(text)) {
        _commonHabits.add(text);
      }
      if (!_selectedHabits.contains(text)) {
        _selectedHabits.add(text);
      }
      _customHabitController.clear();
    });
  }

  /// Chọn thêm ảnh từ thư viện
  Future<void> _pickImages() async {
    try {
      final pickedFiles = await _imagePicker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        setState(() {
          for (final f in pickedFiles) {
            _selectedImages.add(f.path);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể chọn ảnh: $e')),
        );
      }
    }
  }

  /// Xóa ảnh khỏi danh sách
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  /// Xử lý chuyển bước tiếp theo từ Bước 1
  void _onNextFromStep1() {
    _composeAddress();
    if (_selectedDistrict == null || _selectedDistrict!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn Quận / Huyện')),
      );
      return;
    }
    if (_selectedWard == null || _selectedWard!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn Phường / Xã')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    if (_hasRoom) {
      // Đã có phòng -> Chuyển sang Bước 2: Hình ảnh
      setState(() => _currentStep = 1);
    } else {
      // Chưa có phòng -> Không cần ảnh, gửi đăng bài luôn và chuyển thẳng sang Hoàn tất!
      _submitPost(hasRoom: false);
    }
  }

  /// Lưu bài đăng vào Firestore / Service
  Future<void> _submitPost({required bool hasRoom}) async {
    setState(() => _isSubmitting = true);

    try {
      final user = ref.read(currentUserProvider);
      final profile = ref.read(userProfileProvider).value;

      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vui lòng đăng nhập tài khoản để đăng tin ở ghép!'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        return;
      }

      final priceVal = double.tryParse(_priceController.text.replaceAll(RegExp(r'\D'), '')) ?? 1800000;
      final district = _selectedDistrict ?? _extractDistrict(_addressController.text);
      final authorName = _authorNameController.text.trim().isNotEmpty
          ? _authorNameController.text.trim()
          : (profile?.displayName.isNotEmpty == true
              ? profile!.displayName
              : (user.displayName?.isNotEmpty == true ? user.displayName! : 'Minh Trang'));
      final authorAge = int.tryParse(_authorAgeController.text.trim()) ??
          (profile?.birthDate != null ? (DateTime.now().year - profile!.birthDate!.year) : 21);
      final authorOccupation = _authorOccupationController.text.trim().isNotEmpty
          ? _authorOccupationController.text.trim()
          : (profile?.occupation.isNotEmpty == true ? profile!.occupation : 'SV Đại học Ngoại Thương CS2');
      final authorPhone = _phoneController.text.trim().isNotEmpty
          ? _phoneController.text.trim()
          : (profile?.phoneNumber.isNotEmpty == true ? profile!.phoneNumber : '0981234567');

      // Danh sách chú thích ảnh mặc định nếu chưa nhập
      final captions = <String>[];
      if (hasRoom && _selectedImages.isNotEmpty) {
        for (int i = 0; i < _selectedImages.length; i++) {
          if (i < _selectedCaptions.length && _selectedCaptions[i].isNotEmpty) {
            captions.add(_selectedCaptions[i]);
          } else {
            captions.add(i == 0 ? 'Phòng ngủ máy lạnh' : 'Bếp chung rộng');
          }
        }
      }

      // Tải hình ảnh lên Firebase Storage / Cloud để tất cả thiết bị khác luôn thấy ảnh
      final postId = 'rm_${DateTime.now().millisecondsSinceEpoch}';
      List<String> uploadedImages = [];
      if (hasRoom && _selectedImages.isNotEmpty) {
        uploadedImages = await ref.read(imageStorageServiceProvider).uploadRoommateImages(
          localPaths: _selectedImages,
          postId: postId,
        );
      }

      final post = RoommatePostModel(
        id: postId,
        authorId: user.uid,
        authorName: authorName,
        authorAge: authorAge,
        authorGender: _authorGender,
        authorOccupation: authorOccupation,
        authorAvatar: profile?.avatarUrl.isNotEmpty == true
            ? profile!.avatarUrl
            : (user.photoURL?.isNotEmpty == true
                ? user.photoURL!
                : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400'),
        title: _titleController.text.trim().isNotEmpty
            ? _titleController.text.trim()
            : 'Cần tìm 1 bạn nữ ở ghép căn hộ Sunview Town (Đã có phòng)',
        description: _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : 'Căn hộ thoáng mát, đầy đủ tiện nghi, tìm bạn ở ghép lịch sự, sạch sẽ.',
        postType: hasRoom ? 'timNguoiOGhep' : 'dangTimPhong',
        propertyType: _selectedPropertyType,
        pricePerPerson: priceVal,
        budgetMin: hasRoom ? priceVal : (priceVal * 0.8).roundToDouble(),
        budgetMax: hasRoom ? priceVal : (priceVal * 1.2).roundToDouble(),
        address: _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : 'Hiệp Bình Phước, TP. Thủ Đức (Gần cầu Bình Triệu)',
        district: district,
        targetGender: _targetGender,
        habits: _selectedHabits.isNotEmpty
            ? List.from(_selectedHabits)
            : ['Không hút thuốc', 'Yên tĩnh sau 23h', 'Sạch sẽ ngăn nắp', 'Thân thiện vui vẻ'],
        images: hasRoom ? uploadedImages : [],
        imageCaptions: captions,
        hasRoom: hasRoom,
        status: 'dangMo',
        isVerified: true,
        matchRate: 94,
        contactPhone: authorPhone,
        createdAt: DateTime.now(),
      );

      final saved = await ref.read(roommateServiceProvider).createPost(post);
      ref.read(roommatePostsRefreshTrigger.notifier).trigger();

      if (mounted) {
        setState(() {
          _createdPost = saved;
          // Đã có phòng: step 2 là Hoàn tất. Chưa có phòng: step 1 là Hoàn tất.
          _currentStep = hasRoom ? 2 : 1;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _extractDistrict(String addr) {
    if (_selectedDistrict != null && _selectedDistrict!.isNotEmpty) {
      return _selectedDistrict!;
    }
    final lower = addr.toLowerCase();
    if (lower.contains('thủ đức')) return 'TP. Thủ Đức';
    if (lower.contains('bình thạnh')) return 'Bình Thạnh';
    if (lower.contains('quận 1')) return 'Quận 1';
    if (lower.contains('quận 9')) return 'Quận 9';
    if (lower.contains('gò vấp')) return 'Gò Vấp';
    if (lower.contains('tân bình')) return 'Tân Bình';
    return 'TP. Thủ Đức';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<UserProfile?>>(userProfileProvider, (prev, next) {
      final p = next.value;
      if (p != null && mounted) {
        setState(() {
          _syncFromProfile(p, force: false);
        });
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildFigmaAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            // Stepper Thanh Tiến Trình (Tùy biến động 3 bước nếu có phòng, 2 bước nếu chưa có phòng)
            _buildStepperHeader(),

            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // Nội dung theo từng bước
            Expanded(
              child: _buildCurrentStepContent(),
            ),
          ],
        ),
      ),
    );
  }

  /// AppBar chuẩn Figma: Back button + Tiêu đề "đăng bài"
  PreferredSizeWidget _buildFigmaAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF1E293B)),
        onPressed: () {
          if (_currentStep > 0 && (_hasRoom && _currentStep < 2)) {
            setState(() => _currentStep--);
          } else {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          }
        },
      ),
      title: const Text(
        'đăng bài',
        style: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 16.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Stepper Header chuẩn Figma:
  /// - Đã có phòng: 1 Thông tin -> 2 Hình ảnh -> 3 Hoàn tất
  /// - Chưa có phòng: 1 Thông tin -> 2 Hoàn tất
  Widget _buildStepperHeader() {
    final stepLabels = _hasRoom
        ? ['Thông tin', 'Hình ảnh', 'Hoàn tất']
        : ['Thông tin', 'Hoàn tất'];

    final totalSteps = stepLabels.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(totalSteps * 2 - 1, (index) {
          if (index.isOdd) {
            // Đường kẻ nối
            final stepIdx = index ~/ 2;
            final isCompleted = _currentStep > stepIdx;
            return Expanded(
              child: Container(
                height: 2,
                color: isCompleted ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
              ),
            );
          }

          // Nút tròn số bước
          final stepIdx = index ~/ 2;
          final isCurrent = _currentStep == stepIdx;
          final isDone = _currentStep > stepIdx;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: (isCurrent || isDone) ? const Color(0xFF2563EB) : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (isCurrent || isDone) ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: isDone
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : Text(
                        '${stepIdx + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isCurrent ? Colors.white : const Color(0xFF64748B),
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                stepLabels[stepIdx],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                  color: isCurrent ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  /// Nội dung tương ứng với bước hiện tại
  Widget _buildCurrentStepContent() {
    if (_hasRoom) {
      switch (_currentStep) {
        case 0:
          return _buildStep1InformationForm();
        case 1:
          return _buildStep2Images();
        case 2:
        default:
          return _buildStepSuccess();
      }
    } else {
      switch (_currentStep) {
        case 0:
          return _buildStep1InformationForm();
        case 1:
        default:
          return _buildStepSuccess();
      }
    }
  }

  // ===========================================================================
  // BƯỚC 1: THÔNG TIN CƠ BẢN
  // ===========================================================================
  Widget _buildStep1InformationForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Thông tin người đăng bài
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.person_pin_rounded, size: 18, color: Color(0xFF2563EB)),
                          SizedBox(width: 6),
                          Text(
                            'Thông tin người đăng bài',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () {
                          final p = ref.read(userProfileProvider).value;
                          if (p != null) {
                            setState(() {
                              _syncFromProfile(p, force: true);
                            });
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã đồng bộ thông tin từ tài khoản của bạn ✓'),
                                backgroundColor: Color(0xFF2563EB),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.sync, size: 14, color: Color(0xFF2563EB)),
                        label: const Text('Lấy từ tài khoản', style: TextStyle(fontSize: 11.5, color: Color(0xFF2563EB))),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('Họ và tên người đăng *'),
                            TextFormField(
                              controller: _authorNameController,
                              decoration: _inputDecoration('Ví dụ: Minh Trang'),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Nhập họ tên' : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('Tuổi *'),
                            TextFormField(
                              controller: _authorAgeController,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration('Ví dụ: 21'),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Nhập tuổi' : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildFieldLabel('Trường học / Nghề nghiệp *'),
                  TextFormField(
                    controller: _authorOccupationController,
                    decoration: _inputDecoration('Ví dụ: SV Đại học Ngoại Thương CS2'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Nhập trường / nghề nghiệp' : null,
                  ),
                  const SizedBox(height: 10),
                  _buildFieldLabel('Giới tính của bạn (Người đăng bài) *'),
                  Row(
                    children: ['Nam', 'Nữ'].map((g) {
                      final isSel = _authorGender == g;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: ChoiceChip(
                          label: Text(g),
                          selected: isSel,
                          selectedColor: const Color(0xFF2563EB),
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : const Color(0xFF334155),
                            fontSize: 13,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          ),
                          onSelected: (_) => setState(() => _authorGender = g),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Thông tin phòng & bài đăng',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 14),

            // Tỉnh / Thành phố (Toàn quốc 34 Tỉnh/TP mới)
            _buildFieldLabel('Tỉnh / Thành phố (Toàn quốc) *'),
            InkWell(
              onTap: () async {
                final res = await _showSearchablePicker(
                  context: context,
                  title: 'Chọn Tỉnh / Thành phố',
                  items: VietnamLocations.provinces,
                  selectedItem: _selectedProvince,
                );
                if (res != null && res != _selectedProvince) {
                  setState(() {
                    _selectedProvince = res;
                    _selectedDistrict = null;
                    _selectedWard = null;
                    _composeAddress();
                  });
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_city_outlined, size: 18, color: Color(0xFF2563EB)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedProvince,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Quận / Huyện / Thị xã
            _buildFieldLabel('Quận / Huyện / Thị xã *'),
            InkWell(
              onTap: () async {
                final districts = VietnamLocations.getAdministrativeDistricts(_selectedProvince);
                final res = await _showSearchablePicker(
                  context: context,
                  title: 'Chọn Quận / Huyện ($_selectedProvince)',
                  items: districts,
                  selectedItem: _selectedDistrict,
                );
                if (res != null && res != _selectedDistrict) {
                  setState(() {
                    _selectedDistrict = res;
                    _selectedWard = null;
                    _composeAddress();
                  });
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedDistrict != null ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.map_outlined, size: 18, color: Color(0xFF2563EB)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedDistrict ?? 'Chọn Quận / Huyện...',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: _selectedDistrict != null ? FontWeight.w500 : FontWeight.normal,
                          color: _selectedDistrict != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Phường / Xã / Thị trấn
            _buildFieldLabel('Phường / Xã / Thị trấn *'),
            InkWell(
              onTap: () async {
                if (_selectedDistrict == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng chọn Quận / Huyện trước!')),
                  );
                  return;
                }
                final wards = VietnamLocations.getWards(_selectedProvince, _selectedDistrict!);
                final res = await _showSearchablePicker(
                  context: context,
                  title: 'Chọn Phường / Xã ($_selectedDistrict)',
                  items: wards,
                  selectedItem: _selectedWard,
                  allowCustom: true,
                );
                if (res != null) {
                  setState(() {
                    _selectedWard = res;
                    _composeAddress();
                  });
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedWard != null ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.holiday_village_outlined, size: 18, color: Color(0xFF2563EB)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedWard ?? (_selectedDistrict == null ? 'Vui lòng chọn Quận / Huyện trước' : 'Chọn Phường / Xã...'),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: _selectedWard != null ? FontWeight.w500 : FontWeight.normal,
                          color: _selectedWard != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Số nhà, tên đường *
            _buildFieldLabel('Số nhà, tên đường *'),
            TextFormField(
              controller: _streetController,
              decoration: _inputDecoration('Ví dụ: Số 123 Đường Số 8, KDC Nam Long...'),
              onChanged: (_) => _composeAddress(),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Vui lòng nhập số nhà, tên đường';
                }
                if (_selectedDistrict == null || _selectedDistrict!.isEmpty) {
                  return 'Vui lòng chọn Quận / Huyện';
                }
                if (_selectedWard == null || _selectedWard!.isEmpty) {
                  return 'Vui lòng chọn Phường / Xã';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Xem trước địa chỉ đầy đủ tự động
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, size: 18, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Địa chỉ bài đăng đầy đủ:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _addressController.text.trim().isNotEmpty
                              ? _addressController.text.trim()
                              : 'Chưa đủ thông tin (vui lòng chọn Tỉnh/TP, Quận/Huyện, Phường/Xã và số nhà)',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: _addressController.text.trim().isNotEmpty ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Loại hình *
            _buildFieldLabel('Loại hình *'),
            DropdownButtonFormField<String>(
              initialValue: _selectedPropertyType,
              decoration: _inputDecoration(''),
              items: _propertyTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13.5)))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedPropertyType = val);
              },
            ),
            const SizedBox(height: 14),

            // Tiêu đề bài đăng *
            _buildFieldLabel('Tiêu đề bài đăng *'),
            TextFormField(
              controller: _titleController,
              decoration: _inputDecoration(
                _hasRoom
                    ? 'Ví dụ: Cần tìm 1 bạn nữ ở ghép căn hộ Sunview Town (Đã có phòng)'
                    : 'Ví dụ: Muốn tìm 1 bạn nữ hòa đồng cùng tìm phòng Thủ Đức',
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập tiêu đề bài đăng' : null,
            ),
            const SizedBox(height: 14),

            // Giá thuê / Ngân sách dự kiến *
            _buildFieldLabel(_hasRoom ? 'Giá thuê mỗi người (VNĐ/tháng) *' : 'Ngân sách tìm phòng dự kiến (VNĐ/tháng) *'),
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('Ví dụ: 1.800.000'),
              validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập giá' : null,
            ),
            const SizedBox(height: 14),

            // Giới tính mong muốn (chỉ Nam / Nữ theo yêu cầu)
            _buildFieldLabel('Giới tính mong muốn *'),
            Row(
              children: ['Nam', 'Nữ'].map((g) {
                final isSel = _targetGender == g;
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: ChoiceChip(
                    label: Text(g),
                    selected: isSel,
                    selectedColor: const Color(0xFF2563EB),
                    labelStyle: TextStyle(
                      color: isSel ? Colors.white : const Color(0xFF334155),
                      fontSize: 13,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    ),
                    onSelected: (_) => setState(() => _targetGender = g),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Tiêu chí sinh hoạt & Thói quen (chọn hoặc nhập để thêm)
            _buildFieldLabel('Tiêu chí sinh hoạt & Thói quen (chọn hoặc nhập để thêm)'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _commonHabits.map((h) {
                final isSel = _selectedHabits.contains(h);
                return FilterChip(
                  label: Text(h),
                  selected: isSel,
                  selectedColor: const Color(0xFFEFF6FF),
                  checkmarkColor: const Color(0xFF2563EB),
                  labelStyle: TextStyle(
                    color: isSel ? const Color(0xFF2563EB) : const Color(0xFF475569),
                    fontSize: 11.5,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSel ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                  ),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedHabits.add(h);
                      } else {
                        _selectedHabits.remove(h);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 10),

            // Ô nhập tiêu chí mới
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: TextField(
                      controller: _customHabitController,
                      decoration: InputDecoration(
                        hintText: 'Nhập tiêu chí khác (ví dụ: Không nhậu nhẹt, WFH...)',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
                        ),
                      ),
                      onSubmitted: (_) => _addCustomHabit(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: _addCustomHabit,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Thêm', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Số điện thoại / Zalo liên hệ *
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFieldLabel('Số điện thoại liên hệ *'),
                if (ref.watch(userProfileProvider).value?.phoneNumber.isNotEmpty == true)
                  TextButton.icon(
                    onPressed: () {
                      final p = ref.read(userProfileProvider).value;
                      if (p != null) {
                        setState(() => _phoneController.text = p.phoneNumber);
                      }
                    },
                    icon: const Icon(Icons.person_pin_circle_outlined, size: 14, color: Color(0xFF2563EB)),
                    label: const Text('Lấy từ tài khoản', style: TextStyle(fontSize: 12, color: Color(0xFF2563EB))),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                  ),
              ],
            ),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: _inputDecoration('Số điện thoại Zalo để người tìm ghép liên hệ'),
              validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập số điện thoại liên hệ' : null,
            ),
            const SizedBox(height: 14),

            // Nội dung
            _buildFieldLabel('Nội dung'),
            TextFormField(
              controller: _descController,
              maxLines: 4,
              decoration: _inputDecoration('nội dung bài đăng'),
            ),
            const SizedBox(height: 16),

            // Trạng thái (Radio options: Đã có nhà vs Chưa có nhà)
            _buildFieldLabel('Trạng thái'),
            Row(
              children: [
                _buildStatusRadio(
                  label: 'Đã có nhà',
                  isSelected: _hasRoom,
                  onTap: () => setState(() => _hasRoom = true),
                ),
                const SizedBox(width: 24),
                _buildStatusRadio(
                  label: 'Chưa có nhà',
                  isSelected: !_hasRoom,
                  onTap: () => setState(() => _hasRoom = false),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Nút Tiếp theo
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _onNextFromStep1,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text(
                        'Tiếp theo',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
    );
  }

  Widget _buildStatusRadio({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                width: isSelected ? 5.5 : 1.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BƯỚC 2: HÌNH ẢNH NHÀ (CHỈ ÁP DỤNG KHI ĐÃ CÓ PHÒNG)
  // ===========================================================================
  Widget _buildStep2Images() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hình ảnh nhà',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 3),
          const Text(
            'Chọn ít nhất 1 ảnh để thu hút người thuê',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),

          // Khung to nét đứt chọn ảnh
          InkWell(
            onTap: _pickImages,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF93C5FD),
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF2563EB), size: 22),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'chọn ảnh hoặc kéo thả',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Tối thiểu 1 tấm, tối đa 12 tấm',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ),

          if (_selectedImages.isEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedImages.addAll([
                      'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=600',
                      'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?w=600',
                    ]);
                    _selectedCaptions.addAll([
                      'Phòng ngủ máy lạnh',
                      'Bếp chung rộng',
                    ]);
                  });
                },
                icon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF2563EB)),
                label: const Text(
                  'Dùng ảnh phòng đẹp (Phòng ngủ + Bếp)',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF93C5FD)),
                  backgroundColor: const Color(0xFFEFF6FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Lưới ảnh 3 cột
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.0,
            ),
            itemCount: _selectedImages.length + 1,
            itemBuilder: (context, index) {
              if (index == _selectedImages.length) {
                // Ô cuối: + Thêm ảnh
                return InkWell(
                  onTap: _pickImages,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF93C5FD), width: 1.2),
                      color: const Color(0xFFF8FAFC),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 24, color: Color(0xFF2563EB)),
                        SizedBox(height: 2),
                        Text(
                          'Thêm ảnh',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final imgPath = _selectedImages[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: imgPath.startsWith('http')
                        ? Image.network(imgPath, fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => Container(color: Colors.grey.shade200))
                        : Image.file(File(imgPath), fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => Container(color: Colors.grey.shade200)),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: () => _removeImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 28),

          // 2 Nút: Quay lại & Hoàn tất
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => setState(() => _currentStep = 0),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Quay lại', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            if (_selectedImages.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Vui lòng chọn ít nhất 1 hình ảnh phòng thật của bạn'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }
                            _submitPost(hasRoom: true);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Hoàn tất', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ===========================================================================
  // BƯỚC 3 / HOÀN TẤT: ĐĂNG BÀI THÀNH CÔNG
  // ===========================================================================
  Widget _buildStepSuccess() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),

          // Minh họa nhà có dấu tick xanh chuẩn Figma
          Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(
              color: Color(0xFFF0FDF4),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.home_outlined,
                  size: 52,
                  color: Color(0xFF60A5FA),
                ),
                Positioned(
                  right: 18,
                  bottom: 18,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFF16A34A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // Tiêu đề
          const Text(
            'đăng bài thành công!',
            style: TextStyle(
              fontSize: 18.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),

          // Mô tả
          const Text(
            'bài đăng của bạn đã được lưu và sẵn sàng để đăng tin cho thuê.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF64748B),
            ),
          ),

          const Spacer(),

          // Nút Xem bài đăng
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                // 1. Chuyển tab sang mục Ở ghép (Tab 3)
                ref.read(renterBottomNavIndexProvider.notifier).setIndex(3);
                // 2. Đóng màn hình nếu được mở qua push
                if (Navigator.canPop(context)) {
                  Navigator.pop(context, _createdPost);
                }
                // 3. Reset form
                _resetForm();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: const Text('Xem bài đăng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 12),

          // Nút Quay lại trang chủ
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () {
                // 1. Chuyển tab sang mục Khám phá (Tab 0)
                ref.read(renterBottomNavIndexProvider.notifier).setIndex(0);
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
                _resetForm();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFFBFDBFE)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: const Text('quay lại trang chủ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// BottomSheet tìm kiếm và chọn địa giới hành chính (Tỉnh/TP, Quận/Huyện, Phường/Xã)
class _SearchablePickerSheet extends StatefulWidget {
  final String title;
  final List<String> items;
  final String? selectedItem;
  final bool allowCustom;

  const _SearchablePickerSheet({
    required this.title,
    required this.items,
    this.selectedItem,
    this.allowCustom = false,
  });

  @override
  State<_SearchablePickerSheet> createState() => _SearchablePickerSheetState();
}

class _SearchablePickerSheetState extends State<_SearchablePickerSheet> {
  final _searchController = TextEditingController();
  late List<String> _filteredItems;

  @override
  void initState() {
    super.initState();
    _filteredItems = List.from(widget.items);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredItems = List.from(widget.items);
      } else {
        _filteredItems = widget.items.where((item) => item.toLowerCase().contains(q)).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: EdgeInsets.only(bottom: keyboardHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thanh kéo
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Tiêu đề và nút đóng
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Ô tìm kiếm
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm ${widget.title.toLowerCase().replaceAll('chọn ', '')}...',
                hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearch('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              onChanged: _onSearch,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          // Danh sách kết quả
          Expanded(
            child: _filteredItems.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            widget.allowCustom && _searchController.text.trim().isNotEmpty
                                ? 'Không tìm thấy trong danh mục'
                                : 'Không tìm thấy kết quả phù hợp',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
                          ),
                          if (widget.allowCustom && _searchController.text.trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.pop(context, _searchController.text.trim()),
                              icon: const Icon(Icons.add, size: 16),
                              label: Text('Dùng "${_searchController.text.trim()}"'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    itemCount: _filteredItems.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF8FAFC)),
                    itemBuilder: (ctx, idx) {
                      final item = _filteredItems[idx];
                      final isSelected = item == widget.selectedItem;
                      return ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        tileColor: isSelected ? const Color(0xFFEFF6FF) : null,
                        title: Text(
                          item,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, size: 18, color: Color(0xFF2563EB))
                            : null,
                        onTap: () => Navigator.pop(context, item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

