import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/vietnam_locations.dart';
import '../../../core/services/image_storage_service.dart';
import '../../../core/services/roommate_service.dart';
import '../../../data/models/roommate_post_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import 'renter_main_screen.dart';

/// Màn hình Đăng Tin Tìm Ở Ghép chuẩn Figma 100%
/// Thiết kế Stepper 3 bước rõ ràng, sạch sẽ, không lỗi layout:
/// Bước 1: Thông tin người đăng (Hồ sơ cá nhân)
/// Bước 2: Thông tin phòng & Ngân sách (Địa điểm, Giá thuê, Tình trạng)
/// Bước 3: Lối sống, Thói quen & Hình ảnh phòng
class CreateRoommatePostScreen extends ConsumerStatefulWidget {
  const CreateRoommatePostScreen({super.key});

  @override
  ConsumerState<CreateRoommatePostScreen> createState() => _CreateRoommatePostScreenState();
}

class _CreateRoommatePostScreenState extends ConsumerState<CreateRoommatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  // 1. Thông tin người đăng
  final _authorNameController = TextEditingController();
  final _authorAgeController = TextEditingController();
  final _authorOccupationController = TextEditingController();
  final _phoneController = TextEditingController();
  String _authorGender = 'Nữ';

  // 2. Thông tin bài đăng & phòng
  bool _hasRoom = true; // true: Đã có phòng, false: Chưa có phòng
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _addressController = TextEditingController();
  String _selectedProvince = 'TP. Hồ Chí Minh';
  String _selectedDistrict = 'TP. Thủ Đức';
  String _selectedWard = 'Linh Trung';
  String _selectedPropertyType = 'Căn hộ chung cư';
  String _targetGender = 'Nữ';

  // 3. Lối sống & Thói quen
  final List<String> _selectedHabits = [];
  final TextEditingController _customHabitController = TextEditingController();
  final List<String> _selectedImages = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _isSubmitting = false;

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

  final List<String> _propertyTypes = [
    'Nhà trọ / Phòng trọ',
    'Căn hộ chung cư',
    'Nhà nguyên căn',
    'Ký túc xá / Sleepbox',
  ];

  @override
  void initState() {
    super.initState();
    // Tự động tải thông tin thực tế từ tài khoản người dùng đăng nhập, không hardcode dữ liệu giả
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initFromUserProfile();
    });
  }

  void _initFromUserProfile() {
    final user = ref.read(currentUserProvider);
    final profile = ref.read(userProfileProvider).value;

    if (profile != null) {
      if (profile.displayName.isNotEmpty) {
        _authorNameController.text = profile.displayName;
      }
      if (profile.phoneNumber.isNotEmpty) {
        _phoneController.text = profile.phoneNumber;
      }
      if (profile.occupation.isNotEmpty) {
        _authorOccupationController.text = profile.occupation;
      }
      if (profile.birthDate != null) {
        final age = DateTime.now().year - profile.birthDate!.year;
        if (age > 0) _authorAgeController.text = age.toString();
      }
      if (profile.gender.isNotEmpty) {
        final g = profile.gender.toLowerCase();
        if (g == 'nam' || g == 'male') {
          _authorGender = 'Nam';
        } else if (g == 'nu' || g == 'nữ' || g == 'female') {
          _authorGender = 'Nữ';
        } else {
          _authorGender = 'Khác';
        }
      }
      if (profile.hobbies.isNotEmpty) {
        for (final h in profile.hobbies) {
          if (!_selectedHabits.contains(h)) _selectedHabits.add(h);
        }
      }
      if (mounted) setState(() {});
    } else if (user != null) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        _authorNameController.text = user.displayName!;
      }
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        _phoneController.text = user.phoneNumber!;
      }
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _authorNameController.dispose();
    _authorAgeController.dispose();
    _authorOccupationController.dispose();
    _phoneController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _addressController.dispose();
    _customHabitController.dispose();
    super.dispose();
  }

  void _syncFromProfile() {
    final profile = ref.read(userProfileProvider).value;
    if (profile == null) return;

    setState(() {
      if (profile.displayName.isNotEmpty) _authorNameController.text = profile.displayName;
      if (profile.phoneNumber.isNotEmpty) _phoneController.text = profile.phoneNumber;
      if (profile.occupation.isNotEmpty) _authorOccupationController.text = profile.occupation;
      if (profile.birthDate != null) {
        _authorAgeController.text = (DateTime.now().year - profile.birthDate!.year).toString();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã đồng bộ thông tin từ tài khoản của bạn ✓'),
        backgroundColor: Color(0xFF2563EB),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        setState(() {
          _selectedImages.add(picked.path);
        });
      }
    } catch (e) {
      debugPrint('Lỗi chọn ảnh: $e');
    }
  }

  void _addCustomHabit() {
    final text = _customHabitController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        if (!_selectedHabits.contains(text)) {
          _selectedHabits.add(text);
        }
        _customHabitController.clear();
      });
    }
  }

  Future<void> _submitPost() async {
    if (_isSubmitting) return;

    final user = ref.read(currentUserProvider);
    final profile = ref.read(userProfileProvider).value;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập trước khi đăng bài tìm ở ghép!'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tiêu đề bài đăng!'), backgroundColor: AppColors.danger),
      );
      return;
    }

    final rawPrice = _priceController.text.trim().replaceAll('.', '').replaceAll(',', '');
    final price = double.tryParse(rawPrice) ?? 0.0;
    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền thuê / ngân sách hợp lệ!'), backgroundColor: AppColors.danger),
      );
      return;
    }

    final specificAddress = _addressController.text.trim();
    if (specificAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập địa chỉ cụ thể!'), backgroundColor: AppColors.danger),
      );
      return;
    }

    final authorId = user.uid;
    final authorName = _authorNameController.text.trim().isNotEmpty
        ? _authorNameController.text.trim()
        : (profile?.displayName ?? user.displayName ?? 'Người dùng HomeShare');
    final authorAge = int.tryParse(_authorAgeController.text.trim()) ??
        (profile?.birthDate != null ? (DateTime.now().year - profile!.birthDate!.year) : 20);
    final authorOcc = _authorOccupationController.text.trim().isNotEmpty
        ? _authorOccupationController.text.trim()
        : (profile?.occupation.isNotEmpty == true ? profile!.occupation : 'Sinh viên / Người đi làm');

    setState(() => _isSubmitting = true);

    try {
      final postId = 'post_${DateTime.now().millisecondsSinceEpoch}';
      // Tải ảnh lên Firebase Storage nếu có với cơ chế fallback an toàn
      final uploadedUrls = await ref.read(imageStorageServiceProvider).uploadRoommateImages(
        localPaths: _selectedImages,
        postId: postId,
      );

      final fullAddress = '$specificAddress, $_selectedWard, $_selectedDistrict, $_selectedProvince';

      final post = RoommatePostModel(
        id: postId,
        authorId: authorId,
        authorName: authorName,
        authorAge: authorAge,
        authorGender: _authorGender,
        authorOccupation: authorOcc,
        authorAvatar: profile?.avatarUrl ?? user.photoURL ?? '',
        title: title,
        description: _descController.text.trim(),
        postType: _hasRoom ? 'timNguoiOGhep' : 'dangTimPhong',
        propertyType: _selectedPropertyType,
        pricePerPerson: price,
        budgetMin: price > 500000 ? price - 500000 : price,
        budgetMax: price + 500000,
        address: fullAddress,
        district: _selectedDistrict,
        targetGender: _targetGender,
        habits: _selectedHabits.isNotEmpty ? _selectedHabits : ['Sạch sẽ', 'Hòa đồng'],
        images: uploadedUrls,
        imageCaptions: uploadedUrls.map((_) => 'Ảnh phòng').toList(),
        isVerified: profile?.isCccdVerified ?? false,
        matchRate: 0,
        hasRoom: _hasRoom,
        contactPhone: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : (profile?.phoneNumber ?? ''),
        createdAt: DateTime.now(),
      );

      await ref.read(roommateServiceProvider).createPost(post);

      if (mounted) {
        setState(() => _isSubmitting = false);
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi đăng tin: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
            SizedBox(width: 8),
            Text('Đăng tin thành công!'),
          ],
        ),
        content: const Text(
          'Bài đăng tìm bạn ở ghép của bạn đã được xuất bản và hiển thị ngay trên Cộng đồng HomeShare.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); // Đóng dialog
              // Chuyển tab sang "Tìm ở ghép"
              ref.read(renterBottomNavIndexProvider.notifier).setIndex(3);
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Xem trên cộng đồng', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Đăng tin tìm ở ghép',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          if (_currentStep == 0)
            TextButton.icon(
              onPressed: _syncFromProfile,
              icon: const Icon(Icons.sync, size: 16, color: Color(0xFF2563EB)),
              label: const Text('Đồng bộ', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Step Indicator Bar
          _buildStepIndicator(),

          // Main Step Content
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const BouncingScrollPhysics(),
                child: _buildCurrentStepContent(),
              ),
            ),
          ),

          // Bottom Action Bar
          _buildBottomActionBar(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Hồ sơ', 'Phòng & Giá', 'Lối sống & Ảnh'];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: List.generate(steps.length, (idx) {
          final isPassed = idx < _currentStep;
          final isCurrent = idx == _currentStep;
          final color = isPassed || isCurrent ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1);

          return Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: color,
                  child: Text(
                    '${idx + 1}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  steps[idx],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                    color: isCurrent ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                  ),
                ),
                if (idx < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: isPassed ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Profile();
      case 1:
        return _buildStep2RoomAndPrice();
      case 2:
      default:
        return _buildStep3LifestyleAndImages();
    }
  }

  // BƯỚC 1: Hồ sơ bản thân
  Widget _buildStep1Profile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          title: 'Thông tin cá nhân người đăng',
          subtitle: 'Giúp người tìm phòng hiểu rõ hơn về bạn cùng phòng tiềm năng',
          icon: Icons.person_outline,
          children: [
            _buildTextField(label: 'Họ và tên *', controller: _authorNameController),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'Tuổi *',
                    controller: _authorAgeController,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Giới tính *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _authorGender,
                        items: ['Nam', 'Nữ', 'Khác'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                        onChanged: (val) => setState(() => _authorGender = val ?? 'Nữ'),
                        decoration: _inputDecoration(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Nghề nghiệp / Trường học *',
              controller: _authorOccupationController,
              hint: 'Ví dụ: SV Đại học Bách Khoa / Lập trình viên',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Số điện thoại / Zalo liên hệ *',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ],
    );
  }

  // BƯỚC 2: Thông tin bài đăng & phòng
  Widget _buildStep2RoomAndPrice() {
    final provinces = VietnamLocations.provinces;
    final districts = VietnamLocations.getAdministrativeDistricts(_selectedProvince);
    final wards = VietnamLocations.getWards(_selectedProvince, _selectedDistrict);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          title: 'Tình trạng phòng hiện tại',
          subtitle: 'Bạn đã có phòng sẵn để share hay đang tìm bạn đi thuê cùng?',
          icon: Icons.home_work_outlined,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildSelectCard(
                    title: 'Đã có phòng',
                    subtitle: 'Tìm người dọn vào ở cùng',
                    isSelected: _hasRoom,
                    onTap: () => setState(() => _hasRoom = true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSelectCard(
                    title: 'Chưa có phòng',
                    subtitle: 'Tìm bạn cùng đi thuê',
                    isSelected: !_hasRoom,
                    onTap: () => setState(() => _hasRoom = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Tiêu đề bài đăng *',
              controller: _titleController,
              hint: 'Ví dụ: Tìm bạn nữ ở ghép căn hộ 2PN',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: _hasRoom ? 'Chi phí thuê / người (VNĐ / tháng) *' : 'Ngân sách mong muốn / người *',
              controller: _priceController,
              keyboardType: TextInputType.number,
              hint: 'Ví dụ: 1800000',
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tỉnh / Thành phố *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  key: ValueKey('province_$_selectedProvince'),
                  initialValue: provinces.contains(_selectedProvince) ? _selectedProvince : provinces.first,
                  items: provinces.map((p) => DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedProvince = val;
                        final newDistricts = VietnamLocations.getAdministrativeDistricts(_selectedProvince);
                        _selectedDistrict = newDistricts.isNotEmpty ? newDistricts.first : '';
                        final newWards = VietnamLocations.getWards(_selectedProvince, _selectedDistrict);
                        _selectedWard = newWards.isNotEmpty ? newWards.first : '';
                      });
                    }
                  },
                  decoration: _inputDecoration(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Quận / Huyện *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        key: ValueKey('district_${_selectedProvince}_$_selectedDistrict'),
                        initialValue: districts.contains(_selectedDistrict) ? _selectedDistrict : (districts.isNotEmpty ? districts.first : null),
                        items: districts.map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedDistrict = val ?? districts.first;
                            final newWards = VietnamLocations.getWards(_selectedProvince, _selectedDistrict);
                            _selectedWard = newWards.isNotEmpty ? newWards.first : 'Linh Trung';
                          });
                        },
                        decoration: _inputDecoration(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Phường / Xã', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        key: ValueKey('ward_${_selectedDistrict}_$_selectedWard'),
                        initialValue: wards.contains(_selectedWard) ? _selectedWard : (wards.isNotEmpty ? wards.first : 'Linh Trung'),
                        items: wards.map((w) => DropdownMenuItem(value: w, child: Text(w, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) => setState(() => _selectedWard = val ?? 'Linh Trung'),
                        decoration: _inputDecoration(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Loại hình nhà ở *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedPropertyType,
                        items: _propertyTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) => setState(() => _selectedPropertyType = val ?? _propertyTypes.first),
                        decoration: _inputDecoration(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Giới tính tìm kiếm *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _targetGender,
                        items: ['Nữ', 'Nam', 'Tất cả'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                        onChanged: (val) => setState(() => _targetGender = val ?? 'Nữ'),
                        decoration: _inputDecoration(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Địa chỉ cụ thể *',
              controller: _addressController,
              hint: 'Ví dụ: Số 10 đường Số 8, P. Linh Trung',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Mô tả chi tiết phòng & yêu cầu *',
              controller: _descController,
              maxLines: 3,
              hint: 'Mô tả không gian, tiện ích có sẵn, giờ giấc, nội quy phòng...',
            ),
          ],
        ),
      ],
    );
  }

  // BƯỚC 3: Lối sống & Ảnh phòng
  Widget _buildStep3LifestyleAndImages() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          title: 'Thói quen sinh hoạt & Lối sống',
          subtitle: 'Chọn các tiêu chí giúp AI kết nối bạn cùng phòng tương thích',
          icon: Icons.interests_outlined,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _commonHabits.map((habit) {
                final isSelected = _selectedHabits.contains(habit);
                return FilterChip(
                  label: Text(habit),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedHabits.add(habit);
                      } else {
                        _selectedHabits.remove(habit);
                      }
                    });
                  },
                  selectedColor: const Color(0xFFDBEAFE),
                  checkmarkColor: const Color(0xFF2563EB),
                  backgroundColor: const Color(0xFFF1F5F9),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: isSelected ? const Color(0xFF1E40AF) : const Color(0xFF334155),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  side: BorderSide(color: isSelected ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0)),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customHabitController,
                    decoration: _inputDecoration(hint: 'Thêm thói quen khác...'),
                    onSubmitted: (_) => _addCustomHabit(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addCustomHabit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Thêm'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildSectionCard(
          title: 'Hình ảnh phòng (nếu có)',
          subtitle: 'Bài đăng có hình ảnh thực tế nhận được nhiều liên hệ hơn 300%',
          icon: Icons.photo_library_outlined,
          children: [
            if (_selectedImages.isNotEmpty)
              SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (ctx, idx) {
                    return Stack(
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            image: DecorationImage(
                              image: FileImage(File(_selectedImages[idx])),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 12,
                          child: InkWell(
                            onTap: () => setState(() => _selectedImages.removeAt(idx)),
                            child: const CircleAvatar(
                              radius: 11,
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Chụp ảnh'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_outlined, size: 18),
                    label: const Text('Từ thư viện'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // Action buttons
  Widget _buildBottomActionBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep--),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Quay lại', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                if (_currentStep < 2) {
                  setState(() => _currentStep++);
                } else {
                  _submitPost();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      _currentStep < 2 ? 'Tiếp tục' : 'Đăng bài ngay',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSelectCard({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: _inputDecoration(hint: hint),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
    );
  }
}
