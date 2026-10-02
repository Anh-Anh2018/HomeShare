import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/vietnam_locations.dart';
import '../../../core/services/room_service.dart';
import '../../../data/models/room_model.dart';
import 'room_detail_screen.dart';
import '../../chat/screens/chat_detail_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';

class SearchFilterScreen extends ConsumerStatefulWidget {
  final String initialCategory;
  final bool initialAdvanced;

  const SearchFilterScreen({
    super.key,
    this.initialCategory = 'Tất cả',
    this.initialAdvanced = false,
  });

  @override
  ConsumerState<SearchFilterScreen> createState() => _SearchFilterScreenState();
}

class _SearchFilterScreenState extends ConsumerState<SearchFilterScreen> {
  final currencyFormatter = NumberFormat('#,###', 'vi_VN');

  // 1. Khu vực state 3 cấp đầy đủ: Tỉnh/TP -> Quận/Huyện -> Phường/Xã
  String _selectedCity = 'TP. Hồ Chí Minh';
  String _selectedDistrict = 'Tất cả';
  String _selectedWard = 'Tất cả';
  String _rentalType = 'all'; // 'all' (Tất cả), 'single' (Ở 1 mình), 'shared' (Ở ghép)

  // 2. Bộ lọc nâng cao state
  bool _isAdvancedExpanded = false;
  bool _hasSearched = false;

  // Giá thuê mặc định mở rộng tối đa (0 - 20.000.000đ) để không lọc mất dữ liệu phòng
  RangeValues _priceRange = const RangeValues(0, 20000000);
  final double _minPriceLimit = 0;
  final double _maxPriceLimit = 20000000;

  // Diện tích
  RangeValues _areaRange = const RangeValues(10, 200);
  final double _minAreaLimit = 10;
  final double _maxAreaLimit = 200;

  // Tiện ích & Yêu cầu - Mặc định RỖNG để luôn hiển thị các phòng hiện có
  final TextEditingController _customAmenityController = TextEditingController();
  final Set<String> _selectedAmenities = {};

  final List<String> _availableAmenities = [
    'Máy lạnh',
    'Có gác lửng',
    'Chỗ để xe miễn phí',
    'Giờ giấc tự do',
    'Gần trường ĐH / Bến xe',
    'Wifi tốc độ cao',
    'Tủ lạnh & Máy giặt',
    'Cho nuôi thú cưng',
    'Không chung chủ',
    'Ban công / Cửa sổ lớn',
  ];

  // Sắp xếp
  String _selectedSort = 'newest';

  List<String> get _districts {
    if (_selectedCity == 'Tất cả') return const ['Tất cả'];
    final list = VietnamLocations.getAdministrativeDistricts(_selectedCity);
    return ['Tất cả', ...list];
  }

  List<String> get _wards {
    if (_selectedCity == 'Tất cả' || _selectedDistrict == 'Tất cả') return const ['Tất cả'];
    final list = VietnamLocations.getWards(_selectedCity, _selectedDistrict);
    return ['Tất cả', ...list];
  }

  void _showCityPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LocationSearchBottomSheet(
        title: 'Chọn Tỉnh / Thành phố',
        searchHint: 'Tìm kiếm tỉnh hoặc thành phố...',
        items: const ['Tất cả', ...VietnamLocations.provinces],
        selectedItem: _selectedCity,
        allLabel: 'Tất cả Tỉnh / Thành phố',
        onSelected: (val) {
          setState(() {
            _selectedCity = val;
            _selectedDistrict = 'Tất cả';
            _selectedWard = 'Tất cả';
          });
        },
      ),
    );
  }

  void _showDistrictPicker() {
    final districts = _districts;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LocationSearchBottomSheet(
        title: _selectedCity == 'Tất cả'
            ? 'Chọn Quận / Huyện'
            : 'Chọn Quận / Huyện ($_selectedCity)',
        searchHint: 'Tìm quận, huyện, thị xã...',
        items: districts,
        selectedItem: _selectedDistrict,
        allLabel: 'Tất cả Quận / Huyện',
        onSelected: (val) {
          setState(() {
            _selectedDistrict = val;
            _selectedWard = 'Tất cả';
          });
        },
      ),
    );
  }

  void _showWardPicker() {
    if (_selectedDistrict == 'Tất cả') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn Quận / Huyện trước khi chọn Phường / Xã'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final wards = _wards;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LocationSearchBottomSheet(
        title: 'Chọn Phường / Xã ($_selectedDistrict)',
        searchHint: 'Tìm phường, xã, thị trấn...',
        items: wards,
        selectedItem: _selectedWard,
        allLabel: 'Tất cả Phường / Xã',
        onSelected: (val) {
          setState(() {
            _selectedWard = val;
          });
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _isAdvancedExpanded = widget.initialAdvanced;
    if (widget.initialCategory.isNotEmpty && widget.initialCategory != 'Tất cả') {
      if (widget.initialCategory == 'Tìm ở ghép') {
        _rentalType = 'shared';
      } else if (widget.initialCategory == 'Phòng trọ') {
        _rentalType = 'single';
      } else if (widget.initialCategory == 'Gần trường ĐH') {
        _selectedAmenities.add('Gần trường ĐH / Bến xe');
      } else {
        _rentalType = 'single';
      }
    }
  }

  @override
  void dispose() {
    _customAmenityController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _selectedCity = 'TP. Hồ Chí Minh';
      _selectedDistrict = 'Tất cả';
      _selectedWard = 'Tất cả';
      _rentalType = 'all';
      _priceRange = const RangeValues(0, 20000000);
      _areaRange = const RangeValues(10, 200);
      _selectedAmenities.clear();
      _selectedSort = 'newest';
      _hasSearched = false;
      _isAdvancedExpanded = false;
    });
  }

  void _executeSearch() {
    setState(() {
      _hasSearched = true;
      _isAdvancedExpanded = false;
    });
  }

  void _addCustomAmenity() {
    final text = _customAmenityController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        if (!_availableAmenities.contains(text)) {
          _availableAmenities.add(text);
        }
        _selectedAmenities.add(text);
        _customAmenityController.clear();
      });
    }
  }

  void _showCallHostDialog(RoomModel room) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Số điện thoại chủ nhà'),
        content: Text(
          'Liên hệ trực tiếp với chủ trọ ${room.hostName}:\n\n'
          '📞 ${room.hostPhone}',
          style: const TextStyle(fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _openChatWithHost(RoomModel room) {
    final currentUser = ref.read(currentUserProvider);
    final profile = ref.read(userProfileProvider).value;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để nhắn tin với chủ trọ')),
      );
      return;
    }

    if (currentUser.uid == room.hostId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đây là phòng do chính bạn quản lý')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          receiverId: room.hostId,
          receiverName: room.hostName,
          receiverAvatar: room.hostAvatar,
          receiverPhone: room.hostPhone,
          isLandlord: true,
          currentUserId: currentUser.uid,
          currentUserName: profile?.displayName ?? currentUser.displayName ?? 'Khách thuê',
          pinnedRoom: room,
        ),
      ),
    );
  }

  int get _selectedCriteriaCount {
    int count = 0;
    if (_priceRange.start > 0 || _priceRange.end < 20000000) count++;
    if (_areaRange.start > 10 || _areaRange.end < 200) count++;
    count += _selectedAmenities.length;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;

    // Xử lý bộ lọc địa giới hành chính (Ưu tiên Phường/Xã -> Quận/Huyện -> Tỉnh/TP)
    final filterDistrict = _selectedWard != 'Tất cả'
        ? _selectedWard
        : (_selectedDistrict != 'Tất cả' ? _selectedDistrict : 'Tất cả');

    // Filter Params for Stream: Áp dụng các tiêu chí lọc đã chọn
    final filterParams = RoomFilterParams(
      city: _selectedCity,
      district: filterDistrict,
      rentalType: _rentalType,
      minPrice: _priceRange.start > 0 ? _priceRange.start : null,
      maxPrice: _priceRange.end < 20000000 ? _priceRange.end : null,
      minArea: _areaRange.start > 10 ? _areaRange.start : null,
      maxArea: _areaRange.end < 200 ? _areaRange.end : null,
      amenities: _selectedAmenities.isNotEmpty ? _selectedAmenities.toList() : const [],
      sortBy: _selectedSort,
    );

    final roomsAsync = ref.watch(roomsStreamProvider(filterParams));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.textDark),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Quay lại',
              )
            : null,
        titleSpacing: Navigator.canPop(context) ? 0 : null,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.22),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.home_work_rounded,
                color: Colors.white,
                size: 20,
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
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Share',
                      style: TextStyle(
                        fontSize: 18,
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
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined, color: AppColors.textDark),
            tooltip: 'Thông báo',
            onPressed: () {},
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: Text(
                profile?.displayName.isNotEmpty == true ? profile!.displayName[0].toUpperCase() : 'U',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. CARD KHU VỰC
            _buildLocationCard(),
            const SizedBox(height: 14),

            // 2. PHẦN BỘ LỌC NÂNG CAO (KHI MỞ RỘNG)
            if (_isAdvancedExpanded) ...[
              _buildAdvancedFilterSection(),
              const SizedBox(height: 16),
            ] else ...[
              // Nút Tìm kiếm phòng chính
              ElevatedButton.icon(
                onPressed: _executeSearch,
                icon: const Icon(Icons.search, size: 20),
                label: const Text(
                  'Tìm kiếm phòng',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.circle, size: 6, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text(
                    'Hơn 12.400+ phòng trọ chính chủ đang sẵn sàng',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // 3. DANH SÁCH KẾT QUẢ TÌM KIẾM
            _buildResultsSection(roomsAsync),
          ],
        ),
      ),
    );
  }

  // WIDGET: Card Khu vực & Hình thức thuê
  Widget _buildLocationCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề | Khu vực
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Khu vực',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Tỉnh / Thành phố *
          const Text(
            'Tỉnh / Thành phố *',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: _showCityPicker,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _selectedCity == 'Tất cả' ? Icons.location_on_outlined : Icons.near_me_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedCity == 'Tất cả' ? 'Chọn Tỉnh/Thành phố' : _selectedCity,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: _selectedCity == 'Tất cả' ? FontWeight.normal : FontWeight.w500,
                        color: _selectedCity == 'Tất cả' ? AppColors.textMuted : AppColors.textDark,
                      ),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, color: AppColors.textDark),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Quận / Huyện *
          const Text(
            'Quận / Huyện *',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: _showDistrictPicker,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_city_outlined, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedDistrict == 'Tất cả' ? 'Chọn Quận / Huyện' : _selectedDistrict,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: _selectedDistrict == 'Tất cả' ? FontWeight.normal : FontWeight.w500,
                        color: _selectedDistrict == 'Tất cả' ? AppColors.textMuted : AppColors.textDark,
                      ),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, color: AppColors.textDark),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 3. Phường / Xã
          const Text(
            'Phường / Xã',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: _showWardPicker,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.map_outlined, size: 18, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedWard == 'Tất cả' ? 'Chọn Phường / Xã' : _selectedWard,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: _selectedWard == 'Tất cả' ? FontWeight.normal : FontWeight.w500,
                        color: _selectedWard == 'Tất cả' ? AppColors.textMuted : AppColors.textDark,
                      ),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, color: AppColors.textDark),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Hình thức thuê
          const Text(
            'Hình thức thuê',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildRentalTypeCard(
                  type: 'single',
                  label: 'Ở 1 mình',
                  icon: Icons.person_outline,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRentalTypeCard(
                  type: 'shared',
                  label: 'Ở ghép',
                  icon: Icons.group_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRentalTypeCard(
                  type: 'all',
                  label: 'Khác',
                  icon: Icons.apartment_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Nút + Nâng cao / + Thêm bộ lọc / Thu gọn bộ lọc nâng cao
          InkWell(
            onTap: () => setState(() => _isAdvancedExpanded = !_isAdvancedExpanded),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: _isAdvancedExpanded ? const Color(0xFFF3F4F6) : const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isAdvancedExpanded ? const Color(0xFFE5E7EB) : const Color(0xFFD6E2FF),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isAdvancedExpanded ? Icons.keyboard_arrow_up : Icons.add,
                    size: 18,
                    color: _isAdvancedExpanded ? AppColors.textMuted : const Color(0xFF1E5BB0),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isAdvancedExpanded
                        ? 'Thu gọn bộ lọc nâng cao'
                        : (_hasSearched ? 'Thêm bộ lọc' : 'Nâng cao'),
                    style: TextStyle(
                      color: _isAdvancedExpanded ? AppColors.textMuted : const Color(0xFF1E5BB0),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET: Thẻ lựa chọn Hình thức thuê
  Widget _buildRentalTypeCard({
    required String type,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _rentalType == type;

    return InkWell(
      onTap: () => setState(() => _rentalType = type),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE5E7EB),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppColors.primary : AppColors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 14,
              color: isSelected ? AppColors.primary : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  // WIDGET: Toàn bộ mục Bộ lọc nâng cao (Giá, Diện tích, Tiện ích)
  Widget _buildAdvancedFilterSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bộ lọc + Badge số tiêu chí
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune, size: 20, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Bộ lọc',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_selectedCriteriaCount tiêu chí',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 1. GIÁ THUÊ / THÁNG
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Giá thuê / tháng',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              Text(
                '${currencyFormatter.format(_priceRange.start)}đ - ${currencyFormatter.format(_priceRange.end)}đ',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text('Tối thiểu', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      const SizedBox(height: 2),
                      Text(
                        '${currencyFormatter.format(_priceRange.start)}đ',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text('Tối đa', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      const SizedBox(height: 2),
                      Text(
                        '${currencyFormatter.format(_priceRange.end)}đ',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          RangeSlider(
            values: _priceRange,
            min: _minPriceLimit,
            max: _maxPriceLimit,
            divisions: 40,
            activeColor: AppColors.primary,
            inactiveColor: const Color(0xFFE5E7EB),
            onChanged: (values) {
              setState(() => _priceRange = values);
            },
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0đ', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              Text('20.000.000đ', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 20),

          // 2. DIỆN TÍCH
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Diện tích',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              Text(
                '${_areaRange.start.toInt()} m² - ${_areaRange.end.toInt()} m²',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text('Từ', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      const SizedBox(height: 2),
                      Text(
                        '${_areaRange.start.toInt()} m²',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text('Đến', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      const SizedBox(height: 2),
                      Text(
                        '${_areaRange.end.toInt()} m²',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          RangeSlider(
            values: _areaRange,
            min: _minAreaLimit,
            max: _maxAreaLimit,
            divisions: 38,
            activeColor: AppColors.primary,
            inactiveColor: const Color(0xFFE5E7EB),
            onChanged: (values) {
              setState(() => _areaRange = values);
            },
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('10 m²', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              Text('200 m²', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 20),

          // 3. TIỆN ÍCH & YÊU CẦU
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.checklist, size: 18, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text(
                    'Tiện ích & Yêu cầu',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                ],
              ),
              Text(
                '${_selectedAmenities.length} đang chọn',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Ô thêm tiện ích riêng
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customAmenityController,
                  decoration: InputDecoration(
                    hintText: 'Thêm tiện ích, yêu cầu riêng...',
                    hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.add_circle_outline, size: 18, color: AppColors.textMuted),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onSubmitted: (_) => _addCustomAmenity(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addCustomAmenity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Thêm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Danh sách các tiện ích & yêu cầu
          Column(
            children: _availableAmenities.map((amenity) {
              final isSelected = _selectedAmenities.contains(amenity);

              void toggleAmenity() {
                setState(() {
                  if (isSelected) {
                    _selectedAmenities.remove(amenity);
                  } else {
                    _selectedAmenities.add(amenity);
                  }
                });
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : const Color(0xFFE5E7EB),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: InkWell(
                  onTap: toggleAmenity,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.check_circle : Icons.check_box_outline_blank,
                          size: 20,
                          color: isSelected ? AppColors.primary : AppColors.textMuted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            amenity,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? AppColors.primary : AppColors.textDark,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC8E6C9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Đã chọn',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.close, size: 12, color: AppColors.primary),
                              ],
                            ),
                          )
                        else
                          const Icon(Icons.add, size: 18, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Nút Thu gọn ˄
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _isAdvancedExpanded = false),
              icon: const Text('Thu gọn', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              label: const Icon(Icons.keyboard_arrow_up, size: 18, color: AppColors.textMuted),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFF3F4F6),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Hàng nút: Đặt lại & Tìm kiếm
          Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.refresh, size: 18, color: AppColors.textDark),
                  label: const Text('Đặt lại', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _executeSearch,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Tìm kiếm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // WIDGET: Danh sách kết quả tìm kiếm (128 phòng)
  Widget _buildResultsSection(AsyncValue<List<RoomModel>> roomsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tiêu đề Kết quả tìm kiếm + Sort
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                roomsAsync.when(
                  data: (rooms) => Text(
                    'Kết quả tìm kiếm (${rooms.length} phòng)',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  loading: () => const Text(
                    'Kết quả tìm kiếm...',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                  error: (err, stack) => const Text(
                    'Kết quả tìm kiếm',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                ),
              ],
            ),
            // Menu sắp xếp
            PopupMenuButton<String>(
              initialValue: _selectedSort,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Text(
                      _getSortLabel(_selectedSort),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                    ),
                    const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textMuted),
                  ],
                ),
              ),
              onSelected: (val) => setState(() => _selectedSort = val),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'newest', child: Text('Mới nhất')),
                const PopupMenuItem(value: 'price_asc', child: Text('Giá thấp đến cao')),
                const PopupMenuItem(value: 'price_desc', child: Text('Giá cao đến thấp')),
                const PopupMenuItem(value: 'rating', child: Text('Đánh giá cao nhất')),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Danh sách các thẻ phòng trọ
        roomsAsync.when(
          data: (rooms) {
            if (rooms.isEmpty) {
              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.search_off, size: 52, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          const Text(
                            'Chưa tìm thấy phòng khớp chính xác',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Hãy thử điều chỉnh bộ lọc hoặc bấm nút bên dưới để xem toàn bộ phòng trọ có sẵn.',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: _resetFilters,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Xem tất cả phòng có sẵn'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rooms.length,
              itemBuilder: (context, index) {
                final room = rooms[index];
                return _buildHorizontalRoomCard(room, index);
              },
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => Center(
            child: Text('Lỗi tải dữ liệu: $err'),
          ),
        ),
      ],
    );
  }

  String _getSortLabel(String sort) {
    switch (sort) {
      case 'price_asc':
        return 'Giá tăng dần';
      case 'price_desc':
        return 'Giá giảm dần';
      case 'rating':
        return 'Đánh giá';
      case 'newest':
      default:
        return 'Mới nhất';
    }
  }

  // WIDGET: Thẻ phòng trọ ngang chuẩn thiết kế Figma
  Widget _buildHorizontalRoomCard(RoomModel room, int index) {
    final priceStr = '${currencyFormatter.format(room.price)} đ/tháng';
    final isOwner = index % 2 == 0; // Thay đổi huy hiệu Chính chủ / Mới

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F2F5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RoomDetailScreen(room: room)),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ảnh phòng bên trái kèm huy hiệu Chính chủ / Mới
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 95,
                      height: 95,
                      child: room.images.isNotEmpty
                          ? Image.network(
                              room.images.first,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.apartment, color: Colors.grey),
                              ),
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.apartment, color: Colors.grey),
                            ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOwner ? const Color(0xFF00796B) : const Color(0xFF1976D2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isOwner ? 'Chính chủ' : 'Mới',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Thông tin bên phải
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tiêu đề phòng
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

                    // Giá thuê
                    Text(
                      priceStr,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Thông số diện tích & vị trí
                    Text(
                      '${room.area.toInt()}m² • ${room.roomType} • ${room.district}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Tiện ích & Nút gọi điện / nhắn tin
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Tags tiện ích
                        Expanded(
                          child: Wrap(
                            spacing: 4,
                            children: room.amenities.take(2).map((a) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  a,
                                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        // Action buttons: Phone & Chat
                        Row(
                          children: [
                            InkWell(
                              onTap: () => _showCallHostDialog(room),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE8F5E9),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.phone, size: 14, color: AppColors.primary),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => _openChatWithHost(room),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE3F2FD),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.chat_bubble_outline, size: 14, color: Color(0xFF1976D2)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationSearchBottomSheet extends StatefulWidget {
  final String title;
  final String searchHint;
  final List<String> items;
  final String selectedItem;
  final String allLabel;
  final ValueChanged<String> onSelected;

  const _LocationSearchBottomSheet({
    required this.title,
    required this.searchHint,
    required this.items,
    required this.selectedItem,
    required this.allLabel,
    required this.onSelected,
  });

  @override
  State<_LocationSearchBottomSheet> createState() => _LocationSearchBottomSheetState();
}

class _LocationSearchBottomSheetState extends State<_LocationSearchBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static String _removeDiacritics(String str) {
    var withDiacritics = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
    var withoutDiacritics = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyydAAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
    for (int i = 0; i < withDiacritics.length; i++) {
      str = str.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    return str;
  }

  @override
  Widget build(BuildContext context) {
    final cleanQuery = _removeDiacritics(_query.trim().toLowerCase());

    final filteredItems = widget.items.where((item) {
      if (cleanQuery.isEmpty) return true;
      final cleanItem = _removeDiacritics(item.toLowerCase());
      final cleanAllLabel = _removeDiacritics(widget.allLabel.toLowerCase());
      return cleanItem.contains(cleanQuery) || 
             (item == 'Tất cả' && cleanAllLabel.contains(cleanQuery));
    }).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            // Tiêu đề BottomSheet
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Đóng',
                  ),
                ],
              ),
            ),
            // Ô tìm kiếm nhanh
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: widget.searchHint,
                    hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                    icon: const Icon(Icons.search, size: 20, color: AppColors.primary),
                    border: InputBorder.none,
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: AppColors.textMuted),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) => setState(() => _query = val),
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            // Danh sách các địa điểm
            Expanded(
              child: filteredItems.isEmpty
                  ? const Center(
                      child: Text(
                        'Không tìm thấy khu vực phù hợp',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                      ),
                    )
                  : RepaintBoundary(
                      child: ListView.separated(
                        physics: const ClampingScrollPhysics(),
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: filteredItems.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, indent: 56, color: Color(0xFFF3F4F6)),
                        itemBuilder: (ctx, index) {
                          final item = filteredItems[index];
                          final isSelected = item == widget.selectedItem;
                          final isAll = item == 'Tất cả';

                          return ListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFE8F5E9) : const Color(0xFFF3F4F6),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isAll
                                    ? Icons.location_on_outlined
                                    : Icons.near_me_outlined,
                                size: 18,
                                color: isSelected ? AppColors.primary : AppColors.textMuted,
                              ),
                            ),
                            title: Text(
                              isAll ? widget.allLabel : item,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                color: isSelected ? AppColors.primary : AppColors.textDark,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                                : null,
                            onTap: () {
                              widget.onSelected(item);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
