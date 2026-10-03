import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/roommate_post_model.dart';

class RoommateFilterParams {
  final String district;
  final String targetGender;
  final bool? hasRoom; // null: Tất cả, true: Đã có phòng sẵn, false: Chưa có phòng
  final String occupation; // 'Tất cả', 'Sinh viên', 'Đã đi làm', 'Freelancer'
  final double? budgetMin;
  final double? budgetMax;
  final List<String> habits;
  final int minMatchRate;
  final String searchQuery;

  const RoommateFilterParams({
    this.district = 'Tất cả',
    this.targetGender = 'Tất cả',
    this.hasRoom,
    this.occupation = 'Tất cả',
    this.budgetMin,
    this.budgetMax,
    this.habits = const [],
    this.minMatchRate = 0,
    this.searchQuery = '',
  });

  RoommateFilterParams copyWith({
    String? district,
    String? targetGender,
    bool? hasRoom,
    bool clearHasRoom = false,
    String? occupation,
    double? budgetMin,
    double? budgetMax,
    List<String>? habits,
    int? minMatchRate,
    String? searchQuery,
  }) {
    return RoommateFilterParams(
      district: district ?? this.district,
      targetGender: targetGender ?? this.targetGender,
      hasRoom: clearHasRoom ? null : (hasRoom ?? this.hasRoom),
      occupation: occupation ?? this.occupation,
      budgetMin: budgetMin ?? this.budgetMin,
      budgetMax: budgetMax ?? this.budgetMax,
      habits: habits ?? this.habits,
      minMatchRate: minMatchRate ?? this.minMatchRate,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoommateFilterParams &&
          district == other.district &&
          targetGender == other.targetGender &&
          hasRoom == other.hasRoom &&
          occupation == other.occupation &&
          budgetMin == other.budgetMin &&
          budgetMax == other.budgetMax &&
          listEquals(habits, other.habits) &&
          minMatchRate == other.minMatchRate &&
          searchQuery == other.searchQuery;

  @override
  int get hashCode => Object.hash(
        district,
        targetGender,
        hasRoom,
        occupation,
        budgetMin,
        budgetMax,
        Object.hashAll(habits),
        minMatchRate,
        searchQuery,
      );
}

class RoommateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Danh sách bài đăng tạo mới trong bộ nhớ (đảm bảo luôn hiển thị ngay lập tức)
  static final List<RoommatePostModel> _localCreatedPosts = [];

  // Stream bài đăng tìm ở ghép (an toàn bộ lọc, in-memory filter & sort)
  Stream<List<RoommatePostModel>> getRoommatePostsStream({
    String? district,
    String? targetGender,
    RoommateFilterParams? filters,
  }) {
    final effectiveDistrict = filters?.district ?? district;
    final effectiveTargetGender = filters?.targetGender ?? targetGender;
    final hasRoom = filters?.hasRoom;
    final occupation = filters?.occupation;
    final budgetMin = filters?.budgetMin;
    final budgetMax = filters?.budgetMax;
    final habits = filters?.habits ?? const [];
    final minMatchRate = filters?.minMatchRate ?? 0;
    final searchQuery = filters?.searchQuery.trim().toLowerCase() ?? '';

    return _firestore.collection('roommate_posts').snapshots().handleError((err) {
      debugPrint('Firestore stream error, fallback to local: $err');
      return const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    }).map((snapshot) {
      List<RoommatePostModel> list;
      if (snapshot.docs.isNotEmpty) {
        list = snapshot.docs.map((doc) {
          try {
            return RoommatePostModel.fromFirestore(doc);
          } catch (e) {
            debugPrint('Error parsing roommate post ${doc.id}: $e');
            return null;
          }
        }).whereType<RoommatePostModel>().toList();
      } else {
        list = [];
      }

      // Hợp nhất bài đăng tạo trong phiên (Local) và Cloud Firestore (Local ưu tiên trên đầu)
      final merged = <RoommatePostModel>[];
      for (final p in _localCreatedPosts) {
        merged.add(p);
      }
      for (final p in list) {
        if (!merged.any((item) => item.id == p.id)) {
          merged.add(p);
        }
      }

      // Nạp dữ liệu mẫu Figma nếu danh sách bài đăng rỗng
      if (merged.isEmpty) {
        merged.addAll(getFigmaSamplePosts());
      }

      final filtered = merged.where((post) {
        // 1. Tình trạng phòng (Đã có phòng / Chưa có phòng)
        if (hasRoom != null && post.hasRoom != hasRoom) {
          return false;
        }

        // 2. Tìm kiếm theo từ khóa (trường học, quận, tiêu đề, tên)
        if (searchQuery.isNotEmpty) {
          final matchTitle = post.title.toLowerCase().contains(searchQuery);
          final matchAddress = post.address.toLowerCase().contains(searchQuery);
          final matchDistrict = post.district.toLowerCase().contains(searchQuery);
          final matchAuthor = post.authorName.toLowerCase().contains(searchQuery);
          final matchOcc = post.authorOccupation.toLowerCase().contains(searchQuery);
          if (!matchTitle && !matchAddress && !matchDistrict && !matchAuthor && !matchOcc) {
            return false;
          }
        }

        // 3. Khu vực quận huyện
        if (effectiveDistrict != null && effectiveDistrict.isNotEmpty && effectiveDistrict != 'Tất cả') {
          if (!post.district.toLowerCase().contains(effectiveDistrict.toLowerCase()) &&
              !post.address.toLowerCase().contains(effectiveDistrict.toLowerCase())) {
            return false;
          }
        }

        // 4. Giới tính
        if (effectiveTargetGender != null && effectiveTargetGender.isNotEmpty && effectiveTargetGender != 'Tất cả') {
          if (effectiveTargetGender == 'LGBT+') {
            final isLgbt = post.targetGender.toLowerCase().contains('lgbt') ||
                post.habits.any((h) => h.toLowerCase().contains('lgbt'));
            if (!isLgbt && post.targetGender != 'Tất cả') return false;
          } else {
            if (post.targetGender != 'Tất cả' && post.targetGender != 'tatCa' && post.targetGender != effectiveTargetGender) {
              return false;
            }
          }
        }

        // 5. Nghề nghiệp
        if (occupation != null && occupation.isNotEmpty && occupation != 'Tất cả') {
          if (!post.authorOccupation.toLowerCase().contains(occupation.toLowerCase())) {
            return false;
          }
        }

        // 6. Ngân sách
        if (budgetMin != null && budgetMax != null) {
          final price = post.pricePerPerson > 0 ? post.pricePerPerson : post.budgetMax;
          if (price < budgetMin || price > budgetMax) {
            return false;
          }
        }

        // 7. Lối sống & Thói quen bắt buộc
        if (habits.isNotEmpty) {
          final matchedCount = habits.where((h) => post.habits.contains(h)).length;
          if (matchedCount == 0 && habits.length > 2) {
            return false;
          }
        }

        // 8. Tỷ lệ tương thích Match rate
        if (minMatchRate > 0 && post.matchRate < minMatchRate) {
          return false;
        }

        return true;
      }).toList();

      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return filtered;
    });
  }

  // Đăng bài tìm ở ghép mới
  Future<RoommatePostModel> createPost(RoommatePostModel post) async {
    final newId = post.id.isNotEmpty ? post.id : 'rm_${DateTime.now().millisecondsSinceEpoch}';
    final savedPost = post.copyWith(id: newId);
    _localCreatedPosts.removeWhere((p) => p.id == newId);
    _localCreatedPosts.insert(0, savedPost);

    try {
      await _firestore.collection('roommate_posts').doc(newId).set(savedPost.toMap());
    } catch (e) {
      debugPrint('Firestore save roommate post offline fallback: $e');
    }
    return savedPost;
  }

  // Danh sách bài đăng mẫu chuẩn 100% Figma HomeShare
  static List<RoommatePostModel> getFigmaSamplePosts() {
    return [
      RoommatePostModel(
        id: 'figma_post_1',
        authorId: 'user_minh_trang',
        authorName: 'Minh Trang',
        authorAge: 21,
        authorGender: 'Nữ',
        authorOccupation: 'SV Đại học Ngoại Thương CS2',
        authorAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400',
        title: 'Cần tìm 1 bạn nữ ở ghép căn hộ Sunview Town (Đã có phòng)',
        description: 'Căn hộ 2PN2WC tại chung cư Sunview Town, lầu 12 thoáng mát. Đã trang bị đầy đủ máy giặt, tủ lạnh, bếp từ, máy nước nóng. Tìm 1 bạn nữ gọn gàng, tính tình vui vẻ, hòa đồng cùng share phòng.',
        postType: 'timNguoiOGhep',
        pricePerPerson: 1800000,
        budgetMin: 1500000,
        budgetMax: 2000000,
        address: 'Hiệp Bình Phước, TP. Thủ Đức (Gần cầu Bình Triệu)',
        district: 'TP. Thủ Đức',
        targetGender: 'Nữ',
        habits: ['Tuyệt đối không thuốc lá', 'Yên tĩnh sau 23h', 'Sạch sẽ, ngăn nắp cao', 'Thân thiện vui vẻ', 'Quy định dẫn bạn về phòng'],
        images: [
          'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=600',
          'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?w=600',
        ],
        imageCaptions: ['Phòng ngủ máy lạnh', 'Bếp chung rộng'],
        isVerified: true,
        matchRate: 94,
        hasRoom: true,
        contactPhone: '0981234567',
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
      RoommatePostModel(
        id: 'figma_post_2',
        authorId: 'user_quoc_bao',
        authorName: 'Quốc Bảo',
        authorAge: 22,
        authorGender: 'Nam',
        authorOccupation: 'Kỹ sư phần mềm mới ra trường',
        authorAvatar: 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=400',
        title: 'Cần tìm 1 bạn nam ghép phòng trọ D2 Bình Thạnh (Đã có phòng)',
        description: 'Phòng trọ rộng 28m2 gác lửng, giờ giấc tự do không chung chủ, có chỗ để xe an toàn. Cần 1 bạn nam làm việc văn phòng hoặc sinh viên năm cuối cùng chia tiền phòng.',
        postType: 'timNguoiOGhep',
        pricePerPerson: 2200000,
        budgetMin: 2000000,
        budgetMax: 2500000,
        address: 'Đường Nguyễn Gia Trí, P.25, Bình Thạnh',
        district: 'Bình Thạnh',
        targetGender: 'Nam',
        habits: ['Giờ giấc tự do 24/7', 'Có xe máy riêng', 'Thích thể thao', 'Không tụ tập ồn ào'],
        images: [
          'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=600',
        ],
        imageCaptions: ['Phòng trọ gác lửng'],
        isVerified: true,
        matchRate: 88,
        hasRoom: true,
        contactPhone: '0912987654',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      RoommatePostModel(
        id: 'figma_post_3',
        authorId: 'user_thuy_dung',
        authorName: 'Thùy Dung',
        authorAge: 20,
        authorGender: 'Nữ',
        authorOccupation: 'SV ĐH Sư Phạm Kỹ Thuật (HCMUT)',
        authorAvatar: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400',
        title: 'Muốn tìm 1 bạn nữ tính tình hòa đồng cùng tìm & thuê phòng quanh ĐH Sư...',
        description: 'Mình là sinh viên năm 2 ĐH Sư Phạm Kỹ Thuật, muốn tìm 1 bạn nữ cùng gu để cùng đi tìm và thuê phòng trọ bán kính 2km quanh ngã tư Thủ Đức. Ngân sách tầm 1.5 - 2 triệu/tháng.',
        postType: 'dangTimPhong',
        pricePerPerson: 1750000,
        budgetMin: 1500000,
        budgetMax: 2000000,
        address: 'Bán kính 2km quanh ngã tư Thủ Đức',
        district: 'TP. Thủ Đức',
        targetGender: 'Nữ',
        habits: ['Chăm học, ít ồn', 'Nấu ăn tại phòng', 'Dậy sớm (Trước 7h)', 'Sạch sẽ, ngăn nắp cao'],
        images: [],
        imageCaptions: [],
        isVerified: true,
        matchRate: 91,
        hasRoom: false,
        contactPhone: '0903456789',
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
      RoommatePostModel(
        id: 'figma_post_4',
        authorId: 'user_huy_hoang',
        authorName: 'Huy Hoàng',
        authorAge: 23,
        authorGender: 'Nam',
        authorOccupation: 'Freelancer / WFH',
        authorAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
        title: 'Tìm bạn cùng thuê căn hộ dịch vụ Quận 1 hoặc Bình Thạnh',
        description: 'Làm việc tự do tại nhà, cần không gian làm việc yên tĩnh, có ban công thoáng mát và tôn trọng sự riêng tư của nhau.',
        postType: 'dangTimPhong',
        pricePerPerson: 3000000,
        budgetMin: 2500000,
        budgetMax: 3500000,
        address: 'Khu vực Đa Kao, Quận 1',
        district: 'Quận 1',
        targetGender: 'Nam',
        habits: ['Yên tĩnh sau 23h', 'Tuyệt đối không thuốc lá', 'Thú cưng (Chó/Mèo)', 'Không mở loa to'],
        images: [],
        imageCaptions: [],
        isVerified: true,
        matchRate: 85,
        hasRoom: false,
        contactPhone: '0938112233',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }

  // Vô hiệu hóa nạp bài đăng mẫu theo yêu cầu người dùng
  Future<void> seedInitialRoommatesIfEmpty() async {
    // Không nạp dữ liệu mẫu
  }

  // Bảo toàn bài đăng mẫu để người dùng luôn thấy bài đăng
  Future<void> deleteSampleRoommatePosts() async {
    // Không xóa bài mẫu để tránh màn hình trống
  }
}

final roommateServiceProvider = Provider<RoommateService>((ref) => RoommateService());

class RoommatePostsRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void trigger() => state++;
}

final roommatePostsRefreshTrigger = NotifierProvider<RoommatePostsRefreshNotifier, int>(RoommatePostsRefreshNotifier.new);

final roommatePostsStreamProvider = StreamProvider.autoDispose.family<List<RoommatePostModel>, RoommateFilterParams>((ref, filters) {
  ref.watch(roommatePostsRefreshTrigger);
  final service = ref.watch(roommateServiceProvider);
  return service.getRoommatePostsStream(
    filters: filters,
  );
});
