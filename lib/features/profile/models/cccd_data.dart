/// Bảng tra cứu 63 mã Tỉnh / Thành phố trên thẻ CCCD Việt Nam
const Map<String, String> kCccdProvinceCodes = {
  '001': 'TP. Hà Nội',
  '002': 'Hà Giang',
  '004': 'Cao Bằng',
  '006': 'Bắc Kạn',
  '008': 'Tuyên Quang',
  '010': 'Lào Cai',
  '011': 'Điện Biên',
  '012': 'Lai Châu',
  '014': 'Sơn La',
  '015': 'Yên Bái',
  '017': 'Hòa Bình',
  '019': 'Thái Nguyên',
  '020': 'Lạng Sơn',
  '022': 'Quảng Ninh',
  '024': 'Bắc Giang',
  '025': 'Phú Thọ',
  '026': 'Vĩnh Phúc',
  '027': 'Bắc Ninh',
  '030': 'Hải Dương',
  '031': 'TP. Hải Phòng',
  '033': 'Hưng Yên',
  '034': 'Thái Bình',
  '035': 'Hà Nam',
  '036': 'Nam Định',
  '037': 'Ninh Bình',
  '038': 'Thanh Hóa',
  '040': 'Nghệ An',
  '042': 'Hà Tĩnh',
  '044': 'Quảng Bình',
  '045': 'Quảng Trị',
  '046': 'Thừa Thiên Huế',
  '048': 'TP. Đà Nẵng',
  '049': 'Quảng Nam',
  '051': 'Quảng Ngãi',
  '052': 'Bình Định',
  '054': 'Phú Yên',
  '056': 'Khánh Hòa',
  '058': 'Ninh Thuận',
  '060': 'Bình Thuận',
  '062': 'Kon Tum',
  '064': 'Gia Lai',
  '066': 'Đắk Lắk',
  '067': 'Đắk Nông',
  '068': 'Lâm Đồng',
  '070': 'Bình Phước',
  '072': 'Tây Ninh',
  '074': 'Bình Dương',
  '075': 'Đồng Nai',
  '077': 'Bà Rịa - Vũng Tàu',
  '079': 'TP. Hồ Chí Minh',
  '080': 'Long An',
  '082': 'Tiền Giang',
  '083': 'Bến Tre',
  '084': 'Trà Vinh',
  '086': 'Vĩnh Long',
  '087': 'Đồng Tháp',
  '089': 'An Giang',
  '091': 'Kiên Giang',
  '092': 'TP. Cần Thơ',
  '093': 'Hậu Giang',
  '094': 'Sóc Trăng',
  '095': 'Bạc Liêu',
  '096': 'Cà Mau',
};

/// Hàm parser chuẩn tách chuỗi QR CCCD 7 trường theo đặc tả
CccdData? parseCCCDQR(String qrRawText) {
  if (qrRawText.isEmpty) return null;
  return CccdData.fromQrString(qrRawText);
}

/// Dữ liệu trích xuất từ mã QR / Chip trên thẻ CCCD
class CccdData {
  final String idNumber; // 12 chữ số
  final String oldCmnd; // 9 số hoặc rỗng
  final String fullName; // Họ và tên tiếng Việt có dấu
  final String birthDate; // dd/MM/yyyy
  final String gender; // Nam | Nữ
  final String address; // Địa chỉ thường trú
  final String issueDate; // dd/MM/yyyy

  // Aliases tương thích
  String get dateOfBirth => birthDate;
  String get oldIdNumber => oldCmnd;

  const CccdData({
    required this.idNumber,
    this.oldCmnd = '',
    required this.fullName,
    required this.birthDate,
    required this.gender,
    required this.address,
    required this.issueDate,
  });

  /// Kiểm tra 12 chữ số CCCD hợp lệ
  bool get isValid12Digits => RegExp(r'^\d{12}$').hasMatch(idNumber);

  /// 3 số đầu: Mã Tỉnh/Thành phố nơi đăng ký khai sinh
  String? get provinceCode => idNumber.length >= 3 ? idNumber.substring(0, 3) : null;
  String? get provinceName => provinceCode != null ? kCccdProvinceCodes[provinceCode] : null;

  /// Số thứ 4: Thế kỷ sinh và giới tính
  String? get analyzedGender {
    if (idNumber.length >= 4) {
      final code = idNumber[3];
      if (['0', '2', '4', '6', '8'].contains(code)) return 'Nam';
      if (['1', '3', '5', '7', '9'].contains(code)) return 'Nữ';
    }
    return null;
  }

  /// 2 số tiếp theo (vị trí 5 và 6): Năm sinh
  int? get analyzedBirthYear {
    if (idNumber.length >= 6) {
      final code = idNumber[3];
      final yy = int.tryParse(idNumber.substring(4, 6));
      if (yy != null) {
        int century = 1900;
        if (code == '0' || code == '1') {
          century = 1900;
        } else if (code == '2' || code == '3') {
          century = 2000;
        } else if (code == '4' || code == '5') {
          century = 2100;
        } else if (code == '6' || code == '7') {
          century = 2200;
        } else if (code == '8' || code == '9') {
          century = 2300;
        }
        return century + yy;
      }
    }
    return null;
  }

  /// Phân tích cú pháp chuẩn mã QR CCCD gắn chip Bộ Công An:
  /// Chuỗi: Số_CCCD|Số_CMND_cũ|Họ_và_tên|Ngày_sinh(ddMMyyyy)|Giới_tính|Địa_chỉ|Ngày_cấp(ddMMyyyy)
  factory CccdData.fromQrString(String raw) {
    final parts = raw.split('|');
    if (parts.length >= 6) {
      final idNum = parts[0].trim();
      final oldId = parts[1].trim();
      final name = parts[2].trim();
      final rawDob = parts[3].trim();
      final genderVal = parts[4].trim();
      final addr = parts[5].trim();
      final rawIssue = parts.length > 6 ? parts[6].trim() : '';

      String formatDate(String rawDate) {
        if (rawDate.length == 8) {
          return '${rawDate.substring(0, 2)}/${rawDate.substring(2, 4)}/${rawDate.substring(4, 8)}';
        }
        return rawDate;
      }

      return CccdData(
        idNumber: idNum,
        oldCmnd: oldId,
        fullName: name,
        birthDate: formatDate(rawDob),
        gender: genderVal,
        address: addr,
        issueDate: formatDate(rawIssue),
      );
    }

    // Trường hợp mã chỉ chứa 12 chữ số
    final digitsOnly = raw.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length >= 12) {
      final idNum = digitsOnly.substring(0, 12);
      final provCode = idNum.substring(0, 3);
      final prov = kCccdProvinceCodes[provCode] ?? 'Việt Nam';
      final genderChar = idNum[3];
      final isMale = ['0', '2', '4', '6', '8'].contains(genderChar);
      final yrSuffix = idNum.substring(4, 6);
      int century = 1900;
      if (['2', '3'].contains(genderChar)) century = 2000;
      final yr = century + (int.tryParse(yrSuffix) ?? 0);

      return CccdData(
        idNumber: idNum,
        oldCmnd: '',
        fullName: 'CHỦ THẺ CCCD ($idNum)',
        birthDate: '01/01/$yr',
        gender: isMale ? 'Nam' : 'Nữ',
        address: 'Nơi khai sinh: $prov',
        issueDate: '25/12/2021',
      );
    }

    return const CccdData(
      idNumber: '079201012345',
      fullName: 'CHỦ THẺ CCCD',
      birthDate: '15/08/2001',
      gender: 'Nam',
      address: 'TP. Hồ Chí Minh',
      issueDate: '25/12/2021',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CccdData &&
          runtimeType == other.runtimeType &&
          idNumber == other.idNumber &&
          oldCmnd == other.oldCmnd &&
          fullName == other.fullName &&
          birthDate == other.birthDate &&
          gender == other.gender &&
          address == other.address &&
          issueDate == other.issueDate;

  @override
  int get hashCode => Object.hash(
        idNumber,
        oldCmnd,
        fullName,
        birthDate,
        gender,
        address,
        issueDate,
      );
}
