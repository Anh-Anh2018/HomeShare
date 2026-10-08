import 'package:cloud_firestore/cloud_firestore.dart';

/// Model Tin ở ghép chuẩn hóa theo Database homeShare (DrawIO pkg_4: Ở ghép)
/// Bảng: Tin ở ghép, Ảnh tin ở ghép, Yêu cầu trao đổi ở ghép
class RoommatePostModel {
  final String id;
  final String authorId; // nguoiDangId
  final String authorName; // hoTen / tenNguoiDang
  final int authorAge; // tuoi
  final String authorGender; // Nam / Nữ (gioiTinh)
  final String authorOccupation; // ngheNghiep
  final String authorAvatar; // anhDaiDien
  final String title; // tieuDe
  final String description; // noiDung
  final String postType; // loaiTin: 'timNguoiOGhep' (daCoPhong) | 'dangTimPhong'
  final String? propertyType; // loaiNhaO: 'Căn hộ chung cư' | 'Nhà trọ / Phòng trọ / Căn hộ mini' | 'Nhà nguyên căn' | 'Ký túc xá / Sleepbox'
  final double pricePerPerson; // giaMoiNguoi
  final double budgetMin; // nganSachTu
  final double budgetMax; // nganSachDen
  final String address; // diaChi
  final String district; // khuVuc / quanHuyen (diaDiemId)
  final String targetGender; // gioiTinhMongMuon: nu | nam | tatCa
  final List<String> habits; // thoiQuen / soThich
  final List<String> images; // anhTinOGhep (duongDan)
  final List<String> imageCaptions; // ghiChuAnh
  final bool isVerified; // daXacThuc
  final int matchRate; // doTuongThich (AI Match Rate 0-100%)
  final bool hasRoom; // true = daCoPhong (timNguoiOGhep), false = dangTimPhong
  final String status; // trangThai: dangMo | daDong
  final String contactPhone; // soDienThoai / sdtLienHe
  final DateTime createdAt; // ngayTao
  final DateTime updatedAt; // ngayCapNhat

  // Vietnamese DrawIO Alias Getters
  String get tieuDe => title;
  String get noiDung => description;
  String get nguoiDangId => authorId;
  String get loaiTin => postType;
  String get displayPropertyType => (propertyType != null && propertyType!.isNotEmpty)
      ? propertyType!
      : (hasRoom ? 'Căn hộ chung cư' : 'Phòng trọ sinh viên');
  String get loaiNhaO => displayPropertyType;
  double get giaMoiNguoi => pricePerPerson;
  double get nganSachTu => budgetMin;
  double get nganSachDen => budgetMax;
  String get diaChi => address;
  String get gioiTinhMongMuon => targetGender;
  List<String> get thoiQuen => habits;
  List<String> get anhTinOGhep => images;
  String get trangThai => status;
  String get soDienThoai => contactPhone;
  DateTime get ngayTao => createdAt;
  DateTime get ngayCapNhat => updatedAt;

  RoommatePostModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAge,
    required this.authorGender,
    required this.authorOccupation,
    this.authorAvatar = '',
    required this.title,
    required this.description,
    this.postType = 'timNguoiOGhep',
    this.propertyType,
    this.pricePerPerson = 0.0,
    required this.budgetMin,
    required this.budgetMax,
    this.address = '',
    required this.district,
    required this.targetGender,
    required this.habits,
    this.images = const [],
    this.imageCaptions = const [],
    this.isVerified = true,
    this.matchRate = 94,
    required this.hasRoom,
    this.status = 'dangMo',
    required this.contactPhone,
    required this.createdAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  RoommatePostModel copyWith({
    String? id,
    String? authorId,
    String? authorName,
    int? authorAge,
    String? authorGender,
    String? authorOccupation,
    String? authorAvatar,
    String? title,
    String? description,
    String? postType,
    String? propertyType,
    double? pricePerPerson,
    double? budgetMin,
    double? budgetMax,
    String? address,
    String? district,
    String? targetGender,
    List<String>? habits,
    List<String>? images,
    List<String>? imageCaptions,
    bool? isVerified,
    int? matchRate,
    bool? hasRoom,
    String? status,
    String? contactPhone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RoommatePostModel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAge: authorAge ?? this.authorAge,
      authorGender: authorGender ?? this.authorGender,
      authorOccupation: authorOccupation ?? this.authorOccupation,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      title: title ?? this.title,
      description: description ?? this.description,
      postType: postType ?? this.postType,
      propertyType: propertyType ?? this.propertyType,
      pricePerPerson: pricePerPerson ?? this.pricePerPerson,
      budgetMin: budgetMin ?? this.budgetMin,
      budgetMax: budgetMax ?? this.budgetMax,
      address: address ?? this.address,
      district: district ?? this.district,
      targetGender: targetGender ?? this.targetGender,
      habits: habits ?? this.habits,
      images: images ?? this.images,
      imageCaptions: imageCaptions ?? this.imageCaptions,
      isVerified: isVerified ?? this.isVerified,
      matchRate: matchRate ?? this.matchRate,
      hasRoom: hasRoom ?? this.hasRoom,
      status: status ?? this.status,
      contactPhone: contactPhone ?? this.contactPhone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory RoommatePostModel.fromFirestore(DocumentSnapshot doc) {
    return RoommatePostModel.fromMap(doc.data() as Map<String, dynamic>? ?? {}, doc.id);
  }

  factory RoommatePostModel.fromMap(Map<String, dynamic> data, String id) {
    final loaiTinVal = data['postType'] ?? data['loaiTin'] ?? (data['hasRoom'] == true ? 'timNguoiOGhep' : 'dangTimPhong');
    final hasRoomVal = data['hasRoom'] ?? (loaiTinVal == 'timNguoiOGhep' || loaiTinVal == 'daCoPhong');
    
    // Parse habits / thoiQuen
    final rawHabits = (data['habits'] ?? data['thoiQuen'] ?? data['soThich']) as List<dynamic>?;
    final parsedHabits = rawHabits
            ?.map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];

    // Parse images / anhTinOGhep
    final rawImages = (data['images'] ?? data['anhTinOGhep'] ?? data['anhPhong']) as List<dynamic>?;
    final parsedImages = rawImages
            ?.map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];

    final rawCaptions = (data['imageCaptions'] ?? data['ghiChuAnh']) as List<dynamic>?;
    final parsedCaptions = rawCaptions
            ?.map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];

    return RoommatePostModel(
      id: id,
      authorId: data['authorId'] ?? data['nguoiDangId'] ?? '',
      authorName: data['authorName'] ?? data['hoTen'] ?? data['tenNguoiDang'] ?? 'Thành viên HomeShare',
      authorAge: (data['authorAge'] ?? data['tuoi']) is num ? (data['authorAge'] ?? data['tuoi']).toInt() : 20,
      authorGender: data['authorGender'] ?? data['gioiTinh'] ?? 'Nam',
      authorOccupation: data['authorOccupation'] ?? data['ngheNghiep'] ?? 'Sinh viên',
      authorAvatar: data['authorAvatar'] ?? data['anhDaiDien'] ?? '',
      title: data['title'] ?? data['tieuDe'] ?? '',
      description: data['description'] ?? data['noiDung'] ?? data['moTa'] ?? '',
      postType: loaiTinVal.toString(),
      propertyType: data['propertyType'] ?? data['loaiNhaO'] ?? data['loaiHinh'] ?? (hasRoomVal ? 'Căn hộ chung cư' : 'Phòng trọ sinh viên'),
      pricePerPerson: ((data['pricePerPerson'] ?? data['giaMoiNguoi']) as num?)?.toDouble() ?? 0.0,
      budgetMin: ((data['budgetMin'] ?? data['nganSachTu']) as num?)?.toDouble() ?? 1000000,
      budgetMax: ((data['budgetMax'] ?? data['nganSachDen']) as num?)?.toDouble() ?? 2500000,
      address: data['address'] ?? data['diaChi'] ?? '',
      district: data['district'] ?? data['quanHuyen'] ?? data['khuVuc'] ?? 'TP. Thủ Đức',
      targetGender: data['targetGender'] ?? data['gioiTinhMongMuon'] ?? 'Tất cả',
      habits: parsedHabits,
      images: parsedImages,
      imageCaptions: parsedCaptions,
      isVerified: data['isVerified'] ?? data['daXacThuc'] ?? true,
      matchRate: (data['matchRate'] ?? data['doTuongThich'] ?? 94) is num ? (data['matchRate'] ?? data['doTuongThich'] ?? 94).toInt() : 94,
      hasRoom: hasRoomVal,
      status: data['status'] ?? data['trangThai'] ?? 'dangMo',
      contactPhone: data['contactPhone'] ?? data['soDienThoai'] ?? data['sdtLienHe'] ?? '',
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['ngayTao'] is Timestamp)
              ? (data['ngayTao'] as Timestamp).toDate()
              : DateTime.now(),
      updatedAt: (data['updatedAt'] is Timestamp)
          ? (data['updatedAt'] as Timestamp).toDate()
          : (data['ngayCapNhat'] is Timestamp)
              ? (data['ngayCapNhat'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'nguoiDangId': authorId,
      'authorName': authorName,
      'authorAge': authorAge,
      'authorGender': authorGender,
      'authorOccupation': authorOccupation,
      'authorAvatar': authorAvatar,
      'title': title,
      'tieuDe': title,
      'description': description,
      'noiDung': description,
      'postType': postType,
      'loaiTin': postType,
      'propertyType': displayPropertyType,
      'loaiNhaO': displayPropertyType,
      'pricePerPerson': pricePerPerson,
      'giaMoiNguoi': pricePerPerson,
      'budgetMin': budgetMin,
      'nganSachTu': budgetMin,
      'budgetMax': budgetMax,
      'nganSachDen': budgetMax,
      'address': address,
      'diaChi': address,
      'district': district,
      'targetGender': targetGender,
      'gioiTinhMongMuon': targetGender,
      'habits': habits,
      'thoiQuen': habits,
      'images': images,
      // Ảnh Base64 đã khá dài; không ghi thêm bản sao vào anhTinOGhep kẻo document vượt 1MB và máy kia không nhận được bài.
      if (!images.any((path) => path.startsWith('data:image'))) 'anhTinOGhep': images,
      'imageCaptions': imageCaptions,
      'isVerified': isVerified,
      'matchRate': matchRate,
      'hasRoom': hasRoom,
      'status': status,
      'trangThai': status,
      'contactPhone': contactPhone,
      'soDienThoai': contactPhone,
      'createdAt': Timestamp.fromDate(createdAt),
      'ngayTao': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'ngayCapNhat': Timestamp.fromDate(updatedAt),
    };
  }
}
