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

/// Màn hình Tìm kiếm & Bộ lọc nâng cao chuẩn 100% Figma HomeShare
/// Hỗ trợ 3 trạng thái:
/// 1. Tìm kiếm cơ bản (Card Khu vực + Nút Tìm kiếm phòng)
/// 2. Sổ bộ lọc nâng cao xuống (Khoảng giá, Diện tích, Tiện ích chuẩn #006948)
/// 3. Hiển thị kết quả tìm kiếm (Thanh bộ lọc thu gọn + Danh sách kết quả realtime)
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
  static const Color _lavenderBg = Color(0xFFF5F3FF);
  static const Color _lavenderBorder = Color(0xFFDDD6FE);
  static const Color _lavenderText = Color(0xFF7C3AED);

  // 1. Khu vực state 3 cấp: Tỉnh/TP -> Quận/Huyện -> Phường/Xã
  String _selectedCity = 'TP. Hồ Chí Minh';
  String _selectedDistrict = 'Tất cả';
  String _selectedWard = 'Tất cả';
  String _rentalType = 'all'; // 'all' (Tất cả), 'single' (Ở 1 mình), 'shared' (Ở ghép)

  // 2. Bộ lọc nâng cao state
  bool _isAdvancedExpanded = false;
  bool _hasSearched = false;

  // Giá thuê mặc định: toàn dải 0đ - 20.000.000đ để hiển thị toàn bộ phòng
  RangeValues _priceRange = const RangeValues(0, 20000000);
  final double _minPriceLimit = 0;
  final double _maxPriceLimit = 20000000;

  // Diện tích mặc định: toàn dải 10m² - 200m²
  RangeValues _areaRange = const RangeValues(10, 200);
  final double _minAreaLimit = 10;
  final double _maxAreaLimit = 200;

  // Tiện ích & Yêu cầu: bắt đầu rỗng để người dùng tự chọn linh hoạt
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
  final Set<String> _favoriteRoomIds = {};

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
        const SnackBar(
          content: Text('Vui lòng chọn Tỉnh / Thành phố trước'),
          duration: Duration(seconds: 2),
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn Tỉnh / Thành phố trước'),
          duration: Duration(seconds: 2),
        ),
      );
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
      _rentalType = 'all';
      _priceRange = const RangeValues(0, 20000000);
      _areaRange = const RangeValues(10, 200);
      _selectedAmenities.clear();
      _selectedSort = 'newest';
      _hasSearched = false;
      _isAdvancedExpanded = false;
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOutCubic);
    }
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

  int get _selectedCriteriaCount {
    int count = 0;
    if (_priceRange.start > 0 || _priceRange.end < 20000000) count++;
    if (_areaRange.start > 10 || _areaRange.end < 200) count++;
    count += _selectedAmenities.length;
    return count;
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
          'Tìm kiếm phòng',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 22, color: AppColors.textDark),
            tooltip: 'Đặt lại bộ lọc',
            onPressed: _resetFilters,
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_hasSearched) ...[
              // TRẠNG THÁI 1 HOẶC 2: Chưa nhấn tìm kiếm phòng
              _buildLocationCard(),
              const SizedBox(height: 14),

              if (!_isAdvancedExpanded) ...[
                ElevatedButton.icon(
                  onPressed: _executeSearch,
                  icon: const Icon(Icons.search, size: 20, color: Colors.white),
                  label: const Text(
                    'Tìm kiếm phòng',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _emerald,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
                const SizedBox(height: 10),
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
                const SizedBox(height: 20),
                _buildResultsSection(roomsAsync),
              ] else ...[
                _buildAdvancedFilterSection(),
                const SizedBox(height: 16),
                _buildAdvancedActionButtons(),
                const SizedBox(height: 24),
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
            children: const [
              Icon(Icons.location_on, size: 20, color: _emerald),
              SizedBox(width: 6),
              Text(
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

          // 1. Tỉnh / Thành phố
          _buildFieldLabel('Tỉnh / Thành phố *'),
          const SizedBox(height: 6),
          _buildLocationDropdown(
            label: _selectedCity,
            icon: Icons.location_city,
            onTap: _showCityPicker,
          ),
          const SizedBox(height: 12),

          // 2. Quận / Huyện & 3. Phường / Xã
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Quận / Huyện'),
                    const SizedBox(height: 6),
                    _buildLocationDropdown(
                      label: _selectedDistrict,
                      icon: Icons.map_outlined,
                      onTap: _showDistrictPicker,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Phường / Xã'),
                    const SizedBox(height: 6),
                    _buildLocationDropdown(
                      label: _selectedWard,
                      icon: Icons.signpost_outlined,
                      onTap: _showWardPicker,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4. Hình thức thuê
          _buildFieldLabel('Hình thức thuê'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildRentalTypeCard(
                  type: 'single',
                  icon: Icons.person,
                  title: 'Ở 1 mình',
                  subtitle: 'Phòng riêng tư',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRentalTypeCard(
                  type: 'shared',
                  icon: Icons.group,
                  title: 'Ở ghép',
                  subtitle: 'Tìm bạn cùng phòng',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRentalTypeCard(
                  type: 'all',
                  icon: Icons.dashboard_outlined,
                  title: 'Cả hai',
                  subtitle: 'Tất cả loại hình',
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD1D5DB)),
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
    required String subtitle,
  }) {
    final isSelected = _rentalType == type;

    return InkWell(
      onTap: () => setState(() => _rentalType = type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? _emeraldLight : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _emerald : const Color(0xFFE5E7EB),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? _emerald : AppColors.textMuted,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? _emerald : AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9.5,
                color: isSelected ? _emerald.withValues(alpha: 0.8) : AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // WIDGET: Card Bộ lọc nâng cao chuẩn Figma
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề Nâng cao & Nút Thu gọn
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune, size: 20, color: _emerald),
                  const SizedBox(width: 8),
                  const Text(
                    'Bộ lọc nâng cao',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _emeraldLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_selectedCriteriaCount tiêu chí',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _emerald,
                      ),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => setState(() => _isAdvancedExpanded = false),
                icon: const Icon(Icons.keyboard_arrow_up, size: 18, color: _emerald),
                label: const Text(
                  'Thu gọn',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _emerald),
                ),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. Khoảng giá thuê
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFieldLabel('Khoảng giá (VNĐ / tháng)'),
              Text(
                '${(currencyFormatter.format(_priceRange.start))} - ${(currencyFormatter.format(_priceRange.end))} đ',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _emerald),
              ),
            ],
          ),
          RangeSlider(
            values: _priceRange,
            min: _minPriceLimit,
            max: _maxPriceLimit,
            divisions: 20,
            activeColor: _emerald,
            inactiveColor: const Color(0xFFE5E7EB),
            labels: RangeLabels(
              '${(_priceRange.start / 1000000).toStringAsFixed(1)}Tr',
              '${(_priceRange.end / 1000000).toStringAsFixed(1)}Tr',
            ),
            onChanged: (values) => setState(() => _priceRange = values),
          ),
          const SizedBox(height: 14),

          // 2. Diện tích
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFieldLabel('Diện tích (m²)'),
              Text(
                '${_areaRange.start.toInt()}m² - ${_areaRange.end.toInt()}m²',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _emerald),
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
            labels: RangeLabels(
              '${_areaRange.start.toInt()}m²',
              '${_areaRange.end.toInt()}m²',
            ),
            onChanged: (values) => setState(() => _areaRange = values),
          ),
          const SizedBox(height: 14),

          // 3. Tiện ích & Yêu cầu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFieldLabel('Tiện ích & Yêu cầu'),
              Text(
                '${_selectedAmenities.length} đang chọn',
                style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableAmenities.map((amenity) {
              final isChecked = _selectedAmenities.contains(amenity);
              return FilterChip(
                label: Text(amenity),
                selected: isChecked,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedAmenities.add(amenity);
                    } else {
                      _selectedAmenities.remove(amenity);
                    }
                  });
                },
                selectedColor: _emeraldLight,
                checkmarkColor: _emerald,
                backgroundColor: const Color(0xFFF9FAFB),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                  color: isChecked ? _emerald : AppColors.textDark,
                ),
                side: BorderSide(
                  color: isChecked ? _emerald : const Color(0xFFE5E7EB),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Ô thêm tiện ích tùy chỉnh
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customAmenityController,
                  decoration: InputDecoration(
                    hintText: 'Thêm tiện ích khác (ví dụ: Nuôi mèo, Ban công...)',
                    hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _emerald),
                    ),
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
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                child: const Text('Thêm', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // WIDGET: Action Buttons
  Widget _buildAdvancedActionButtons() {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: OutlinedButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.refresh, size: 18, color: AppColors.textDark),
            label: const Text('Đặt lại', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: const BorderSide(color: Color(0xFFD1D5DB)),
              backgroundColor: const Color(0xFFF9FAFB),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _executeSearch,
            icon: const Icon(Icons.search, size: 18, color: Colors.white),
            label: const Text('Tìm kiếm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _emerald,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  // WIDGET: Thanh bộ lọc thu gọn hiển thị ở Trạng thái 3
  Widget _buildCompactFilterBar() {
    final locationText = _selectedWard != 'Tất cả'
        ? '$_selectedWard, ${_selectedDistrict != 'Tất cả' ? _selectedDistrict : _selectedCity}'
        : (_selectedDistrict != 'Tất cả'
            ? '$_selectedDistrict, $_selectedCity'
            : (_selectedCity == 'Tất cả' ? 'Toàn quốc' : _selectedCity));

    final typeText = _rentalType == 'single'
        ? 'Ở 1 mình'
        : (_rentalType == 'shared' ? 'Ở ghép' : 'Tất cả hình thức');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _emeraldLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.location_on, color: _emerald, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  locationText,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$typeText • $_selectedCriteriaCount tiêu chí',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => setState(() => _isAdvancedExpanded = true),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD6E2FF)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune, size: 14, color: Color(0xFF1E5BB0)),
                  SizedBox(width: 4),
                  Text(
                    'Bộ lọc',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E5BB0),
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

  // WIDGET: Danh sách kết quả tìm kiếm
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
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _emerald,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                roomsAsync.when(
                  data: (rooms) => Text(
                    _hasSearched
                        ? 'Kết quả tìm kiếm (${rooms.length} phòng)'
                        : 'Gợi ý phòng trọ dành cho bạn (${rooms.length} phòng)',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  loading: () => Text(
                    _hasSearched ? 'Kết quả tìm kiếm...' : 'Đang tải gợi ý phòng...',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                  error: (err, stack) => Text(
                    _hasSearched ? 'Kết quả tìm kiếm' : 'Gợi ý phòng trọ',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
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
                  child: _buildRoomCard(room),
                );
              },
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
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

  // WIDGET: Thẻ phòng trọ chuẩn HomeShare
  Widget _buildRoomCard(RoomModel room) {
    final isFavorite = _favoriteRoomIds.contains(room.id);
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ảnh phòng
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: SizedBox(
                    height: 170,
                    width: double.infinity,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFFF3F4F6),
                        child: const Icon(Icons.home, size: 48, color: Color(0xFF9CA3AF)),
                      ),
                    ),
                  ),
                ),
                // Badge Loại phòng
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      room.roomType,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                // Nút Yêu thích
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        setState(() {
                          if (isFavorite) {
                            _favoriteRoomIds.remove(room.id);
                          } else {
                            _favoriteRoomIds.add(room.id);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: isFavorite ? Colors.redAccent : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Nội dung chi tiết
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${room.address}, ${room.district}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Giá và Diện tích
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        priceStr,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${room.area.toInt()} m²',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Tiện ích chips
                  if (room.amenities.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: room.amenities.take(3).map((a) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(a, style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569))),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Chủ trọ & Tác vụ nhanh
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 13,
                              backgroundColor: _emeraldLight,
                              child: const Icon(Icons.person, size: 15, color: _emerald),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                room.hostName.isNotEmpty ? room.hostName : 'Chủ trọ',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.phone_outlined, size: 20, color: _emerald),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _showCallHostDialog(room),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.chat_bubble_outline, size: 20, color: Color(0xFF2563EB)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _openChatWithHost(room),
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
