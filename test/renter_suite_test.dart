import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:home_share/data/models/room_model.dart';
import 'package:home_share/data/models/roommate_post_model.dart';
import 'package:home_share/data/models/booking_model.dart';
import 'package:home_share/data/models/chat_model.dart';
import 'package:home_share/core/services/room_service.dart';
import 'package:home_share/core/services/roommate_service.dart';
import 'package:home_share/core/services/chat_service.dart';
import 'package:home_share/features/auth/providers/user_provider.dart';
import 'package:home_share/core/constants/vietnam_locations.dart';

void main() {
  group('RoomModel Tests', () {
    test('RoomModel creates and serializes correctly', () {
      final now = DateTime(2026, 10, 1, 10, 0);
      final room = RoomModel(
        id: 'room_123',
        title: 'Phòng trọ cao cấp trung tâm Thủ Đức',
        description: 'Đầy đủ nội thất, giờ giấc tự do, có gác lửng',
        price: 3500000,
        deposit: 3500000,
        area: 25.0,
        address: '123 Võ Văn Ngân, Linh Chiểu',
        district: 'TP. Thủ Đức',
        roomType: 'Phòng trọ',
        images: ['https://images.unsplash.com/photo-1'],
        amenities: ['wifi', 'air_conditioner', 'parking'],
        hostId: 'host_001',
        hostName: 'Nguyễn Văn Chủ',
        hostPhone: '0901234567',
        isAvailable: true,
        createdAt: now,
      );

      expect(room.id, equals('room_123'));
      expect(room.price, equals(3500000));
      expect(room.deposit, equals(3500000));
      expect(room.amenities.length, equals(3));
      expect(room.isAvailable, isTrue);

      final map = room.toMap();
      expect(map['title'], equals('Phòng trọ cao cấp trung tâm Thủ Đức'));
      expect(map['tieuDe'], equals('Phòng trọ cao cấp trung tâm Thủ Đức'));
      expect(map['price'], equals(3500000));
      expect(map['giaThueThang'], equals(3500000));
      expect(map['district'], equals('TP. Thủ Đức'));
      expect(map['quanHuyen'], equals('TP. Thủ Đức'));
      expect(map['isAvailable'], isTrue);
    });

    test('RoomModel fromMap parses DrawIO Vietnamese schema keys correctly', () {
      final data = {
        'tieuDe': 'Căn hộ Studio mini',
        'moTa': 'Ban công thoáng mát',
        'giaThueThang': 4200000,
        'tienCoc': 4200000,
        'dienTichM2': 30,
        'diaChi': 'D2 Bình Thạnh',
        'quanHuyen': 'Bình Thạnh',
        'loaiPhong': 'Căn hộ mini',
        'anhPhong': ['https://example.com/pic1.jpg'],
        'tienIch': ['wifi', 'parking'],
        'chuNhaId': 'host_999',
        'tenChuNha': 'Trần Thị Chủ',
        'soDienThoai': '0987654321',
        'soSaoTrungBinh': 4.9,
        'sucChua': 3,
        'tang': 2,
        'trangThai': 'conPhong',
        'ngayTao': Timestamp.now(),
      };

      final room = RoomModel.fromMap(data, 'room_abc');
      expect(room.id, equals('room_abc'));
      expect(room.title, equals('Căn hộ Studio mini'));
      expect(room.tieuDe, equals('Căn hộ Studio mini'));
      expect(room.price, equals(4200000.0));
      expect(room.giaThueThang, equals(4200000.0));
      expect(room.area, equals(30.0));
      expect(room.dienTichM2, equals(30.0));
      expect(room.district, equals('Bình Thạnh'));
      expect(room.quanHuyen, equals('Bình Thạnh'));
      expect(room.rating, equals(4.9));
      expect(room.capacity, equals(3));
      expect(room.floor, equals(2));
      expect(room.isAvailable, isTrue);
      expect(room.amenities.contains('wifi'), isTrue);
    });
  });

  group('RoommatePostModel Tests', () {
    test('RoommatePostModel creates and converts toMap with DrawIO keys', () {
      final post = RoommatePostModel(
        id: 'post_01',
        authorId: 'user_renter_1',
        authorName: 'Lê Văn An',
        authorAge: 21,
        authorGender: 'Nam',
        authorOccupation: 'Sinh viên HUTECH',
        authorAvatar: '',
        title: 'Tìm bạn nam ở ghép phòng gần HUTECH',
        description: 'Phòng rộng 30m2, chi phí chia đôi tầm 2tr/tháng',
        budgetMin: 1500000,
        budgetMax: 2000000,
        pricePerPerson: 1800000,
        district: 'Bình Thạnh',
        targetGender: 'Nam',
        habits: ['Không hút thuốc', 'Ngủ trước 12h'],
        hasRoom: true,
        contactPhone: '0901234567',
        createdAt: DateTime.now(),
      );

      final map = post.toMap();
      expect(map['authorName'], equals('Lê Văn An'));
      expect(map['tieuDe'], equals('Tìm bạn nam ở ghép phòng gần HUTECH'));
      expect(map['gioiTinhMongMuon'], equals('Nam'));
      expect(map['hasRoom'], isTrue);
      expect(map['giaMoiNguoi'], equals(1800000));
      expect(map['nganSachDen'], equals(2000000));
      expect(map['thoiQuen'], contains('Không hút thuốc'));
    });

    test('RoommatePostModel fromMap parses DrawIO Vietnamese keys', () {
      final data = {
        'nguoiDangId': 'u_viet_10',
        'hoTen': 'Võ Thị B',
        'tuoi': 22,
        'gioiTinh': 'Nữ',
        'ngheNghiep': 'Thiết kế đồ họa',
        'tieuDe': 'Tìm bạn nữ ở ghép căn hộ 2PN',
        'noiDung': 'Phòng khép kín sạch sẽ',
        'loaiTin': 'timNguoiOGhep',
        'giaMoiNguoi': 2000000,
        'nganSachTu': 1500000,
        'nganSachDen': 2500000,
        'diaChi': '10 Mai Chí Thọ',
        'quanHuyen': 'TP. Thủ Đức',
        'gioiTinhMongMuon': 'Nữ',
        'thoiQuen': ['Thích yên tĩnh', 'Giữ vệ sinh chung'],
        'anhTinOGhep': ['https://pic.jpg'],
        'trangThai': 'dangMo',
        'soDienThoai': '0912345678',
        'ngayTao': Timestamp.now(),
      };

      final post = RoommatePostModel.fromMap(data, 'post_drawio');
      expect(post.authorId, equals('u_viet_10'));
      expect(post.authorName, equals('Võ Thị B'));
      expect(post.authorAge, equals(22));
      expect(post.title, equals('Tìm bạn nữ ở ghép căn hộ 2PN'));
      expect(post.tieuDe, equals('Tìm bạn nữ ở ghép căn hộ 2PN'));
      expect(post.description, equals('Phòng khép kín sạch sẽ'));
      expect(post.pricePerPerson, equals(2000000.0));
      expect(post.targetGender, equals('Nữ'));
      expect(post.hasRoom, isTrue);
      expect(post.habits.length, equals(2));
      expect(post.contactPhone, equals('0912345678'));
    });
  });

  group('BookingModel Tests', () {
    test('BookingRequestModel initializes and maps status correctly', () {
      final booking = BookingRequestModel(
        id: 'book_100',
        roomId: 'room_123',
        roomTitle: 'Phòng trọ cao cấp',
        roomAddress: '123 Võ Văn Ngân',
        roomPrice: 3500000,
        deposit: 3500000,
        totalAmount: 7000000,
        rentalMonths: 6,
        hostId: 'host_001',
        hostName: 'Nguyễn Văn Chủ',
        renterId: 'renter_999',
        renterName: 'Nguyễn Văn Thuê',
        renterPhone: '0912345678',
        moveInDate: DateTime(2026, 10, 5, 9, 30),
        note: 'Tôi muốn qua xem phòng vào sáng thứ 2',
        status: 'pending',
        createdAt: DateTime.now(),
      );

      expect(booking.status, equals('pending'));
      expect(booking.roomPrice, equals(3500000));
      expect(booking.deposit, equals(3500000));
      expect(booking.totalAmount, equals(7000000));
      expect(booking.rentalMonths, equals(6));

      final map = booking.toMap();
      expect(map['renterName'], equals('Nguyễn Văn Thuê'));
      expect(map['tenNguoiO'], equals('Nguyễn Văn Thuê'));
      expect(map['tongPhaiTra'], equals(7000000));
      expect(map['soThangThue'], equals(6));
      expect(map['status'], equals('pending'));
      expect(map['hostName'], equals('Nguyễn Văn Chủ'));
    });

    test('BookingRequestModel fromMap parses DrawIO keys correctly', () {
      final data = {
        'nguoiDung_Id': 'r_01',
        'tenNguoiO': 'Trần Văn C',
        'sdtNguoiO': '0933333333',
        'phongId': 'room_456',
        'tieuDePhong': 'Căn hộ Riverpark',
        'diaChiPhong': 'Thảo Điền, TP. Thủ Đức',
        'giaThue': 6000000,
        'tienCoc': 6000000,
        'tongPhaiTra': 12000000,
        'soThangThue': 12,
        'chuNhaId': 'h_02',
        'tenChuNha': 'Bác Ba',
        'trangThai': 'daDuyet',
        'ngayVao': Timestamp.now(),
        'ghiChu': 'Hẹn gặp lúc 10h',
        'ngayTao': Timestamp.now(),
      };

      final booking = BookingRequestModel.fromMap(data, 'book_456');
      expect(booking.id, equals('book_456'));
      expect(booking.renterId, equals('r_01'));
      expect(booking.renterName, equals('Trần Văn C'));
      expect(booking.tenNguoiO, equals('Trần Văn C'));
      expect(booking.status, equals('daDuyet'));
      expect(booking.roomPrice, equals(6000000.0));
      expect(booking.deposit, equals(6000000.0));
      expect(booking.totalAmount, equals(12000000.0));
      expect(booking.rentalMonths, equals(12));
      expect(booking.hostName, equals('Bác Ba'));
      expect(booking.note, equals('Hẹn gặp lúc 10h'));
    });
  });

  group('ChatMessageModel Tests', () {
    test('ChatMessageModel serializes text message and parses with DrawIO keys', () {
      final msg = ChatMessageModel(
        id: 'msg_01',
        conversationId: 'chat_ab',
        senderId: 'user_a',
        senderName: 'Tuấn',
        receiverId: 'user_b',
        text: 'Chào bạn, phòng còn không ạ?',
        timestamp: DateTime(2026, 10, 1, 8, 0),
        isRead: false,
      );

      final map = msg.toMap();
      expect(map['senderId'], equals('user_a'));
      expect(map['nguoiGuiId'], equals('user_a'));
      expect(map['text'], equals('Chào bạn, phòng còn không ạ?'));
      expect(map['noiDung'], equals('Chào bạn, phòng còn không ạ?'));
      expect(map['isRead'], isFalse);

      final parsed = ChatMessageModel.fromMap({
        'cuocTroChuyenId': 'chat_ab',
        'nguoiGuiId': 'user_a',
        'tenNguoiGui': 'Tuấn',
        'nguoiNhanId': 'user_b',
        'noiDung': 'Chào bạn, phòng còn không ạ?',
        'ngayGui': Timestamp.fromDate(DateTime(2026, 10, 1, 8, 0)),
        'trangThaiTinNhan_id': 'daDoc',
      }, 'msg_01');

      expect(parsed.isRead, isTrue);
      expect(parsed.noiDung, equals('Chào bạn, phòng còn không ạ?'));
      expect(parsed.senderName, equals('Tuấn'));
      expect(parsed.cuocTroChuyenId, equals('chat_ab'));
    });
  });

  group('UserProfile Tests', () {
    test('UserProfile parses from DrawIO keys and enforces renter role', () {
      final data = {
        'hoTen': 'Nguyễn Văn Thuê',
        'email': 'thue@gmail.com',
        'soDienThoai': '0988888888',
        'gioiTinh': 'Nam',
        'diaChi': 'Linh Trung, Thủ Đức',
        'queQuan': 'Đồng Nai',
        'diemUyTin': 100,
        'ngheNghiep': 'Kỹ sư phần mềm',
        'soThich': ['Đọc sách', 'Thể thao'],
      };

      final profile = UserProfile.fromMap(data, 'u_user_99');
      expect(profile.uid, equals('u_user_99'));
      expect(profile.displayName, equals('Nguyễn Văn Thuê'));
      expect(profile.hoTen, equals('Nguyễn Văn Thuê'));
      expect(profile.phoneNumber, equals('0988888888'));
      expect(profile.role, equals('renter'));
      expect(profile.gender, equals('Nam'));
      expect(profile.reputationScore, equals(100));
      expect(profile.occupation, equals('Kỹ sư phần mềm'));
      expect(profile.hobbies, contains('Đọc sách'));
    });
  });

  group('FilterParams & Riverpod Equality Tests', () {
    test('RoomFilterParams equality and hashCode work correctly', () {
      const p1 = RoomFilterParams(district: 'Bình Thạnh', roomType: 'Phòng trọ', maxPrice: 3000000);
      const p2 = RoomFilterParams(district: 'Bình Thạnh', roomType: 'Phòng trọ', maxPrice: 3000000);
      const p3 = RoomFilterParams(district: 'TP. Thủ Đức', roomType: 'Phòng trọ', maxPrice: 3000000);

      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1 == p3, isFalse);
    });

    test('RoommateFilterParams equality and hashCode work correctly', () {
      const p1 = RoommateFilterParams(district: 'TP. Thủ Đức', targetGender: 'Nam');
      const p2 = RoommateFilterParams(district: 'TP. Thủ Đức', targetGender: 'Nam');
      const p3 = RoommateFilterParams(district: 'TP. Thủ Đức', targetGender: 'Nữ');

      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1 == p3, isFalse);
    });

    test('ChatParams equality and hashCode work correctly', () {
      const p1 = ChatParams(userA: 'u1', userB: 'u2');
      const p2 = ChatParams(userA: 'u1', userB: 'u2');
      const p3 = ChatParams(userA: 'u1', userB: 'u3');

      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1 == p3, isFalse);
    });
  });

  group('VietnamLocations 63 Provinces & Districts Tests', () {
    test('Contains exactly 63 provinces and centrally-governed cities across Vietnam', () {
      expect(VietnamLocations.provinces.length, equals(63));
      expect(VietnamLocations.provinces.contains('TP. Hồ Chí Minh'), isTrue);
      expect(VietnamLocations.provinces.contains('Hà Nội'), isTrue);
      expect(VietnamLocations.provinces.contains('Đà Nẵng'), isTrue);
      expect(VietnamLocations.provinces.contains('Bình Dương'), isTrue);
      expect(VietnamLocations.provinces.contains('Cần Thơ'), isTrue);
      expect(VietnamLocations.provinces.contains('Hải Phòng'), isTrue);
      expect(VietnamLocations.provinces.contains('Đồng Nai'), isTrue);
      expect(VietnamLocations.provinces.contains('Lâm Đồng'), isTrue);
      expect(VietnamLocations.provinces.contains('Yên Bái'), isTrue);
    });

    test('getDistricts returns comprehensive administrative units for selected province', () {
      final hcmDistricts = VietnamLocations.getDistricts('TP. Hồ Chí Minh');
      expect(hcmDistricts.first, equals('Tất cả'));
      expect(hcmDistricts.contains('Quận 1'), isTrue);
      expect(hcmDistricts.contains('Bình Thạnh'), isTrue);
      expect(hcmDistricts.contains('TP. Thủ Đức'), isTrue);
      expect(hcmDistricts.contains('Gò Vấp'), isTrue);

      final hanoiDistricts = VietnamLocations.getDistricts('Hà Nội');
      expect(hanoiDistricts.first, equals('Tất cả'));
      expect(hanoiDistricts.contains('Quận Cầu Giấy'), isTrue);
      expect(hanoiDistricts.contains('Quận Đống Đa'), isTrue);

      final unknownDistricts = VietnamLocations.getDistricts('Unknown Province');
      expect(unknownDistricts, equals(['Tất cả']));
    });
  });
}
