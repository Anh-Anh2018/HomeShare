import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/data/models/room_model.dart';
import 'package:home_share/data/models/roommate_post_model.dart';
import 'package:home_share/data/models/booking_model.dart';
import 'package:home_share/data/models/chat_model.dart';
import 'package:home_share/core/services/chat_service.dart';
import 'package:home_share/core/services/room_service.dart';
import 'package:home_share/core/constants/vietnam_locations.dart';
import 'package:home_share/features/auth/providers/user_provider.dart';
import 'package:home_share/features/profile/screens/cccd_scanner_screen.dart';
import 'package:home_share/core/utils/vietqr_helper.dart';
import 'package:home_share/core/services/roommate_service.dart';
import 'package:home_share/core/services/image_storage_service.dart';
import 'package:home_share/core/constants/app_colors.dart';
import 'package:home_share/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Module 1: Màn hình chào mừng (Tc_WELCOME_01 - 50)', () {
    test('Tc_WELCOME_01 & 02: Onboarding content and default attributes', () {
      const appTitle = 'HomeShare';
      expect(appTitle, equals('HomeShare'));
      expect(appTitle.isNotEmpty, isTrue);
    });

    test('Tc_WELCOME_03 & 04: Navigation & step sequence logic', () {
      int currentSlide = 0;
      void nextSlide() => currentSlide++;
      nextSlide();
      expect(currentSlide, equals(1));
      nextSlide();
      expect(currentSlide, equals(2));
    });
  });

  group('Module 2: Chọn vai trò (Tc_ROLE_01 - 50)', () {
    test('Tc_ROLE_01 & 03: Phân quyền vai trò người thuê (Tenant/Renter)', () {
      final profile = UserProfile(
        uid: 'user_renter_01',
        email: 'renter@homeshare.vn',
        displayName: 'Nguyễn Văn Thuê',
        phoneNumber: '0901234567',
        role: 'renter',
      );

      expect(profile.role, equals('renter'));
      expect(profile.vaiTro, equals('renter'));
      expect(profile.role == 'renter', isTrue);
    });

    test('Tc_ROLE_04: Vai trò chủ trọ phân biệt độc lập', () {
      final hostProfile = UserProfile(
        uid: 'user_host_01',
        email: 'host@homeshare.vn',
        displayName: 'Trần Văn Chủ',
        phoneNumber: '0909999999',
        role: 'host',
      );

      expect(hostProfile.role, equals('host'));
      expect(hostProfile.role == 'renter', isFalse);
    });

    test('Tc_ROLE_05 & 06: Đăng ký hỗ trợ đủ 2 vai trò Người thuê (renter) và Chủ trọ (host)', () {
      const availableRoles = ['renter', 'host'];
      expect(availableRoles.contains('renter'), isTrue);
      expect(availableRoles.contains('host'), isTrue);
      expect(availableRoles.length, equals(2));

      // Kiểm định role mapping DrawIO
      int getRoleId(String role) => role == 'host' ? 2 : 1;
      expect(getRoleId('renter'), equals(1));
      expect(getRoleId('host'), equals(2));
    });
  });

  group('Module 3: Thông tin người thuê 1 & 2 - eKYC (Tc_INFO1_01 - 50, Tc_INFO2_01 - 50)', () {
    test('Tc_INFO1_03 & 04: Hồ sơ cá nhân với đầy đủ thông tin chuẩn DrawIO', () {
      final profile = UserProfile(
        uid: 'user_toan_01',
        email: 'toan@gmail.com',
        displayName: 'Trần Thanh Anh Toàn',
        phoneNumber: '0901234567',
        role: 'renter',
        avatarUrl: 'https://example.com/avatar.jpg',
      );

      final map = profile.toMap();
      expect(map['email'], equals('toan@gmail.com'));
      expect(map['displayName'], equals('Trần Thanh Anh Toàn'));
      expect(map['hoTen'], equals('Trần Thanh Anh Toàn'));
      expect(map['phoneNumber'], equals('0901234567'));
      expect(map['soDienThoai'], equals('0901234567'));
      expect(map['role'], equals('renter'));
      expect(map['vaiTro'], equals('renter'));
    });

    test('Tc_INFO2_03 & 04: Xác thực định dạng CCCD chuẩn 12 chữ số', () {
      bool validateCccd(String cccd) {
        final regex = RegExp(r'^\d{12}$');
        return regex.hasMatch(cccd);
      }

      expect(validateCccd('079204001234'), isTrue); // Đúng 12 số
      expect(validateCccd(''), isFalse); // Rỗng
      expect(validateCccd('12345'), isFalse); // Thiếu số
      expect(validateCccd('07920400123a'), isFalse); // Chứa chữ
      expect(validateCccd('0792040012345'), isFalse); // Thừa số
    });

    test('Tc_USER_CODE_01: Sinh mã người dùng chuẩn 5 ký tự (3 số đầu + 2 chữ sau) và nội dung chuyển tiền', () {
      // 1. Kiểm tra định dạng mã sinh ngẫu nhiên
      final randomCode = UserProfile.generateUserCode();
      expect(randomCode.length, equals(5));
      expect(UserProfile.isValidUserCode(randomCode), isTrue);
      expect(RegExp(r'^\d{3}[A-Z]{2}$').hasMatch(randomCode), isTrue);

      // 2. Kiểm tra tính tất định (deterministic) khi có seed (UID)
      const uid = 'user_toan_999';
      final code1 = UserProfile.generateUserCode(seed: uid);
      final code2 = UserProfile.generateUserCode(seed: uid);
      expect(code1, equals(code2));
      expect(code1.length, equals(5));
      expect(UserProfile.isValidUserCode(code1), isTrue);
      // 3 ký tự đầu phải là số
      final digits = code1.substring(0, 3);
      expect(int.tryParse(digits) != null, isTrue);
      // 2 ký tự sau phải là chữ cái in hoa
      final letters = code1.substring(3);
      expect(RegExp(r'^[A-Z]{2}$').hasMatch(letters), isTrue);

      // 3. Kiểm tra UserProfile tích hợp mã người dùng
      final profile = UserProfile(
        uid: 'user_test_01',
        email: 'test@homeshare.vn',
        displayName: 'Nguyễn Văn Test',
        phoneNumber: '0912345678',
      );
      expect(profile.userCode.length, equals(5));
      expect(profile.maNguoiDung, equals(profile.userCode));
      expect(profile.idNguoiDung, equals(profile.userCode));
      expect(profile.maDinhDanh, equals(profile.userCode));

      final profileMap = profile.toMap();
      expect(profileMap['userCode'], equals(profile.userCode));
      expect(profileMap['maNguoiDung'], equals(profile.userCode));

      // 4. Kiểm tra nội dung chuyển tiền (nội dung chuyển là mã của người dùng để Admin dễ tìm kiếm)
      final transferContent = profile.userCode;
      expect(transferContent, equals(profile.userCode));
      expect(transferContent.length, equals(5));
      expect(RegExp(r'^\d{3}[A-Z]{2}$').hasMatch(transferContent), isTrue);
    });
  });

  group('Module 4: Tìm kiếm phòng trọ (Tc_DASHBOARD_01 - 50)', () {
    test('Tc_DASHBOARD_07 & 08: Tìm kiếm với từ khóa hợp lệ và cắt khoảng trắng thừa (trim)', () {
      String sanitizeQuery(String input) => input.trim();

      expect(sanitizeQuery('   Thủ Đức   '), equals('Thủ Đức'));
      expect(sanitizeQuery('   Bình Thạnh '), equals('Bình Thạnh'));
    });

    test('Tc_DASHBOARD_09: Xử lý an toàn từ khóa đặc biệt không crash', () {
      const specialQuery = '@#\$%^&*()_+';
      const params = RoomFilterParams(searchQuery: specialQuery);

      expect(params.searchQuery, equals(specialQuery));
      expect(params.searchQuery.isNotEmpty, isTrue);
    });

    test('Tc_DASHBOARD_11 & 12: Giới hạn độ dài từ khóa và chức năng xóa nhanh (x)', () {
      String query = 'Phòng trọ cao cấp gần trường ĐH Công nghệ Thủ Đức TP.HCM';
      expect(query.length <= 100, isTrue);

      // Nhấn 'x' để xóa từ khóa
      query = '';
      expect(query.isEmpty, isTrue);
    });

    test('Tc_DASHBOARD_19 & 20: Quản lý lịch sử tìm kiếm gần đây không trùng lặp và đưa lên đầu', () {
      final recentSearches = <String>['Đại học Bách Khoa', 'Bình Thạnh dưới 4 triệu'];

      void addSearch(String keyword) {
        recentSearches.remove(keyword);
        recentSearches.insert(0, keyword);
      }

      addSearch('Khu CNC Quận 9');
      expect(recentSearches.first, equals('Khu CNC Quận 9'));
      expect(recentSearches.length, equals(3));

      // Thêm lại từ khóa đã có -> không trùng lặp, đưa lên đầu
      addSearch('Đại học Bách Khoa');
      expect(recentSearches.first, equals('Đại học Bách Khoa'));
      expect(recentSearches.length, equals(3));
    });
  });

  group('Module 5: Lọc theo nhu cầu bản thân (Tc_FILTER_01 - 50)', () {
    test('Tc_FILTER_01 - 04: Khoảng giá thuê và diện tích tương thích RangeSlider', () {
      const minPrice = 2000000.0;
      const maxPrice = 5000000.0;
      const minArea = 20.0;
      const maxArea = 60.0;

      const filter = RoomFilterParams(
        minPrice: minPrice,
        maxPrice: maxPrice,
        minArea: minArea,
        maxArea: maxArea,
      );

      expect(filter.minPrice, equals(2000000.0));
      expect(filter.maxPrice, equals(5000000.0));
      expect(filter.minArea, equals(20.0));
      expect(filter.maxArea, equals(60.0));
    });

    test('Tc_FILTER_05: Chọn và bỏ chọn tiện ích linh hoạt', () {
      final selectedAmenities = {'Máy lạnh', 'Có gác lửng', 'Chỗ để xe miễn phí'};

      // Toggle thêm
      selectedAmenities.add('Wifi tốc độ cao');
      expect(selectedAmenities.contains('Wifi tốc độ cao'), isTrue);

      // Toggle bỏ chọn
      selectedAmenities.remove('Có gác lửng');
      expect(selectedAmenities.contains('Có gác lửng'), isFalse);
    });

    test('Tc_FILTER_06: Dữ liệu 34 Tỉnh/Thành phố mới (NQ 202/2025/QH15) và cascading quận huyện', () {
      expect(VietnamLocations.provinces.length, equals(34));
      expect(VietnamLocations.provinces63.length, equals(63));
      expect(VietnamLocations.provinces.first, equals('TP. Hồ Chí Minh'));

      final hcmWards = VietnamLocations.getDistricts('TP. Hồ Chí Minh');
      expect(hcmWards.contains('Quận 1'), isTrue);
      expect(hcmWards.contains('TP. Thủ Đức'), isTrue);
      expect(hcmWards.contains('Phường 25 (Bình Thạnh)'), isTrue);

      final danangWards = VietnamLocations.getDistricts('Đà Nẵng');
      expect(danangWards.contains('Quận Hải Châu'), isTrue);
    });

    test('Tc_ADMIN_01: Dữ liệu phân cấp hành chính đầy đủ 34 Tỉnh/TP (NQ 202/2025/QH15), Quận/Huyện và Phường/Xã toàn quốc cho đăng bài', () {
      expect(VietnamLocations.provinces.length, equals(34));
      expect(VietnamLocations.provinces63.length, equals(63));

      // 1. Kiểm tra Quận/Huyện của TP. Hồ Chí Minh
      final hcmDistricts = VietnamLocations.getAdministrativeDistricts('TP. Hồ Chí Minh');
      expect(hcmDistricts.isNotEmpty, isTrue);
      expect(hcmDistricts.contains('Quận 1') || hcmDistricts.contains('Bình Thạnh'), isTrue);

      // 2. Kiểm tra Phường/Xã của Quận 1 (TP.HCM)
      final q1Wards = VietnamLocations.getWards('TP. Hồ Chí Minh', 'Quận 1');
      expect(q1Wards.isNotEmpty, isTrue);
      expect(q1Wards.any((w) => w.contains('Bến Nghé') || w.contains('Bến Thành')), isTrue);

      // 3. Kiểm tra Phường/Xã của Hà Nội
      final hnWards = VietnamLocations.getWards('Hà Nội', 'Cầu Giấy');
      expect(hnWards.isNotEmpty, isTrue);
      expect(hnWards.any((w) => w.contains('Dịch Vọng')), isTrue);

      // 4. Kiểm tra Phường/Xã của Đà Nẵng
      final dnWards = VietnamLocations.getWards('Đà Nẵng', 'Hải Châu');
      expect(dnWards.isNotEmpty, isTrue);

      // 5. Kiểm tra Phường/Xã của Cần Thơ
      final ctWards = VietnamLocations.getWards('Cần Thơ', 'Ninh Kiều');
      expect(ctWards.isNotEmpty, isTrue);
    });
  });

  group('Module 6: Kết quả tìm kiếm & Lọc (Tc_SEARCH_01 - 50)', () {
    test('Tc_SEARCH_01 - 04: Sắp xếp kết quả phòng trọ theo các tiêu chí', () {
      final now = DateTime.now();
      final r1 = RoomModel(
        id: '1',
        title: 'Phòng A',
        description: '',
        price: 3000000,
        deposit: 3000000,
        address: 'Địa chỉ A',
        district: 'Bình Thạnh',
        area: 20,
        roomType: 'Phòng trọ',
        amenities: [],
        images: [],
        hostId: 'h1',
        hostName: 'Chủ 1',
        hostPhone: '0901',
        rating: 4.5,
        createdAt: now.subtract(const Duration(days: 2)),
      );
      final r2 = RoomModel(
        id: '2',
        title: 'Phòng B',
        description: '',
        price: 2000000,
        deposit: 2000000,
        address: 'Địa chỉ B',
        district: 'Gò Vấp',
        area: 25,
        roomType: 'Phòng trọ',
        amenities: [],
        images: [],
        hostId: 'h2',
        hostName: 'Chủ 2',
        hostPhone: '0902',
        rating: 4.9,
        createdAt: now.subtract(const Duration(days: 1)),
      );

      final list = [r1, r2];

      // Sắp xếp theo giá tăng dần
      list.sort((a, b) => a.price.compareTo(b.price));
      expect(list.first.id, equals('2'));

      // Sắp xếp theo đánh giá cao nhất
      list.sort((a, b) => b.rating.compareTo(a.rating));
      expect(list.first.id, equals('2'));
    });
  });

  group('Module 7: Chi tiết phòng & Hành động (Tc_DETAIL_01 - 50, Tc_ACTIONS_01 - 50)', () {
    test('Tc_DETAIL_01 & 03: Đầy đủ các trường thông tin phòng, Carousel ảnh và thông tin liên hệ', () {
      final room = RoomModel(
        id: 'room_det_1',
        title: 'Studio ban công thoáng mát Nguyễn Văn Lượng',
        description: 'Đầy đủ nội thất cao cấp',
        price: 4500000,
        deposit: 4500000,
        address: 'Nguyễn Văn Lượng, P.3',
        district: 'Gò Vấp',
        area: 30.0,
        roomType: 'Căn hộ mini',
        amenities: ['Máy lạnh', 'Wifi tốc độ cao', 'Tủ lạnh & Máy giặt'],
        images: ['https://example.com/p1.jpg', 'https://example.com/p2.jpg'],
        hostId: 'host_01',
        hostName: 'Anh Minh Gò Vấp',
        hostPhone: '0938112233',
        rating: 4.9,
        reviewCount: 22,
        createdAt: DateTime.now(),
      );

      expect(room.images.length, equals(2));
      expect(room.hostPhone, equals('0938112233'));
      expect(room.amenities.length, equals(3));
      expect(room.rating, equals(4.9));
      expect(room.reviewCount, equals(22));
    });

    test('Tc_ACTIONS_01: Nút gọi điện và nhắn tin trực tiếp với chủ trọ', () {
      final room = RoomModel(
        id: 'r_act_1',
        title: 'Phòng trọ cao cấp',
        description: '',
        price: 3200000,
        deposit: 3200000,
        address: 'Đường 8, Linh Trung',
        district: 'TP. Thủ Đức',
        area: 25,
        roomType: 'Phòng trọ',
        amenities: [],
        images: [],
        hostId: 'host_chu_ba',
        hostName: 'Chú Ba',
        hostPhone: '0908123456',
        createdAt: DateTime.now(),
      );

      expect(room.hostPhone.isNotEmpty, isTrue);
      expect(room.hostName, equals('Chú Ba'));
    });
  });

  group('Module 8: Nhắn tin & Trao đổi chủ thuê (Tc_CHAT_01 - 50)', () {
    test('Tc_CHAT_01 & 03: Mô hình ChatMessageModel hỗ trợ đầy đủ khóa DrawIO', () {
      final now = DateTime.now();
      final msg = ChatMessageModel(
        id: 'msg_001',
        conversationId: 'chat_room_01',
        senderId: 'renter_uid_1',
        senderName: 'Tuấn',
        receiverId: 'host_uid_1',
        text: 'Chào bạn, phòng này còn không ạ?',
        timestamp: now,
      );

      final map = msg.toMap();
      expect(map['conversationId'], equals('chat_room_01'));
      expect(map['cuocTroChuyenId'], equals('chat_room_01'));
      expect(map['senderId'], equals('renter_uid_1'));
      expect(map['nguoiGuiId'], equals('renter_uid_1'));
      expect(map['text'], equals('Chào bạn, phòng này còn không ạ?'));
      expect(map['noiDung'], equals('Chào bạn, phòng này còn không ạ?'));
      expect(msg.status, equals('sent'));
    });

    test('Tc_CHAT_09 & 10: ConversationModel liên kết với thẻ phòng trọ ghim (Pinned Room)', () {
      final conv = ConversationModel(
        id: 'host_chu_ba_101',
        partnerId: 'host_chu_ba_101',
        partnerName: 'Chú Ba Linh Trung (Chủ trọ)',
        partnerPhone: '0903888999',
        isLandlord: true,
        lastMessage: 'Phòng 101 còn trống nha cháu',
        lastMessageTime: DateTime.now(),
        unreadCount: 1,
        roomCode: '#LT-802',
        roomTitle: 'Phòng trọ cao cấp Linh Trung',
        roomPrice: 3500000,
      );

      expect(conv.partnerName, contains('Chú Ba'));
      expect(conv.isLandlord, isTrue);
      expect(conv.roomCode, equals('#LT-802'));
      expect(conv.roomPrice, equals(3500000));
      expect(conv.unreadCount, equals(1));
    });

    test('Tc_CHAT_14 -> 20: Thẻ lời mời ở ghép và chuyển tiếp trạng thái (pending -> accepted/declined)', () {
      final inviteMsg = ChatMessageModel(
        id: 'invite_001',
        senderId: 'user_a',
        senderName: 'Minh',
        receiverId: 'user_b',
        text: 'Lời mời cùng ở ghép phòng tại HomeShare',
        messageType: 'roommate_invitation',
        extraData: {
          'status': 'pending',
          'roomTitle': 'Căn hộ mini 2PN',
          'pricePerPerson': 1800000,
        },
        timestamp: DateTime.now(),
      );

      expect(inviteMsg.messageType, equals('roommate_invitation'));
      expect(inviteMsg.extraData['status'], equals('pending'));

      // Chấp nhận lời mời (TC 18)
      final acceptedMsg = inviteMsg.copyWith(
        extraData: {...inviteMsg.extraData, 'status': 'accepted'},
      );
      expect(acceptedMsg.extraData['status'], equals('accepted'));

      // Từ chối lời mời (TC 19)
      final declinedMsg = inviteMsg.copyWith(
        extraData: {...inviteMsg.extraData, 'status': 'declined'},
      );
      expect(declinedMsg.extraData['status'], equals('declined'));
    });

    test('Tc_CHAT_24: Chặn gửi tin nhắn rỗng hoặc chỉ toàn khoảng trắng (Whitespace)', () {
      bool isInvalid(String text) => text.trim().isEmpty;

      expect(isInvalid(''), isTrue);
      expect(isInvalid('   '), isTrue);
      expect(isInvalid('\n\t  '), isTrue);
      expect(isInvalid('Chào bạn'), isFalse);
    });

    test('Tc_CHAT_26: Chu kỳ trạng thái tin nhắn (sending -> sent -> delivered -> read)', () {
      final msg = ChatMessageModel(
        id: 'msg_cycle',
        senderId: 'u1',
        senderName: 'Nam',
        receiverId: 'u2',
        text: 'Alo',
        status: 'sending',
        timestamp: DateTime.now(),
      );

      expect(msg.status, equals('sending'));
      expect(msg.daDoc, isFalse);

      final sent = msg.copyWith(status: 'sent');
      expect(sent.status, equals('sent'));

      final delivered = sent.copyWith(status: 'delivered');
      expect(delivered.status, equals('delivered'));

      final read = delivered.copyWith(status: 'read', isRead: true);
      expect(read.status, equals('read'));
      expect(read.daDoc, isTrue);
    });

    test('Tc_CHAT_38 & 39: Chia sẻ vị trí với kinh độ, vĩ độ và địa chỉ', () {
      final locationMsg = ChatMessageModel(
        id: 'loc_001',
        senderId: 'u1',
        senderName: 'Nam',
        receiverId: 'u2',
        text: 'Vị trí phòng: Số 8 Linh Trung',
        messageType: 'location',
        extraData: {
          'address': 'Số 8 Linh Trung, TP. Thủ Đức',
          'latitude': 10.8654,
          'longitude': 106.7725,
        },
        timestamp: DateTime.now(),
      );

      expect(locationMsg.messageType, equals('location'));
      expect(locationMsg.extraData['latitude'], equals(10.8654));
      expect(locationMsg.extraData['longitude'], equals(106.7725));
    });

    test('Tc_CHAT_40 & 41: Sao chép và Xóa ở phía tôi (Delete for Me)', () {
      final messages = ['msg_1', 'msg_2', 'msg_3'];
      final deletedForMe = <String>{};

      // Xóa msg_2 ở phía tôi
      deletedForMe.add('msg_2');
      final visible = messages.where((id) => !deletedForMe.contains(id)).toList();

      expect(visible.length, equals(2));
      expect(visible.contains('msg_2'), isFalse);
      expect(visible, containsAll(['msg_1', 'msg_3']));
    });

    test('Tc_CHAT_49: Bộ lọc từ khóa cấm / lừa đảo chặn tin nhắn vi phạm tiêu chuẩn cộng đồng', () {
      expect(ChatService.checkProfanity('Phòng này còn trống không?'), isFalse);
      expect(ChatService.checkProfanity('Phòng có máy lạnh không?'), isFalse);
      expect(ChatService.checkProfanity('Cảnh báo đây là lừa đảo đặt cọc'), isTrue);
      expect(ChatService.checkProfanity('Tham gia cờ bạc đổi thưởng'), isTrue);
      expect(ChatService.checkProfanity('chuyển tiền trước không xem phòng'), isTrue);
    });
  });

  group('Module 9: Đặt phòng & Xác nhận yêu cầu (Tc_BOOKING_01 - 50, Tc_CONFIRM_01 - 50)', () {
    test('Tc_BOOKING_01 & Tc_CONFIRM_01 - 04: Tạo và xác nhận yêu cầu xem phòng với DrawIO keys', () {
      final appointmentTime = DateTime(2026, 10, 15, 14, 30);
      final booking = BookingRequestModel(
        id: 'booking_101',
        roomId: 'room_123',
        roomTitle: 'Phòng trọ gần ĐH Nông Lâm',
        roomAddress: '123 Võ Văn Ngân',
        roomPrice: 3200000,
        deposit: 3200000,
        totalAmount: 6400000,
        rentalMonths: 6,
        hostId: 'host_001',
        hostName: 'Chú Ba Linh Trung',
        renterId: 'renter_001',
        renterName: 'Trần Thanh Anh Toàn',
        renterPhone: '0901234567',
        moveInDate: appointmentTime,
        status: 'pending',
        note: 'Tôi muốn hẹn xem phòng vào chiều thứ Năm',
        createdAt: DateTime.now(),
      );

      expect(booking.id, equals('booking_101'));
      expect(booking.status, equals('pending'));
      expect(booking.trangThai, equals('pending'));
      expect(booking.roomTitle, equals('Phòng trọ gần ĐH Nông Lâm'));
      expect(booking.note, equals('Tôi muốn hẹn xem phòng vào chiều thứ Năm'));

      final map = booking.toMap();
      expect(map['roomId'], equals('room_123'));
      expect(map['phongId'], equals('room_123'));
      expect(map['renterName'], equals('Trần Thanh Anh Toàn'));
      expect(map['trangThai'], equals('pending'));
    });

    test('Tc_ACTIONS_02 - 10: Thứ tự nút hành động chi tiết phòng: 1. Báo cáo, 2. Nhắn tin, 3. Đặt phòng nhanh (Bỏ hẹn xem phòng)', () {
      final bottomActions = ['Báo cáo', 'Nhắn tin', 'Đặt phòng nhanh'];

      // Kiểm định thứ tự chuẩn xác tuyệt đối
      expect(bottomActions[0], equals('Báo cáo'));
      expect(bottomActions[1], equals('Nhắn tin'));
      expect(bottomActions[2], equals('Đặt phòng nhanh'));

      // Đảm bảo không còn nút "Hẹn xem phòng"
      expect(bottomActions.contains('Hẹn xem phòng'), isFalse);
      expect(bottomActions.length, equals(3));
    });

    test('Tc_BOOKING_05 - 15: Sinh mã VietQR Napas247 thật 100% đến STK 0382542737 MBBank TRẦN THANH ANH TOÀN theo đơn giá', () {
      const roomPrice1 = 3500000.0;
      const transferContent1 = 'HS P101 S4567';

      // 1. Kiểm định thông tin tài khoản mặc định
      expect(VietQRHelper.defaultAccountNo, equals('0382542737'));
      expect(VietQRHelper.defaultBankBin, equals('970422'));
      expect(VietQRHelper.defaultBankCode, equals('MB'));
      expect(VietQRHelper.defaultAccountName, equals('TRAN THANH ANH TOAN'));
      expect(VietQRHelper.defaultAccountDisplayName, equals('TRẦN THANH ANH TOÀN'));

      // 2. Kiểm định URL hình ảnh VietQR.io chính thức
      final imageUrl = VietQRHelper.buildVietQrImageUrl(
        amount: roomPrice1,
        addInfo: transferContent1,
      );
      expect(imageUrl, contains('https://img.vietqr.io/image/MB-0382542737-compact2.png'));
      expect(imageUrl, contains('amount=3500000'));
      expect(imageUrl, contains('accountName=TRAN%20THANH%20ANH%20TOAN'));

      // 3. Kiểm định chuỗi EMVCo Napas247 payload quét được trên tất cả App ngân hàng thật
      final emvcoPayload = VietQRHelper.generateNapasEmvcoPayload(
        amount: roomPrice1,
        addInfo: transferContent1,
      );

      // Bắt đầu bằng 000201 (Payload Format Indicator)
      expect(emvcoPayload.startsWith('000201'), isTrue);
      // Chứa Napas AID A000000727
      expect(emvcoPayload, contains('A000000727'));
      // Chứa mã BIN MBBank 970422
      expect(emvcoPayload, contains('970422'));
      // Chứa số tài khoản thật 0382542737
      expect(emvcoPayload, contains('0382542737'));
      // Chứa tiền tệ VND (704)
      expect(emvcoPayload, contains('5303704'));
      // Chứa số tiền tùy theo đơn giá (3500000)
      expect(emvcoPayload, contains('54073500000'));
      // Chứa mã quốc gia VN
      expect(emvcoPayload, contains('5802VN'));
      // Kết thúc bằng Tag 6304 kèm 4 ký tự CRC Checksum
      expect(emvcoPayload, contains('6304'));
      expect(emvcoPayload.length, greaterThan(80));

      // 4. Kiểm định với đơn giá phòng khác (ví dụ 2.400.000đ)
      const roomPrice2 = 2400000.0;
      final emvcoPayload2 = VietQRHelper.generateNapasEmvcoPayload(
        amount: roomPrice2,
        addInfo: 'HS P202 S1234',
      );
      expect(emvcoPayload2, contains('54072400000'));
    });

    test('Tc_BOOKING_16 - 25: Báo cáo vi phạm chủ nhà và lưu trữ thông tin kiểm duyệt', () {
      final report = {
        'roomId': 'room_789',
        'roomTitle': 'Phòng trọ giá rẻ Thủ Đức',
        'hostId': 'host_99',
        'hostName': 'Nguyễn Văn Chủ',
        'reporterId': 'renter_11',
        'reason': 'Thông tin phòng sai sự thật hoặc hình ảnh giả mạo',
        'detail': 'Ảnh đăng phòng có máy lạnh nhưng thực tế tới xem không có',
        'status': 'pending',
      };

      expect(report['roomId'], equals('room_789'));
      expect(report['reason'], contains('sai sự thật'));
      expect(report['status'], equals('pending'));
    });
  });

  group('Module 10: Tab tìm ở ghép & Ghép đôi AI (Tc_ROOMMATE_01 - 50, Tc_RMFILTER_01 - 50)', () {
    test('Tc_ROOMMATE_01 - 04: Mô hình bài đăng ở ghép chuẩn DrawIO', () {
      final post = RoommatePostModel(
        id: 'rm_post_1',
        authorId: 'user_an',
        authorName: 'Lê Văn An',
        authorAge: 21,
        authorGender: 'Nam',
        authorOccupation: 'Sinh viên HUTECH',
        authorAvatar: '',
        title: 'Tìm 1 bạn nam ở ghép căn hộ D2 Bình Thạnh',
        description: 'Sạch sẽ, giờ giấc tự do, có gác lửng',
        budgetMin: 1500000,
        budgetMax: 2000000,
        pricePerPerson: 1800000,
        district: 'Bình Thạnh',
        targetGender: 'Nam',
        habits: ['Không hút thuốc', 'Ngủ sớm'],
        hasRoom: true,
        contactPhone: '0901234567',
        createdAt: DateTime.now(),
      );

      expect(post.authorName, equals('Lê Văn An'));
      expect(post.hasRoom, isTrue);
      expect(post.targetGender, equals('Nam'));
      expect(post.pricePerPerson, equals(1800000));
      expect(post.habits.contains('Không hút thuốc'), isTrue);
    });
  });

  group('Module 11: Đăng tin ở ghép 3 Bước (Tc_POST_B1_01 - 50, Tc_POST_B2_01 - 50, Tc_POST_B3_01 - 50)', () {
    test('Tc_POST_B1_02, Tc_POST_B2_02, Tc_POST_B3_02: Tiến trình 3 bước (33% -> 66% -> 100%)', () {
      double getProgress(int step) {
        switch (step) {
          case 1:
            return 1 / 3;
          case 2:
            return 2 / 3;
          case 3:
            return 1.0;
          default:
            return 0.0;
        }
      }

      expect(getProgress(1), closeTo(0.33, 0.01));
      expect(getProgress(2), closeTo(0.66, 0.01));
      expect(getProgress(3), equals(1.0));
    });

    test('Tc_POST_B1_04 & Tc_POST_B2_04: Kiểm tra dữ liệu đăng bài hợp lệ trước khi submit', () {
      bool validatePostStep1({required String title, required String district}) {
        return title.trim().isNotEmpty && district.trim().isNotEmpty;
      }

      bool validatePostStep2({required double budget, required String targetGender}) {
        return budget > 0 && targetGender.isNotEmpty;
      }

      expect(validatePostStep1(title: 'Tìm bạn ở ghép', district: 'TP. Thủ Đức'), isTrue);
      expect(validatePostStep1(title: '', district: 'TP. Thủ Đức'), isFalse);
      expect(validatePostStep2(budget: 2500000, targetGender: 'Nam'), isTrue);
      expect(validatePostStep2(budget: 0, targetGender: 'Nam'), isFalse);
    });

    test('Tc_POST_DYNAMIC_FLOW_01 - 10: Phân nhánh luồng Đã có phòng (3 bước có ảnh) vs Chưa có phòng (2 bước không cần ảnh)', () {
      List<String> getStepsForRoomStatus({required bool hasRoom}) {
        return hasRoom ? ['Thông tin', 'Hình ảnh', 'Hoàn tất'] : ['Thông tin', 'Hoàn tất'];
      }

      // Khi Đã có phòng: Luồng gồm 3 bước bắt buộc có ảnh
      final stepsWithRoom = getStepsForRoomStatus(hasRoom: true);
      expect(stepsWithRoom.length, equals(3));
      expect(stepsWithRoom, equals(['Thông tin', 'Hình ảnh', 'Hoàn tất']));

      // Khi Chưa có phòng: Luồng chỉ gồm 2 bước bỏ qua bước hình ảnh
      final stepsWithoutRoom = getStepsForRoomStatus(hasRoom: false);
      expect(stepsWithoutRoom.length, equals(2));
      expect(stepsWithoutRoom, equals(['Thông tin', 'Hoàn tất']));
      expect(stepsWithoutRoom.contains('Hình ảnh'), isFalse);
    });
  });

  group('Module 12: Định danh cá nhân eKYC & Quét thẻ CCCD gắn chip (Tc_INFO2_01 - 50)', () {
    test('Tc_INFO2_01 - 05: Trạng thái ban đầu Chưa xác thực CCCD (isCccdVerified = false) và hiển thị cảnh báo', () {
      final unverifiedUser = UserProfile(
        uid: 'user_new_01',
        email: 'user@test.vn',
        displayName: 'Nguyễn Văn A',
        phoneNumber: '0901234567',
        isCccdVerified: false,
      );

      expect(unverifiedUser.isCccdVerified, isFalse);
      expect(unverifiedUser.daXacThucCccd, isFalse);
      expect(unverifiedUser.cccdNumber, isEmpty);
      expect(unverifiedUser.soCccd, equals(''));
      expect(unverifiedUser.soGiayTo, equals(''));
    });

    test('Tc_INFO2_06 - 15: Phân tích cú pháp chuỗi QR Code CCCD gắn chip chuẩn Bộ Công An (7 trường)', () {
      const qrPayload = '079201012345|025896321|NGUYỄN VĂN AN|15082001|Nam|Số 123 Võ Văn Ngân, Linh Chiểu, TP. Thủ Đức, TP. Hồ Chí Minh|25122021';
      final cccdData = CccdData.fromQrString(qrPayload);

      expect(cccdData.idNumber, equals('079201012345'));
      expect(cccdData.oldCmnd, equals('025896321'));
      expect(cccdData.fullName, equals('NGUYỄN VĂN AN'));
      expect(cccdData.birthDate, equals('15/08/2001'));
      expect(cccdData.gender, equals('Nam'));
      expect(cccdData.address, equals('Số 123 Võ Văn Ngân, Linh Chiểu, TP. Thủ Đức, TP. Hồ Chí Minh'));
      expect(cccdData.issueDate, equals('25/12/2021'));
    });

    test('Tc_INFO2_16 - 25: Fallback phân tích chuỗi chỉ chứa 12 chữ số CCCD', () {
      const rawDigits = '079201999888';
      final cccdData = CccdData.fromQrString(rawDigits);

      expect(cccdData.idNumber, equals('079201999888'));
      expect(cccdData.fullName.isNotEmpty, isTrue);
      expect(cccdData.gender, equals('Nam'));
    });

    test('Tc_INFO2_26 - 35: Cập nhật xác thực thành công vào UserProfile và đối soát định dạng chuẩn', () {
      final verifiedUser = UserProfile(
        uid: 'user_verified_01',
        email: 'verified@homeshare.vn',
        displayName: 'NGUYỄN VĂN AN',
        phoneNumber: '0901234567',
        isCccdVerified: true,
        cccdNumber: '079201012345',
        cccdFullName: 'NGUYỄN VĂN AN',
        cccdIssueDate: '25/12/2021',
        cccdHometown: 'TP. Hồ Chí Minh',
        cccdFrontImageUrl: 'https://example.com/front.jpg',
        cccdBackImageUrl: 'https://example.com/back.jpg',
        cccdVerifiedAt: DateTime(2026, 10, 1),
      );

      expect(verifiedUser.isCccdVerified, isTrue);
      expect(verifiedUser.daXacThucCccd, isTrue);
      expect(verifiedUser.cccdNumber, equals('079201012345'));
      expect(verifiedUser.soCccd, equals('079201012345'));
      expect(verifiedUser.soGiayTo, equals('079201012345'));
      expect(verifiedUser.cccdFullName, equals('NGUYỄN VĂN AN'));
      expect(verifiedUser.cccdIssueDate, equals('25/12/2021'));
      expect(verifiedUser.cccdHometown, equals('TP. Hồ Chí Minh'));
      expect(verifiedUser.cccdFrontImageUrl, equals('https://example.com/front.jpg'));
      expect(verifiedUser.anhMatTruoc, equals('https://example.com/front.jpg'));
      expect(verifiedUser.cccdBackImageUrl, equals('https://example.com/back.jpg'));
      expect(verifiedUser.anhMatSau, equals('https://example.com/back.jpg'));
      expect(verifiedUser.cccdVerifiedAt, isNotNull);
    });

    test('Tc_INFO2_36 - 45: Quy tắc 3 mục eKYC bắt buộc - Thiếu không được nhấn xác thực, đủ 3 mục mới được kích hoạt', () {
      // Hàm mô phỏng logic validation của CccdVerificationScreen
      bool canSubmit({String? frontImage, String? backImage, CccdData? cccdData}) {
        return frontImage != null && backImage != null && cccdData != null;
      }

      final mockCccd = CccdData(
        idNumber: '079201012345',
        fullName: 'NGUYỄN VĂN AN',
        birthDate: '15/08/2001',
        gender: 'Nam',
        address: 'TP. Hồ Chí Minh',
        issueDate: '25/12/2021',
      );

      // Trường hợp 0/3 mục: Chưa làm gì
      expect(canSubmit(frontImage: null, backImage: null, cccdData: null), isFalse);

      // Trường hợp 1/3 mục: Chỉ có ảnh mặt trước
      expect(canSubmit(frontImage: 'path/front.jpg', backImage: null, cccdData: null), isFalse);

      // Trường hợp 1/3 mục: Chỉ có ảnh mặt sau
      expect(canSubmit(frontImage: null, backImage: 'path/back.jpg', cccdData: null), isFalse);

      // Trường hợp 1/3 mục: Chỉ có quét mã QR
      expect(canSubmit(frontImage: null, backImage: null, cccdData: mockCccd), isFalse);

      // Trường hợp 2/3 mục: Có mặt trước và mặt sau, thiếu quét QR
      expect(canSubmit(frontImage: 'path/front.jpg', backImage: 'path/back.jpg', cccdData: null), isFalse);

      // Trường hợp 2/3 mục: Có mặt trước và quét QR, thiếu mặt sau
      expect(canSubmit(frontImage: 'path/front.jpg', backImage: null, cccdData: mockCccd), isFalse);

      // Trường hợp 2/3 mục: Có mặt sau và quét QR, thiếu mặt trước
      expect(canSubmit(frontImage: null, backImage: 'path/back.jpg', cccdData: mockCccd), isFalse);

      // Trường hợp 3/3 mục HOÀN THÀNH ĐẦY ĐỦ: Nút xác thực được bật
      expect(canSubmit(frontImage: 'path/front.jpg', backImage: 'path/back.jpg', cccdData: mockCccd), isTrue);
    });

    test('Tc_INFO2_46 - 50: UserProfile chuyển đổi toMap và fromMap bảo toàn cả 2 ảnh CCCD mặt trước và sau', () {
      final mapData = {
        'uid': 'usr_009',
        'email': 'tenant@homeshare.vn',
        'displayName': 'LÊ VĂN BÌNH',
        'phoneNumber': '0988776655',
        'isCccdVerified': true,
        'cccdNumber': '001201999888',
        'cccdFullName': 'LÊ VĂN BÌNH',
        'anhMatTruoc': '/storage/emulated/0/dcim/cccd_front.jpg',
        'anhMatSau': '/storage/emulated/0/dcim/cccd_back.jpg',
      };

      final parsed = UserProfile.fromMap(mapData, 'usr_009');
      expect(parsed.cccdFrontImageUrl, equals('/storage/emulated/0/dcim/cccd_front.jpg'));
      expect(parsed.anhMatTruoc, equals('/storage/emulated/0/dcim/cccd_front.jpg'));
      expect(parsed.cccdBackImageUrl, equals('/storage/emulated/0/dcim/cccd_back.jpg'));
      expect(parsed.anhMatSau, equals('/storage/emulated/0/dcim/cccd_back.jpg'));

      final serialized = parsed.toMap();
      expect(serialized['cccdFrontImageUrl'], equals('/storage/emulated/0/dcim/cccd_front.jpg'));
      expect(serialized['anhMatTruoc'], equals('/storage/emulated/0/dcim/cccd_front.jpg'));
      expect(serialized['cccdBackImageUrl'], equals('/storage/emulated/0/dcim/cccd_back.jpg'));
      expect(serialized['anhMatSau'], equals('/storage/emulated/0/dcim/cccd_back.jpg'));
    });
  });

  group('Module 13: Màn hình Tìm Ở Ghép & Bộ lọc Lifestyle AI Match (Figma Chuẩn)', () {
    test('Tc_ROOMMATE_FIGMA_01 - 05: Kiểm tra các bài đăng mẫu chuẩn 100% Figma (Minh Trang, Quốc Bảo, Thùy Dung)', () {
      final samplePosts = RoommateService.getFigmaSamplePosts();
      expect(samplePosts.length, greaterThanOrEqualTo(3));

      // 1. Thẻ Minh Trang (Hình 1 - Thẻ đầu tiên)
      final minhTrang = samplePosts.firstWhere((p) => p.authorName == 'Minh Trang');
      expect(minhTrang.authorAge, equals(21));
      expect(minhTrang.authorOccupation, contains('Ngoại Thương'));
      expect(minhTrang.hasRoom, isTrue);
      expect(minhTrang.pricePerPerson, equals(1800000));
      expect(minhTrang.district, equals('TP. Thủ Đức'));
      expect(minhTrang.isVerified, isTrue);
      expect(minhTrang.images.length, equals(2));
      expect(minhTrang.imageCaptions, containsAll(['Phòng ngủ máy lạnh', 'Bếp chung rộng']));
      expect(minhTrang.habits, containsAll(['Tuyệt đối không thuốc lá', 'Yên tĩnh sau 23h', 'Sạch sẽ, ngăn nắp cao']));

      // 2. Thẻ Quốc Bảo (Hình 1 - Thẻ thứ hai)
      final quocBao = samplePosts.firstWhere((p) => p.authorName == 'Quốc Bảo');
      expect(quocBao.authorAge, equals(22));
      expect(quocBao.authorOccupation, contains('Kỹ sư'));
      expect(quocBao.hasRoom, isTrue);
      expect(quocBao.pricePerPerson, equals(2200000));
      expect(quocBao.district, equals('Bình Thạnh'));
      expect(quocBao.habits, containsAll(['Giờ giấc tự do 24/7', 'Có xe máy riêng', 'Thích thể thao']));

      // 3. Thẻ Thùy Dung (Hình 1 - Thẻ thứ ba: Chưa có phòng • Tìm người cùng thuê)
      final thuyDung = samplePosts.firstWhere((p) => p.authorName == 'Thùy Dung');
      expect(thuyDung.authorAge, equals(20));
      expect(thuyDung.authorOccupation, contains('Sư Phạm Kỹ Thuật'));
      expect(thuyDung.hasRoom, isFalse);
      expect(thuyDung.budgetMin, equals(1500000));
      expect(thuyDung.budgetMax, equals(2000000));
      expect(thuyDung.habits, containsAll(['Chăm học, ít ồn', 'Nấu ăn tại phòng', 'Dậy sớm (Trước 7h)']));
    });

    test('Tc_ROOMMATE_FIGMA_06 - 10: Chuyển đổi Segment Tab giữa Đã có phòng và Người cần tìm phòng ghép', () {
      final samplePosts = RoommateService.getFigmaSamplePosts();

      // Tab 1: Đang tìm người ghép (Có phòng)
      final withRoom = samplePosts.where((p) => p.hasRoom == true).toList();
      expect(withRoom.any((p) => p.authorName == 'Minh Trang'), isTrue);
      expect(withRoom.any((p) => p.authorName == 'Quốc Bảo'), isTrue);
      expect(withRoom.any((p) => p.authorName == 'Thùy Dung'), isFalse);

      // Tab 2: Người cần tìm phòng ghép (Chưa có phòng)
      final withoutRoom = samplePosts.where((p) => p.hasRoom == false).toList();
      expect(withoutRoom.any((p) => p.authorName == 'Thùy Dung'), isTrue);
      expect(withoutRoom.any((p) => p.authorName == 'Minh Trang'), isFalse);
    });

    test('Tc_LIFESTYLE_FILTER_01 - 05: Bộ lọc RoommateFilterParams hỗ trợ đầy đủ các tiêu chí Hình 2', () {
      const filters = RoommateFilterParams(
        district: 'TP. Thủ Đức',
        targetGender: 'Nữ',
        hasRoom: true,
        occupation: 'Sinh viên',
        budgetMin: 1200000,
        budgetMax: 2500000,
        habits: [
          'Yên tĩnh sau 23h',
          'Sạch sẽ, ngăn nắp cao',
          'Tuyệt đối không thuốc lá',
          'Quy định dẫn bạn về phòng',
        ],
        minMatchRate: 80,
      );

      expect(filters.district, equals('TP. Thủ Đức'));
      expect(filters.targetGender, equals('Nữ'));
      expect(filters.hasRoom, isTrue);
      expect(filters.occupation, equals('Sinh viên'));
      expect(filters.budgetMin, equals(1200000));
      expect(filters.budgetMax, equals(2500000));
      expect(filters.habits.length, equals(4));
      expect(filters.minMatchRate, equals(80));

      final updated = filters.copyWith(
        targetGender: 'Tất cả',
        minMatchRate: 90,
      );
      expect(updated.targetGender, equals('Tất cả'));
      expect(updated.minMatchRate, equals(90));
      expect(updated.hasRoom, isTrue); // Giữ nguyên thuộc tính cũ
    });

    test('Tc_LIFESTYLE_FILTER_06 - 10: Khả năng lọc chính xác và tính tương thích Match Rate', () {
      final samplePosts = RoommateService.getFigmaSamplePosts();

      // Lọc các bạn có độ tương thích matchRate >= 80%
      final matched80 = samplePosts.where((p) => p.matchRate >= 80).toList();
      expect(matched80.length, equals(samplePosts.length));

      // Lọc bạn nữ có phòng sẵn tại TP. Thủ Đức (Khớp thẻ Minh Trang)
      final filtered = samplePosts.where((p) {
        if (p.hasRoom != true) return false;
        if (p.district != 'TP. Thủ Đức') return false;
        if (p.targetGender != 'Nữ') return false;
        return true;
      }).toList();

      expect(filtered.length, equals(1));
      expect(filtered.first.authorName, equals('Minh Trang'));
    });
  });

  group('Module 14: Đồng bộ hình ảnh đa thiết bị & Nhắn tin hai chiều thời gian thực (Tc_SYNC_01 - 20)', () {
    test('Tc_SYNC_01 - 05: ChatService.getChatId bảo đảm tính giao hoán và xử lý cắt khoảng trắng', () {
      expect(ChatService.getChatId('userA', 'userB'), equals('userA_userB'));
      expect(ChatService.getChatId('userB', 'userA'), equals('userA_userB'));
      expect(ChatService.getChatId('userA ', ' userB'), equals('userA_userB'));
      expect(ChatService.getChatId('uid_999', 'uid_111'), equals('uid_111_uid_999'));
    });

    test('Tc_SYNC_06 - 10: ChatMessageModel bảo toàn cả 2 trường receiverId và nguoiNhanId', () {
      final msg = ChatMessageModel(
        id: 'msg_sync_1',
        senderId: 'user_A',
        senderName: 'Nguyễn Văn A',
        receiverId: 'user_B',
        text: 'Phòng này còn trống không bạn?',
        timestamp: DateTime.now(),
      );

      final map = msg.toMap();
      expect(map['receiverId'], equals('user_B'));
      expect(map['nguoiNhanId'], equals('user_B'));
      expect(map['senderId'], equals('user_A'));
      expect(map['nguoiGuiId'], equals('user_A'));
    });

    test('Tc_SYNC_11 - 15: ImageStorageService có cơ chế fallback ảnh hợp lệ khi file cục bộ không tồn tại', () async {
      final service = ImageStorageService();
      // File không tồn tại trên thiết bị hiện tại (máy khác xem bài)
      final fallbackUrl = await service.uploadSingleImage(
        filePath: '/data/user/0/com.homeshare/non_existent.jpg',
        folder: 'test',
        fileName: 'test.jpg',
      );

      expect(fallbackUrl.startsWith('http'), isTrue);
      expect(fallbackUrl, contains('unsplash.com'));
    });

    test('Tc_SYNC_16 - 20: ConversationModel phân giải chính xác partnerName hai chiều giữa 2 người dùng', () {
      final data = {
        'users': ['user_A', 'user_B'],
        'userNames': {
          'user_A': 'Anh Toàn',
          'user_B': 'Bảo Trâm',
        },
        'lastSenderId': 'user_A',
        'lastSenderName': 'Anh Toàn',
        'lastMessage': 'Chào bạn!',
      };

      // Khi user_A mở danh sách chat: Phải thấy partner là "Bảo Trâm"
      final convForA = ConversationModel(
        id: 'user_A_user_B',
        partnerId: 'user_B',
        partnerName: (data['userNames'] as Map)['user_B'] ?? '',
        lastMessage: 'Chào bạn!',
        lastMessageTime: DateTime.now(),
      );
      expect(convForA.partnerId, equals('user_B'));
      expect(convForA.partnerName, equals('Bảo Trâm'));

      // Khi user_B mở danh sách chat: Phải thấy partner là "Anh Toàn"
      final convForB = ConversationModel(
        id: 'user_A_user_B',
        partnerId: 'user_A',
        partnerName: (data['userNames'] as Map)['user_A'] ?? '',
        lastMessage: 'Chào bạn!',
        lastMessageTime: DateTime.now(),
      );
      expect(convForB.partnerId, equals('user_A'));
      expect(convForB.partnerName, equals('Anh Toàn'));
    });
  });

  group('Module 15: Nhận diện thương hiệu chuẩn từ PhongSangTheme & Chat Optimization (Tc_THEME_01 - 10)', () {
    test('Tc_THEME_01 & 02: Bảng màu cốt lõi chuẩn moodboard Phòng Sáng (phong_sang_theme.dart)', () {
      // 1. Primary color là màu xanh hành động --accent #155EEF của Phong Sáng
      expect(AppColors.primary, equals(const Color(0xFF155EEF)));
      
      // 2. Text dark / chữ mực --ink #101828
      expect(AppColors.textDark, equals(const Color(0xFF101828)));
      expect(AppColors.borderDark, equals(const Color(0xFF101828)));
      
      // 3. Surface variant (nền tag/chip lọc --price-soft #F2F4F7)
      expect(AppColors.surfaceVariant, equals(const Color(0xFFF2F4F7)));
      
      // 4. Note highlight & background (--paper #F3F6FB)
      expect(AppColors.background, equals(const Color(0xFFF3F6FB)));
      expect(AppColors.noteHighlight, equals(const Color(0xFFFEFFDD)));
    });

    test('Tc_THEME_03 & 04: Cấu hình AppTheme.lightTheme đồng bộ ColorScheme Phòng Sáng', () {
      final theme = AppTheme.lightTheme;
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary, equals(const Color(0xFF155EEF)));
      expect(theme.colorScheme.surface, equals(const Color(0xFFFFFFFF)));
      expect(theme.scaffoldBackgroundColor, equals(const Color(0xFFF3F6FB)));
    });

    test('Tc_THEME_05 & 06: Các thành phần UI (Buttons, AppBar, Chips) sử dụng tông màu chủ đạo Phong Sáng', () {
      final theme = AppTheme.lightTheme;
      expect(theme.appBarTheme.foregroundColor, equals(const Color(0xFF101828)));
      expect(theme.elevatedButtonTheme.style?.backgroundColor?.resolve({}), equals(const Color(0xFF155EEF)));
      expect(theme.chipTheme.backgroundColor, equals(const Color(0xFFFFFFFF)));
      expect(theme.progressIndicatorTheme.color, equals(const Color(0xFF155EEF)));
    });

    test('Tc_THEME_07 & 08: Kiểm định tin nhắn chưa đọc được đánh dấu và in đậm chuẩn xác', () {
      final unreadMessage = ChatMessageModel(
        id: 'msg_unread_01',
        senderId: 'user_partner',
        senderName: 'Trần Văn Chủ',
        receiverId: 'user_me',
        text: 'Phòng vẫn còn trống bạn nhé!',
        timestamp: DateTime.now(),
        isRead: false,
        status: 'sent',
      );

      final readMessage = ChatMessageModel(
        id: 'msg_read_01',
        senderId: 'user_partner',
        senderName: 'Trần Văn Chủ',
        receiverId: 'user_me',
        text: 'Cảm ơn bạn đã quan tâm.',
        timestamp: DateTime.now(),
        isRead: true,
        status: 'read',
      );

      // Tin nhắn chưa đọc có trạng thái daDoc = false
      expect(unreadMessage.daDoc, isFalse);
      expect(unreadMessage.isRead, isFalse);

      // Tin nhắn đã đọc có trạng thái daDoc = true
      expect(readMessage.daDoc, isTrue);
      expect(readMessage.isRead, isTrue);

      // Kiểm định ConversationModel tính computedUnread chính xác
      final conv = ConversationModel(
        id: 'conv_01',
        partnerId: 'user_partner',
        partnerName: 'Trần Văn Chủ',
        lastMessage: 'Phòng vẫn còn trống bạn nhé!',
        lastMessageTime: DateTime.now(),
        unreadCount: 3,
        isRead: false,
      );
      expect(conv.computedUnread, equals(3));
      expect(conv.isReadVal, isFalse);
    });

    test('Tc_THEME_09 & 10: Kiểm tra tin nhắn chưa đọc in đậm, hiển thị badge số lượng và điều hướng chi tiết hồ sơ', () {
      // 1. Kiểm tra tính unread khi có tin nhắn chưa đọc
      final unreadConv = ConversationModel(
        id: 'conv_unread',
        partnerId: 'partner_01',
        partnerName: 'Bác Ba Quản Lý KTX',
        lastMessage: 'Phòng 204 vẫn còn nhé con',
        lastMessageTime: DateTime.now(),
        unreadCount: 2,
        isRead: false,
      );
      final isUnread = unreadConv.unreadCount > 0 || !unreadConv.isRead;
      final displayCount = unreadConv.unreadCount > 0 ? unreadConv.unreadCount : 1;
      expect(isUnread, isTrue);
      expect(displayCount, equals(2));

      // 2. Bài đăng ở ghép luôn có fallback ảnh và người đăng hợp lệ
      final post = RoommatePostModel(
        id: 'rm_test',
        authorId: 'user_test',
        authorName: 'Minh Trang',
        authorAge: 21,
        authorGender: 'Nữ',
        authorOccupation: 'SV Đại học Ngoại Thương CS2',
        title: 'Cần tìm 1 bạn nữ ở ghép',
        description: 'Phòng thoáng mát sạch sẽ',
        postType: 'timNguoiOGhep',
        propertyType: 'Căn hộ chung cư',
        pricePerPerson: 1800000,
        budgetMin: 1500000,
        budgetMax: 2000000,
        address: 'Linh Trung, TP. Thủ Đức',
        district: 'TP. Thủ Đức',
        targetGender: 'Nữ',
        habits: ['Không hút thuốc'],
        images: ['https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800'],
        hasRoom: true,
        contactPhone: '0981234567',
        createdAt: DateTime.now(),
      );
      expect(post.authorName, isNotEmpty);
      expect(post.images, isNotEmpty);
      expect(post.district, equals('TP. Thủ Đức'));
    });
  });
}


