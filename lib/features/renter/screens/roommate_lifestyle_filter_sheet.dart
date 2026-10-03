import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/roommate_service.dart';

/// Modal Bottom Sheet "Bộ lọc Lifestyle & Ở ghép AI Match" chuẩn Figma 100%
/// Cho phép người dùng lọc theo tình trạng phòng, đối tượng, ngân sách và các tiêu chí lối sống thực tế
class RoommateLifestyleFilterSheet extends StatefulWidget {
  final RoommateFilterParams initialFilters;
  final int matchingCount;
  final ValueChanged<RoommateFilterParams> onApply;

  const RoommateLifestyleFilterSheet({
    super.key,
    required this.initialFilters,
    this.matchingCount = 0,
    required this.onApply,
  });

  static Future<RoommateFilterParams?> show(
    BuildContext context, {
    required RoommateFilterParams initialFilters,
    int matchingCount = 0,
    required ValueChanged<RoommateFilterParams> onApply,
  }) {
    return showModalBottomSheet<RoommateFilterParams>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RoommateLifestyleFilterSheet(
        initialFilters: initialFilters,
        matchingCount: matchingCount,
        onApply: onApply,
      ),
    );
  }

  @override
  State<RoommateLifestyleFilterSheet> createState() => _RoommateLifestyleFilterSheetState();
}

class _RoommateLifestyleFilterSheetState extends State<RoommateLifestyleFilterSheet> {
  // 1. Tình trạng phòng (null = Tất cả, true = Đã có phòng sẵn, false = Chưa có phòng)
  bool? _hasRoom;

  // 2. Đối tượng phù hợp
  String _selectedGender = 'Tất cả';
  String _selectedOccupation = 'Tất cả';

  // 3. Ngân sách mỗi người
  late RangeValues _budgetRange;

  // 4. Lối sống & Thói quen
  final Set<String> _selectedHabits = {};

  // 5. Match Rate
  int _matchRate = 0;

  @override
  void initState() {
    super.initState();
    _hasRoom = widget.initialFilters.hasRoom;
    _selectedGender = widget.initialFilters.targetGender;
    _selectedOccupation = widget.initialFilters.occupation;

    final minVal = (widget.initialFilters.budgetMin ?? 1000000).clamp(500000.0, 6000000.0);
    final maxVal = (widget.initialFilters.budgetMax ?? 3000000).clamp(minVal, 6000000.0);
    _budgetRange = RangeValues(minVal, maxVal);

    if (widget.initialFilters.habits.isNotEmpty) {
      _selectedHabits.addAll(widget.initialFilters.habits);
    }

    _matchRate = widget.initialFilters.minMatchRate;
  }

  void _resetFilters() {
    setState(() {
      _hasRoom = null;
      _selectedGender = 'Tất cả';
      _selectedOccupation = 'Tất cả';
      _budgetRange = const RangeValues(1000000, 3000000);
      _selectedHabits.clear();
      _matchRate = 0;
    });
  }

  void _applyFilters() {
    final updated = widget.initialFilters.copyWith(
      hasRoom: _hasRoom,
      clearHasRoom: _hasRoom == null,
      targetGender: _selectedGender,
      occupation: _selectedOccupation,
      budgetMin: _budgetRange.start,
      budgetMax: _budgetRange.end,
      habits: _selectedHabits.toList(),
      minMatchRate: _matchRate,
    );
    widget.onApply(updated);
    Navigator.pop(context, updated);
  }

  String _formatBudget(double value) {
    if (value >= 1000000) {
      final millions = value / 1000000;
      return '${millions.toStringAsFixed(millions.truncateToDouble() == millions ? 0 : 1)}tr';
    }
    return '${(value / 1000).round()}k';
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.90;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag indicator bar
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Bộ lọc Lifestyle & Ở ghép',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                            ),
                            child: const Text(
                              'AI Match',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Tìm bạn cùng phòng hợp phong cách sống và tính tình',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(Icons.close, size: 18, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Body Form cuộn mượt mà
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                // 1. TÌNH TRẠNG PHÒNG
                _buildSection1RoomStatus(),
                const SizedBox(height: 22),

                // 2. ĐỐI TƯỢNG PHÙ HỢP
                _buildSection2TargetCriteria(),
                const SizedBox(height: 22),

                // 3. NGÂN SÁCH MỖI NGƯỜI
                _buildSection3Budget(),
                const SizedBox(height: 22),

                // 4. TIÊU CHÍ LỐI SỐNG & THÓI QUEN
                _buildSection4LifestyleHabits(),
                const SizedBox(height: 22),

                // 5. MỨC ĐỘ TƯƠNG THÍCH (MATCH RATE)
                _buildSection5MatchRate(),
                const SizedBox(height: 30),
              ],
            ),
          ),

          // Sticky Footer Action Bar
          _buildStickyFooter(widget.matchingCount),
        ],
      ),
    );
  }

  /// 1. TÌNH TRẠNG PHÒNG
  Widget _buildSection1RoomStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.apartment_rounded, size: 18, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  '1. TÌNH TRẠNG PHÒNG',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () => setState(() => _hasRoom = null),
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  'Tất cả',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Option: Đã có phòng sẵn
            Expanded(
              child: _buildRoomStatusCard(
                title: 'Đã có phòng sẵn',
                subtitle: 'Tìm người dọn vào ở chung căn đã thuê',
                icon: Icons.home_rounded,
                isSelected: _hasRoom == true,
                onTap: () => setState(() => _hasRoom = true),
              ),
            ),
            const SizedBox(width: 10),
            // Option: Chưa có phòng
            Expanded(
              child: _buildRoomStatusCard(
                title: 'Chưa có phòng',
                subtitle: 'Tìm bạn cùng gu rồi cùng đi thuê phòng mới',
                icon: Icons.group_rounded,
                isSelected: _hasRoom == false,
                onTap: () => setState(() => _hasRoom = false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoomStatusCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: isSelected ? AppColors.primary : const Color(0xFF94A3B8),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), height: 1.25),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 2. ĐỐI TƯỢNG PHÙ HỢP
  Widget _buildSection2TargetCriteria() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.people_outline_rounded, size: 18, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              '2. ĐỐI TƯỢNG PHÙ HỢP',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Giới tính mong muốn
        const Text(
          'Giới tính mong muốn',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            _buildChoiceChip(
              label: 'Tất cả',
              isSelected: _selectedGender == 'Tất cả',
              onSelected: () => setState(() => _selectedGender = 'Tất cả'),
            ),
            _buildChoiceChip(
              label: 'Nữ',
              isSelected: _selectedGender == 'Nữ',
              isPrimarySolid: true,
              hasCheckmark: true,
              onSelected: () => setState(() => _selectedGender = 'Nữ'),
            ),
            _buildChoiceChip(
              label: 'Nam',
              isSelected: _selectedGender == 'Nam',
              onSelected: () => setState(() => _selectedGender = 'Nam'),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Nghề nghiệp / Tình trạng
        const Text(
          'Nghề nghiệp / Tình trạng',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildChoiceChip(
              label: 'Tất cả',
              isSelected: _selectedOccupation == 'Tất cả',
              onSelected: () => setState(() => _selectedOccupation = 'Tất cả'),
            ),
            _buildChoiceChip(
              label: 'Sinh viên',
              icon: Icons.school_outlined,
              isSelected: _selectedOccupation == 'Sinh viên',
              isPrimarySolid: true,
              hasCheckmark: true,
              onSelected: () => setState(() => _selectedOccupation = 'Sinh viên'),
            ),
            _buildChoiceChip(
              label: 'Người đi làm',
              icon: Icons.work_outline,
              isSelected: _selectedOccupation == 'Người đi làm',
              onSelected: () => setState(() => _selectedOccupation = 'Người đi làm'),
            ),
            _buildChoiceChip(
              label: 'Freelancer',
              icon: Icons.laptop_chromebook,
              isSelected: _selectedOccupation == 'Freelancer',
              onSelected: () => setState(() => _selectedOccupation = 'Freelancer'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChoiceChip({
    required String label,
    IconData? icon,
    bool isSelected = false,
    bool isPrimarySolid = false,
    bool hasCheckmark = false,
    required VoidCallback onSelected,
  }) {
    Color bg;
    Color textColor;
    Border? border;

    if (isSelected && isPrimarySolid) {
      bg = AppColors.primary;
      textColor = Colors.white;
      border = null;
    } else if (isSelected) {
      bg = AppColors.primarySurface;
      textColor = AppColors.primary;
      border = Border.all(color: AppColors.primary, width: 1.2);
    } else {
      bg = Colors.white;
      textColor = const Color(0xFF334155);
      border = Border.all(color: const Color(0xFFE2E8F0));
    }

    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: border,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: textColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: textColor,
              ),
            ),
            if (hasCheckmark && isSelected) ...[
              const SizedBox(width: 4),
              Icon(Icons.check, size: 14, color: textColor),
            ],
          ],
        ),
      ),
    );
  }

  /// 3. NGÂN SÁCH MỖI NGƯỜI
  Widget _buildSection3Budget() {
    final startStr = _formatBudget(_budgetRange.start);
    final endStr = _formatBudget(_budgetRange.end);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
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
                  Icon(Icons.account_balance_wallet_outlined, size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    '3. NGÂN SÁCH MỖI\nNGƯỜI',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 1.2),
                ),
                child: Text(
                  '$startStr - $endStr/tháng',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: const Color(0xFFCBD5E1),
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 3),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              trackHeight: 4,
            ),
            child: RangeSlider(
              values: _budgetRange,
              min: 500000,
              max: 6000000,
              divisions: 55,
              onChanged: (values) {
                setState(() => _budgetRange = values);
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('500k', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                Text('2.5 triệu', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                Text('6 triệu+', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 4. TIÊU CHÍ LỐI SỐNG & THÓI QUEN
  Widget _buildSection4LifestyleHabits() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.psychology_outlined, size: 19, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              '4. TIÊU CHÍ LỐI SỐNG & THÓI QUEN',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Chọn các tiêu chí mà bạn coi trọng nhất ở bạn cùng phòng',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 12),

        // Grid 2 cột: Thói quen sinh hoạt cơ bản
        _buildGridHabits([
          const _HabitItem('Yên tĩnh sau 23h', Icons.nightlight_round, iconColor: Color(0xFF0284C7)),
          const _HabitItem('Sạch sẽ, ngăn nắp cao', Icons.cleaning_services_rounded, iconColor: AppColors.primary),
          const _HabitItem('Tuyệt đối không thuốc lá', Icons.smoke_free_rounded, iconColor: Color(0xFFEF4444)),
          const _HabitItem('Giờ giấc tự do', Icons.access_time_rounded, iconColor: Color(0xFF0284C7)),
          const _HabitItem('Có xe máy riêng', Icons.two_wheeler_rounded, iconColor: Color(0xFF0284C7)),
          const _HabitItem('Thích thể thao/Gym', Icons.sports_soccer_rounded, iconColor: Color(0xFFD97706)),
          const _HabitItem('Không ồn ào/tụ tập', Icons.volume_off_rounded, iconColor: Color(0xFFEF4444)),
          const _HabitItem('Chăm học/Làm việc', Icons.menu_book_rounded, iconColor: AppColors.primary),
        ]),
        const SizedBox(height: 10),

        // 3 Cards lớn full-width (Đặc biệt quan trọng)
        _buildFullWidthHabitTile(
          habitKey: 'Nấu ăn thường xuyên',
          title: 'Nấu ăn thường xuyên',
          subtitle: 'Có nhu cầu dùng bếp chung nấu nướng hàng ngày',
          icon: Icons.restaurant_rounded,
          iconColor: const Color(0xFF0284C7),
        ),
        const SizedBox(height: 8),
        _buildFullWidthHabitTile(
          habitKey: 'Thú cưng (Chó/Mèo)',
          title: 'Thú cưng (Chó/Mèo)',
          subtitle: 'Không dị ứng, chấp nhận người có nuôi pet',
          icon: Icons.pets_rounded,
          iconColor: const Color(0xFFF59E0B),
        ),
        const SizedBox(height: 8),
        _buildFullWidthHabitTile(
          habitKey: 'Quy định dẫn bạn về phòng',
          title: 'Quy định dẫn bạn về phòng',
          subtitle: 'Hạn chế bạn khác giới ở lại qua đêm',
          icon: Icons.people_alt_rounded,
          iconColor: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildGridHabits(List<_HabitItem> items) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.7,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = _selectedHabits.contains(item.title);

        return InkWell(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedHabits.remove(item.title);
              } else {
                _selectedHabits.add(item.title);
              }
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primarySurface : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                width: isSelected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                // Custom check container
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 13, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 6),
                Icon(item.icon, size: 15, color: item.iconColor ?? const Color(0xFF475569)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: const Color(0xFF0F172A),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFullWidthHabitTile({
    required String habitKey,
    required String title,
    required String subtitle,
    required IconData icon,
    Color? iconColor,
  }) {
    final isSelected = _selectedHabits.contains(habitKey);

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedHabits.remove(habitKey);
          } else {
            _selectedHabits.add(habitKey);
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.primary).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: iconColor ?? AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1),
                  width: 1.5,
                ),
              ),
              child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }

  /// 5. MỨC ĐỘ TƯƠNG THÍCH (MATCH RATE)
  Widget _buildSection5MatchRate() {
    return InkWell(
      onTap: () {
        setState(() {
          _matchRate = _matchRate >= 80 ? 0 : 80;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mức độ tương thích (Match rate)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Chỉ hiện hồ sơ có độ trùng thói quen từ 80%',
                    style: TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Text(
                _matchRate > 0 ? '≥ $_matchRate%' : 'Tất cả',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sticky Footer Action Bar
  Widget _buildStickyFooter(int matchingCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Nút Đặt lại
            OutlinedButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Đặt lại', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF334155),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(width: 12),

            // Nút Áp dụng bộ lọc
            Expanded(
              child: ElevatedButton(
                onPressed: _applyFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: Text(
                  matchingCount > 0
                      ? 'Áp dụng bộ lọc ($matchingCount bạn phù hợp)'
                      : 'Áp dụng bộ lọc',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitItem {
  final String title;
  final IconData icon;
  final Color? iconColor;

  const _HabitItem(this.title, this.icon, {this.iconColor});
}
