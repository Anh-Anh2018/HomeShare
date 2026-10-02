/// Tiện ích sinh mã VietQR chuẩn Napas 24/7 và URL VietQR.io
/// Hỗ trợ quét mã bằng 100% ứng dụng ngân hàng Việt Nam (MBBank, Vietcombank, Techcombank, MoMo...)
class VietQRHelper {
  // Thông tin thụ hưởng mặc định theo chỉ định của hệ thống HomeShare
  static const String defaultBankBin = '970422'; // Napas BIN MBBank
  static const String defaultBankCode = 'MB';
  static const String defaultBankName = 'MBBank (Ngân hàng TMCP Quân Đội)';
  static const String defaultAccountNo = '0382542737';
  static const String defaultAccountName = 'TRAN THANH ANH TOAN';
  static const String defaultAccountDisplayName = 'TRẦN THANH ANH TOÀN';

  /// Tạo URL hình ảnh VietQR chuẩn từ VietQR.io
  /// Link này trả về trực tiếp ảnh QR Code chuẩn quốc gia có logo MBBank & Napas 247
  static String buildVietQrImageUrl({
    required double amount,
    required String addInfo,
    String accountNo = defaultAccountNo,
    String bankCode = defaultBankCode,
    String accountName = defaultAccountName,
  }) {
    final cleanAmount = amount.toInt();
    final encodedInfo = Uri.encodeComponent(addInfo.trim());
    final encodedName = Uri.encodeComponent(accountName.trim());
    return 'https://img.vietqr.io/image/$bankCode-$accountNo-compact2.png?amount=$cleanAmount&addInfo=$encodedInfo&accountName=$encodedName';
  }

  /// Tạo chuỗi VietQR Payload chuẩn EMVCo (Napas 24/7)
  /// Chuỗi này có thể dùng cho bất kỳ QR Renderer nào (như qr_flutter)
  /// và đảm bảo mọi app ngân hàng quét đều đọc được chuẩn xác!
  static String generateNapasEmvcoPayload({
    required double amount,
    required String addInfo,
    String accountNo = defaultAccountNo,
    String bankBin = defaultBankBin,
  }) {
    // 00: Payload Format Indicator (01)
    final f00 = _formatTlv('00', '01');

    // 01: Point of Initiation Method (12: Dynamic QR code with amount)
    final f01 = _formatTlv('01', '12');

    // 38: Merchant Account Information (Napas standard)
    // 38.00: GUID Napas: A000000727
    final sub00 = _formatTlv('00', 'A000000727');
    // 38.01: Beneficiary Bank Info (Bin + Account Number)
    final sub0100 = _formatTlv('00', bankBin);
    final sub0101 = _formatTlv('01', accountNo);
    final sub01 = _formatTlv('01', sub0100 + sub0101);
    // 38.02: Service code: QRIBFTTA (Quick Transfer to Account)
    final sub02 = _formatTlv('02', 'QRIBFTTA');
    final f38 = _formatTlv('38', sub00 + sub01 + sub02);

    // 53: Transaction Currency (704 = VND)
    final f53 = _formatTlv('53', '704');

    // 54: Transaction Amount
    final f54 = _formatTlv('54', amount.toInt().toString());

    // 58: Country Code (VN)
    final f58 = _formatTlv('58', 'VN');

    // 59: Merchant Name (Tên chủ tài khoản - Bắt buộc theo EMVCo/Napas, tối đa 25 ký tự)
    final cleanMerchantName = _removeDiacritics(defaultAccountName).toUpperCase();
    final f59 = _formatTlv('59', cleanMerchantName.length > 25 ? cleanMerchantName.substring(0, 25) : cleanMerchantName);

    // 60: Merchant City (Thành phố - Bắt buộc theo EMVCo/Napas, tối đa 15 ký tự)
    final f60 = _formatTlv('60', 'HA NOI');

    // 62: Additional Data Field (Purpose/Reference)
    final cleanInfo = _removeDiacritics(addInfo).trim();
    final sub6208 = _formatTlv('08', cleanInfo.isEmpty ? 'DATPHONG' : cleanInfo);
    final f62 = _formatTlv('62', sub6208);

    // Ghép dữ liệu trước khi tính CRC (Checksum)
    final rawData = '$f00$f01$f38$f53$f54$f58$f59$f60$f62' '6304';
    final crc = _calculateCrc16(rawData);

    return '$rawData$crc';
  }

  /// Định dạng TLV (Tag - Length - Value)
  static String _formatTlv(String tag, String value) {
    final len = value.length.toString().padLeft(2, '0');
    return '$tag$len$value';
  }

  /// Thuật toán tính CRC16-CCITT (Polynomial 0x1021, Initial 0xFFFF) chuẩn EMVCo
  static String _calculateCrc16(String input) {
    int crc = 0xFFFF;
    const int polynomial = 0x1021;

    for (int i = 0; i < input.length; i++) {
      final byte = input.codeUnitAt(i);
      crc ^= (byte << 8);
      for (int bit = 0; bit < 8; bit++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ polynomial) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }

    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  /// Loại bỏ dấu tiếng Việt chuẩn xác (Bảo toàn chữ HOA và chữ thường)
  static String _removeDiacritics(String str) {
    var result = str;

    const lowerPatterns = [
      'a:áàạảãâấầậẩẫăắằặẳẵ',
      'e:éèẹẻẽêếềệểễ',
      'o:óòọỏõôốồộổỗơớờợởỡ',
      'u:úùụủũưứừựửữ',
      'i:íìịỉĩ',
      'd:đ',
      'y:ýỳỵỷỹ',
    ];

    const upperPatterns = [
      'A:ÁÀẠẢÃÂẤẦẬẨẪĂẮẰẶẲẴ',
      'E:ÉÈẸẺẼÊẾỀỆỂỄ',
      'O:ÓÒỌỎÕÔỐỒỘỔỖƠỚỜỢỞỠ',
      'U:ÚÙỤỦŨƯỨỪỰỬỮ',
      'I:ÍÌỊỈĨ',
      'D:Đ',
      'Y:ÝỲỴỶỸ',
    ];

    for (final p in lowerPatterns) {
      final parts = p.split(':');
      final baseChar = parts[0];
      for (final char in parts[1].split('')) {
        result = result.replaceAll(char, baseChar);
      }
    }

    for (final p in upperPatterns) {
      final parts = p.split(':');
      final baseChar = parts[0];
      for (final char in parts[1].split('')) {
        result = result.replaceAll(char, baseChar);
      }
    }

    return result.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '');
  }
}
