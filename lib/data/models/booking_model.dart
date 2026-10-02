import 'package:cloud_firestore/cloud_firestore.dart';

/// Model Đơn đặt phòng & Lịch hẹn xem phòng chuẩn hóa theo Database homeShare (DrawIO pkg_3: Đặt phòng và kỳ ở)
/// Bảng: Đơn đặt phòng (phongId, nguoiDung_Id, trangThai_id, ngayVao, soThangThue, tenNguoiO, sdtNguoiO...)
class BookingRequestModel {
  final String id;
  final String renterId; // nguoiDung_Id / khachXemId
  final String? _renterUserCode; // maNguoiDung 5 ký tự (3 số đầu + 2 chữ sau)
  final String renterName; // tenNguoiO / tenKhach
  final String renterPhone; // sdtNguoiO / sdtKhach
  final String renterGender; // gioiTinhNguoiO
  final String roomId; // phongId / baiDangId
  final String roomTitle; // tieuDePhong
  final String roomAddress; // diaChiPhong
  final double roomPrice; // giaThue / giaPhong
  final double deposit; // tienCoc
  final double totalAmount; // tongPhaiTra
  final int rentalMonths; // soThangThue
  final String hostId; // chuNhaId
  final String hostName; // tenChuNha
  final String status; // trangThai: 'choDuyet' (pending), 'daDuyet' (approved), 'dangO' (active), 'daHuy' (cancelled), 'tuChoi' (rejected)
  final DateTime moveInDate; // ngayVao / thoiDiem
  final DateTime? acceptedDate; // ngayChapNhan
  final String note; // ghiChu
  final DateTime createdAt; // ngayTao

  // Vietnamese DrawIO Alias Getters
  String get donId => id;
  String get phongId => roomId;
  String get nguoiDungId => renterId;
  String get renterUserCode => _renterUserCode ?? '';
  String get maNguoiDung => renterUserCode;
  String get tenNguoiO => renterName;
  String get sdtNguoiO => renterPhone;
  String get gioiTinhNguoiO => renterGender;
  String get tieuDePhong => roomTitle;
  String get diaChiPhong => roomAddress;
  double get giaThue => roomPrice;
  double get tienCoc => deposit;
  double get tongPhaiTra => totalAmount;
  int get soThangThue => rentalMonths;
  String get chuNhaId => hostId;
  String get tenChuNha => hostName;
  String get trangThai => status;
  DateTime get ngayVao => moveInDate;
  DateTime? get ngayChapNhan => acceptedDate;
  String get ghiChu => note;
  DateTime get ngayTao => createdAt;

  BookingRequestModel({
    required this.id,
    required this.renterId,
    String? renterUserCode = '',
    required this.renterName,
    required this.renterPhone,
    this.renterGender = 'nam',
    required this.roomId,
    required this.roomTitle,
    required this.roomAddress,
    required this.roomPrice,
    this.deposit = 0.0,
    this.totalAmount = 0.0,
    this.rentalMonths = 1,
    required this.hostId,
    required this.hostName,
    this.status = 'pending',
    required this.moveInDate,
    this.acceptedDate,
    this.note = '',
    required this.createdAt,
  }) : _renterUserCode = renterUserCode ?? '';

  BookingRequestModel copyWith({
    String? id,
    String? renterId,
    String? renterUserCode,
    String? renterName,
    String? renterPhone,
    String? renterGender,
    String? roomId,
    String? roomTitle,
    String? roomAddress,
    double? roomPrice,
    double? deposit,
    double? totalAmount,
    int? rentalMonths,
    String? hostId,
    String? hostName,
    String? status,
    DateTime? moveInDate,
    DateTime? acceptedDate,
    String? note,
    DateTime? createdAt,
  }) {
    return BookingRequestModel(
      id: id ?? this.id,
      renterId: renterId ?? this.renterId,
      renterUserCode: renterUserCode ?? this.renterUserCode,
      renterName: renterName ?? this.renterName,
      renterPhone: renterPhone ?? this.renterPhone,
      renterGender: renterGender ?? this.renterGender,
      roomId: roomId ?? this.roomId,
      roomTitle: roomTitle ?? this.roomTitle,
      roomAddress: roomAddress ?? this.roomAddress,
      roomPrice: roomPrice ?? this.roomPrice,
      deposit: deposit ?? this.deposit,
      totalAmount: totalAmount ?? this.totalAmount,
      rentalMonths: rentalMonths ?? this.rentalMonths,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      status: status ?? this.status,
      moveInDate: moveInDate ?? this.moveInDate,
      acceptedDate: acceptedDate ?? this.acceptedDate,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory BookingRequestModel.fromFirestore(DocumentSnapshot doc) {
    return BookingRequestModel.fromMap(doc.data() as Map<String, dynamic>? ?? {}, doc.id);
  }

  factory BookingRequestModel.fromMap(Map<String, dynamic> data, String id) {
    return BookingRequestModel(
      id: id,
      renterId: data['renterId'] ?? data['nguoiDung_Id'] ?? data['khachXemId'] ?? '',
      renterUserCode: data['renterUserCode'] ?? data['maNguoiDung'] ?? data['userCode'] ?? '',
      renterName: data['renterName'] ?? data['tenNguoiO'] ?? data['tenKhach'] ?? '',
      renterPhone: data['renterPhone'] ?? data['sdtNguoiO'] ?? data['sdtKhach'] ?? '',
      renterGender: data['renterGender'] ?? data['gioiTinhNguoiO'] ?? 'nam',
      roomId: data['roomId'] ?? data['phongId'] ?? data['baiDangId'] ?? '',
      roomTitle: data['roomTitle'] ?? data['tieuDePhong'] ?? data['tieuDe'] ?? '',
      roomAddress: data['roomAddress'] ?? data['diaChiPhong'] ?? data['diaChi'] ?? '',
      roomPrice: ((data['roomPrice'] ?? data['giaThue'] ?? data['giaPhong']) as num?)?.toDouble() ?? 0.0,
      deposit: ((data['deposit'] ?? data['tienCoc']) as num?)?.toDouble() ?? 0.0,
      totalAmount: ((data['totalAmount'] ?? data['tongPhaiTra']) as num?)?.toDouble() ?? 0.0,
      rentalMonths: ((data['rentalMonths'] ?? data['soThangThue']) as num?)?.toInt() ?? 1,
      hostId: data['hostId'] ?? data['chuNhaId'] ?? '',
      hostName: data['hostName'] ?? data['tenChuNha'] ?? '',
      status: data['status'] ?? data['trangThai'] ?? 'pending',
      moveInDate: (data['moveInDate'] is Timestamp)
          ? (data['moveInDate'] as Timestamp).toDate()
          : (data['ngayVao'] is Timestamp)
              ? (data['ngayVao'] as Timestamp).toDate()
              : (data['thoiDiem'] is Timestamp)
                  ? (data['thoiDiem'] as Timestamp).toDate()
                  : DateTime.now(),
      acceptedDate: (data['acceptedDate'] is Timestamp)
          ? (data['acceptedDate'] as Timestamp).toDate()
          : (data['ngayChapNhan'] is Timestamp)
              ? (data['ngayChapNhan'] as Timestamp).toDate()
              : null,
      note: data['note'] ?? data['ghiChu'] ?? '',
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['ngayTao'] is Timestamp)
              ? (data['ngayTao'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'renterId': renterId,
      'renterUserCode': renterUserCode,
      'maNguoiDung': renterUserCode,
      'userCode': renterUserCode,
      'nguoiDung_Id': renterId,
      'renterName': renterName,
      'tenNguoiO': renterName,
      'renterPhone': renterPhone,
      'sdtNguoiO': renterPhone,
      'renterGender': renterGender,
      'gioiTinhNguoiO': renterGender,
      'roomId': roomId,
      'phongId': roomId,
      'roomTitle': roomTitle,
      'tieuDePhong': roomTitle,
      'roomAddress': roomAddress,
      'diaChiPhong': roomAddress,
      'roomPrice': roomPrice,
      'giaThue': roomPrice,
      'deposit': deposit,
      'tienCoc': deposit,
      'totalAmount': totalAmount,
      'tongPhaiTra': totalAmount,
      'rentalMonths': rentalMonths,
      'soThangThue': rentalMonths,
      'hostId': hostId,
      'chuNhaId': hostId,
      'hostName': hostName,
      'tenChuNha': hostName,
      'status': status,
      'trangThai': status,
      'moveInDate': Timestamp.fromDate(moveInDate),
      'ngayVao': Timestamp.fromDate(moveInDate),
      if (acceptedDate != null) 'acceptedDate': Timestamp.fromDate(acceptedDate!),
      if (acceptedDate != null) 'ngayChapNhan': Timestamp.fromDate(acceptedDate!),
      'note': note,
      'ghiChu': note,
      'createdAt': Timestamp.fromDate(createdAt),
      'ngayTao': Timestamp.fromDate(createdAt),
    };
  }
}
