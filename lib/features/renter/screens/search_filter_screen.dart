import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/vietnam_locations.dart';
import '../../../core/services/room_service.dart';
import '../../../data/models/room_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../chat/screens/chat_detail_screen.dart';
import 'room_detail_screen.dart';

/// Màn hình Tìm kiếm & Bộ lọc chuẩn 100% Figma HomeShare
/// Hỗ trợ 3 trạng thái rõ ràng, không giật lag, không lỗi layout:
/// 1. Tìm kiếm cơ bản (Card Khu vực + Nút Tìm kiếm phòng)
/// 2. Tìm kiếm nâng cao (Dropdown bộ lọc giá, diện tích, tiện ích chuẩn #006948)
/// 3. Hiển thị kết quả tìm kiếm (Thanh lọc thu gọn + Danh sách thẻ phòng nằm ngang)
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
  final ScrollController _scrollController = ScrollController();

  // Bảng màu chuẩn Figma Emerald Green
  static const Color _emerald = Color(0xFF006948);
  static const Color _emeraldLight = Color(0xFFE8F5E9);
  static const Color _lavenderBg = Color(0xFFEEF2FF);
  static const Color _lavenderBorder = Color(0xFFC7D2FE);
  static const Color _lavenderText = Color(0xFF2563EB);

  // 1. Khu vực state
  String _selectedCity = 'TP. Hồ Chí Minh';
  String _selectedDistrict = 'Tất cả';
  String _selectedWard = 'Tất cả';
  String _rentalType = 'single'; // 'single' (Ở 1 mình), 'shared' (Ở ghép), 'all' (Cả hai)

  // 2. Trạng thái giao diện Figma
  bool _isAdvancedExpanded = false;
  bool _hasSearched = false;

  // 3. Bộ lọc nâng cao: Giá thuê (2.000.000đ - 5.000.000đ)
  RangeValues _priceRange = const RangeValues(2000000, 5000000);
  final double _minPriceLimit = 0;
  final double _maxPriceLimit = 20000000;

  // 4. Bộ lọc nâng cao: Diện tích (20m² - 60m²)
  RangeValues _areaRange = const RangeValues(20, 60);
  final double _minAreaLimit = 10;
  final double _maxAreaLimit = 200;

  // 5. Tiện ích & Yêu cầu - 5 tiêu chí được chọn sẵn chuẩn Figma
  final TextEditingController _customAmenityController = TextEditingController();
  final Set<String> _selectedAmenities = {
    'Máy lạnh',
    'Có gác lửng',
    'Chỗ để xe miễn phí',
    'Giờ giấc tự do',
    'Gần trường ĐH / Bến xe',
  };

  final List<String> _availableAmenities = [
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

  @override
  void initState() {
    super.initState();
    if (widget.initialAdvanced) {
      _isAdvancedExpanded = true;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _customAmenityController.dispose();
    super.dispose();
  }

  int get _selectedCriteriaCount {
    int count = 0;
    if (_priceRange.start > 0 || _priceRange.end < 20000000) count++;
    if (_areaRange.start > 10 || _areaRange.end < 200) count++;
    count += _selectedAmenities.length;
    return count;
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
    if (_selectedCity == 'Tất cả') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn Tỉnh / Thành phố trước'), duration: Duration(seconds: 2)),
      );
      _showCityPicker();
      return;
    }

    final districts = _districts;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LocationSearchBottomSheet(
        title: 'Chọn Quận / Huyện ($_selectedCity)',
        searchHint: 'Tìm quận, huyện, thị xã...',
        items: districts,
        selectedItem: _selectedDistrict,
        allLabel: 'Tất cả Quận / Huyện',
        onSelected: (dist) {
          setState(() {
            _selectedDistrict = dist;
            _selectedWard = 'Tất cả';
          });
        },
      ),
    );
  }

  void _showWardPicker() {
    if (_selectedCity == 'Tất cả') {
      _showCityPicker();
      return;
    }
    if (_selectedDistrict == 'Tất cả') {
      _showDistrictPicker();
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
        onSelected: (w) {
          setState(() {
            _selectedWard = w;
          });
        },
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _selectedCity = 'TP. Hồ Chí Minh';
      _selectedDistrict = 'Tất cả';
      _selectedWard = 'Tất cả';
      _rentalType = 'single';
      _priceRange = const RangeValues(2000000, 5000000);
      _areaRange = const RangeValues(20, 60);
      _selectedAmenities.clear();
      _selectedAmenities.addAll([
        'Máy lạnh',
        'Có gác lửng',
        'Chỗ để xe miễn phí',
        'Giờ giấc tự do',
        'Gần trường ĐH / Bến xe',
      ]);
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
          'Liên hệ trực tiếp với chủ trọ ${room.hostName}:\n\n📞 ${room.hostPhone}',
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

  String _getSortLabel(String val) {
    switch (val) {
      case 'price_asc':
        return 'Giá thấp đến cao';
      case 'price_desc':
        return 'Giá cao đến thấp';
      case 'rating':
        return 'Đánh giá cao';
      case 'newest':
      default:
        return 'Mới nhất';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filterDistrict = _selectedWard != 'Tất cả'
        ? _selectedWard
        : (_selectedDistrict != 'Tất cả' ? _selectedDistrict : 'Tất cả');

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22, color: AppColors.textDark),
          onPressed: () {
            if (_isAdvancedExpanded) {
              setState(() => _isAdvancedExpanded = false);
            } else if (_hasSearched) {
              setState(() => _hasSearched = false);
            } else if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'Trang Chủ',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Badge(
              smallSize: 8,
              backgroundColor: AppColors.danger,
              child: Icon(Icons.notifications_none, size: 22, color: AppColors.textDark),
            ),
            onPressed: () {},
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: _emerald,
              child: const Icon(Icons.person, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_hasSearched) ...[
              // TRẠNG THÁI 1 HOẶC 2: Chưa nhấn tìm kiếm phòng
              _buildLocationCard(),
              const SizedBox(height: 14),

              if (!_isAdvancedExpanded) ...[
                // TRẠNG THÁI 1: Nút Tìm kiếm phòng + Dòng thông tin
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _executeSearch,
                    icon: const Icon(Icons.search, size: 20, color: Colors.white),
                    label: const Text(
                      'Tìm kiếm phòng',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _emerald,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.circle, size: 6, color: _emerald),
                    SizedBox(width: 6),
                    Text(
                      'Hơn 12.400+ phòng trọ chính chủ đang sẵn sàng',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ] else ...[
                // TRẠNG THÁI 2: Card Bộ lọc nâng cao + Hàng nút tác vụ
                _buildAdvancedFilterSection(),
                const SizedBox(height: 16),
                _buildAdvancedActionButtons(),
              ],
            ] else ...[
              // TRẠNG THÁI 3: Hiển thị kết quả tìm kiếm
              if (_isAdvancedExpanded) ...[
                _buildLocationCard(),
                const SizedBox(height: 14),
                _buildAdvancedFilterSection(),
                const SizedBox(height: 16),
                _buildAdvancedActionButtons(),
                const SizedBox(height: 20),
              ] else ...[
                _buildCompactFilterBar(),
                const SizedBox(height: 16),
              ],
              _buildResultsSection(roomsAsync),
            ],
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
          Row(
            children: [
              Container(
                width: 3.5,
                height: 16,
                decoration: BoxDecoration(
                  color: _emerald,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
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

          // 1. Dropdown Tỉnh/Thành phố
          _buildFieldLabel('Tỉnh/Thành phố *'),
          const SizedBox(height: 6),
          _buildLocationDropdown(
            label: _selectedCity,
            icon: Icons.near_me_outlined,
            onTap: _showCityPicker,
          ),
          const SizedBox(height: 12),

          // 2. Dropdown Phường/Xã
          _buildFieldLabel('Phường / Xã'),
          const SizedBox(height: 6),
          _buildLocationDropdown(
            label: _selectedDistrict == 'Tất cả'
                ? 'Chọn Phường / Xã'
                : (_selectedWard == 'Tất cả' ? _selectedDistrict : '$_selectedWard, $_selectedDistrict'),
            icon: Icons.map_outlined,
            onTap: () {
              if (_selectedDistrict == 'Tất cả') {
                _showDistrictPicker();
              } else {
                _showWardPicker();
              }
            },
          ),
          const SizedBox(height: 14),

          // 3. Hình thức thuê
          _buildFieldLabel('Hình thức thuê'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildRentalTypeCard(
                  type: 'single',
                  icon: Icons.person_outline,
                  title: 'Ở 1 mình',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRentalTypeCard(
                  type: 'shared',
                  icon: Icons.group_outlined,
                  title: 'Ở ghép',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRentalTypeCard(
                  type: 'all',
                  icon: Icons.swap_horiz_outlined,
                  title: 'Cả hai',
                ),
              ),
            ],
          ),

          // Nút + Nâng cao
          if (!_isAdvancedExpanded)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: InkWell(
                onTap: () {
                  setState(() => _isAdvancedExpanded = true);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: _lavenderBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _lavenderBorder),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 18, color: _lavenderText),
                      SizedBox(width: 6),
                      Text(
                        'Nâng cao',
                        style: TextStyle(
                          color: _lavenderText,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      ),
    );
  }

  Widget _buildLocationDropdown({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: _emerald),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, color: AppColors.textDark),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildRentalTypeCard({
    required String type,
    required IconData icon,
    required String title,
  }) {
    final isSelected = _rentalType == type;

    return InkWell(
      onTap: () => setState(() => _rentalType = type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? _emeraldLight : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _emerald : const Color(0xFFE5E7EB),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? _emerald : AppColors.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? _emerald : AppColors.textDark,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 14,
              color: isSelected ? _emerald : const Color(0xFFD1D5DB),
            ),
          ],
        ),
      ),
    );
  }

  // WIDGET: Card Bộ lọc nâng cao chuẩn Figma
  Widget _buildAdvancedFilterSection() {
    final priceStartStr = '${currencyFormatter.format(_priceRange.start.toInt())}đ';
    final priceEndStr = '${currencyFormatter.format(_priceRange.end.toInt())}đ';
    final areaStartStr = '${_areaRange.start.toInt()} m²';
    final areaEndStr = '${_areaRange.end.toInt()} m²';

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
          // Tiêu đề Nâng cao & Badge tiêu chí
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune, size: 20, color: _emerald),
                  const SizedBox(width: 8),
                  const Text(
                    'Bộ lọc',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _emeraldLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_selectedCriteriaCount tiêu chí',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: _emerald,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. GIÁ THUÊ / THÁNG
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Giá thuê / tháng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              Text('$priceStartStr – $priceEndStr', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _emerald)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tối thiểu', style: TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                      Text(priceStartStr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tối đa', style: TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                      Text(priceEndStr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
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
            activeColor: _emerald,
            inactiveColor: const Color(0xFFE5E7EB),
            onChanged: (values) => setState(() => _priceRange = values),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0đ', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              Text('20.000.000đ', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 16),

          // 2. DIỆN TÍCH
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Diện tích', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              Text('$areaStartStr – $areaEndStr', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _emerald)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Từ', style: TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                      Text(areaStartStr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Đến', style: TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                      Text(areaEndStr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
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
            divisions: 19,
            activeColor: _emerald,
            inactiveColor: const Color(0xFFE5E7EB),
            onChanged: (values) => setState(() => _areaRange = values),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('10 m²', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              Text('200 m²', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 16),

          // 3. TIỆN ÍCH & YÊU CẦU
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tiện ích & Yêu cầu', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              Text('${_selectedAmenities.length} đang chọn', style: const TextStyle(fontSize: 12, color: _emerald, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),

          // Ô nhập thêm tiện ích riêng
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
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  onSubmitted: (_) => _addCustomAmenity(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addCustomAmenity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _emerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: const Text('Thêm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Danh sách tiện ích ĐÃ CHỌN
          Column(
            children: _selectedAmenities.map((amenity) {
              final isCustom = !_availableAmenities.contains(amenity) &&
                  !['Máy lạnh', 'Có gác lửng', 'Chỗ để xe miễn phí', 'Giờ giấc tự do'].contains(amenity);

              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedAmenities.remove(amenity);
                      if (isCustom) _availableAmenities.remove(amenity);
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, size: 18, color: _emerald),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            amenity,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isCustom ? const Color(0xFFDBEAFE) : _emeraldLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isCustom ? 'Tùy chọn' : 'Đã chọn',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isCustom ? const Color(0xFF1E40AF) : _emerald,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isCustom) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.close, size: 14, color: AppColors.textMuted),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // Danh sách tiện ích CHƯA CHỌN
          Column(
            children: _availableAmenities.where((a) => !_selectedAmenities.contains(a)).map((amenity) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: InkWell(
                  onTap: () => setState(() => _selectedAmenities.add(amenity)),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.radio_button_unchecked, size: 18, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            amenity,
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF4B5563)),
                          ),
                        ),
                        const Icon(Icons.add, size: 16, color: Color(0xFF9CA3AF)),
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
            child: InkWell(
              onTap: () => setState(() => _isAdvancedExpanded = false),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: _lavenderBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _lavenderBorder),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Thu gọn',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _lavenderText),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_up, size: 16, color: _lavenderText),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Hàng 2 nút Đặt lại và Tìm kiếm trong Trạng thái 2
  Widget _buildAdvancedActionButtons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.refresh, size: 18, color: AppColors.textDark),
              label: const Text('Đặt lại', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFE5E7EB)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _executeSearch,
              icon: const Icon(Icons.search, size: 18, color: Colors.white),
              label: const Text('Tìm kiếm', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _emerald,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // WIDGET: Thanh lọc thu gọn (Trạng thái 3)
  Widget _buildCompactFilterBar() {
    final rentalLabel = _rentalType == 'single' ? 'Ở 1 mình' : (_rentalType == 'shared' ? 'Ở ghép' : 'Tất cả');
    final locationLabel = _selectedDistrict == 'Tất cả'
        ? _selectedCity
        : '$_selectedDistrict, $_selectedCity';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, size: 18, color: _emerald),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$locationLabel • $rentalLabel',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: () => setState(() => _isAdvancedExpanded = true),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _lavenderBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _lavenderBorder),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune, size: 14, color: _lavenderText),
                  SizedBox(width: 4),
                  Text(
                    'Bộ lọc',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _lavenderText,
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

  // WIDGET: Danh sách kết quả tìm kiếm (Trạng thái 3)
  Widget _buildResultsSection(AsyncValue<List<RoomModel>> roomsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 3.5,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _emerald,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
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
                    'Đang tìm phòng...',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                  error: (err, stack) => const Text(
                    'Kết quả tìm kiếm',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                ),
              ],
            ),
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

        roomsAsync.when(
          data: (rooms) {
            if (rooms.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      const Text(
                        'Chưa tìm thấy phòng khớp chính xác',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Hãy thử điều chỉnh khoảng giá hoặc tiện ích để xem nhiều phòng trọ hơn.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: _resetFilters,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Xem tất cả phòng có sẵn'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _emerald,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rooms.length,
              itemBuilder: (context, index) {
                final room = rooms[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _buildHorizontalRoomCard(room),
                );
              },
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: _emerald),
            ),
          ),
          error: (err, stack) => Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Text('Lỗi tải dữ liệu phòng trọ: $err', style: const TextStyle(color: AppColors.danger)),
          ),
        ),
      ],
    );
  }

  // WIDGET: Thẻ phòng trọ dạng ngang chuẩn 100% Figma & tiendo.md
  // Bên trái: Ảnh 95x95dp + Huy hiệu Chính chủ/Mới
  // Bên phải: Tiêu đề, Giá to xanh, Diện tích • Loại phòng • Quận huyện, Chip tiện ích, Nút gọi & chat
  Widget _buildHorizontalRoomCard(RoomModel room) {
    final priceStr = '${currencyFormatter.format(room.price)} đ/tháng';
    final imageUrl = room.images.isNotEmpty
        ? room.images.first
        : 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=800&q=80';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RoomDetailScreen(room: room)),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(10),
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BÊN TRÁI: Ảnh phòng 95x95dp bo góc 12dp + Badge Chính chủ
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 95,
                height: 95,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFFF3F4F6),
                        child: const Icon(Icons.home, size: 36, color: Color(0xFF9CA3AF)),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Chính chủ',
                          style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // BÊN PHẢI: Thông tin chi tiết phòng
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tiêu đề phòng
                  Text(
                    room.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),

                  // Giá thuê to màu xanh lục bảo
                  Text(
                    priceStr,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _emerald),
                  ),
                  const SizedBox(height: 3),

                  // Thông số: Diện tích • Loại phòng • Quận huyện
                  Text(
                    '${room.area.toInt()} m² • ${room.roomType} • ${room.district}',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Hàng chip tiện ích nhỏ + 2 nút tròn gọi điện & chat
                  Row(
                    children: [
                      // Chip tiện ích
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: room.amenities.take(2).map((a) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                a,
                                style: const TextStyle(fontSize: 10, color: Color(0xFF4B5563)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      // Nút tròn Gọi điện 📞
                      Material(
                        color: _emeraldLight,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _showCallHostDialog(room),
                          child: const Padding(
                            padding: EdgeInsets.all(7),
                            child: Icon(Icons.phone, size: 16, color: _emerald),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Nút tròn Nhắn tin 💬
                      Material(
                        color: const Color(0xFFEFF6FF),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _openChatWithHost(room),
                          child: const Padding(
                            padding: EdgeInsets.all(7),
                            child: Icon(Icons.chat_bubble, size: 16, color: Color(0xFF2563EB)),
                          ),
                        ),
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
}

/// Bottom Sheet tìm kiếm địa điểm với Search Bar mượt mà
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
  final TextEditingController _controller = TextEditingController();
  late List<String> _filteredItems;

  @override
  void initState() {
    super.initState();
    _filteredItems = List.from(widget.items);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredItems = List.from(widget.items);
      } else {
        _filteredItems = widget.items.where((it) {
          if (it == 'Tất cả') return true;
          return it.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _controller,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                final isSelected = item == widget.selectedItem;
                final displayName = item == 'Tất cả' ? widget.allLabel : item;

                return ListTile(
                  title: Text(
                    displayName,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? const Color(0xFF006948) : AppColors.textDark,
                      fontSize: 14,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Color(0xFF006948), size: 20)
                      : null,
                  onTap: () {
                    widget.onSelected(item);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
