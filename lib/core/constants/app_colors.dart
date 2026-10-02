import 'package:flutter/material.dart';
import '../theme/phong_sang_theme.dart';

class AppColors {
  // Bảng màu chuẩn theo moodboard Phòng Sáng (phong_sang_theme.dart)
  static const Color primary = PhongSangColors.accent;         // Nút chính, xanh hành động (--accent #155EEF)
  static const Color primaryLight = Color(0xFF2E90FA);        // Xanh sáng phụ trợ
  static const Color primaryDark = Color(0xFF175CD3);         // Xanh đậm
  static const Color primaryContainer = PhongSangColors.accentSoft; // Nền chip/badge nhấn (--accent-soft #E8F0FE)
  
  static const Color textDark = PhongSangColors.ink;          // Chữ tiêu đề, giá (--ink #101828)
  static const Color textPrimary = PhongSangColors.ink;       // Màu chữ chính
  static const Color textSecondary = PhongSangColors.muted;   // Chữ phụ (--muted #667085)
  static const Color textMuted = PhongSangColors.muted;       // Chữ mờ / placeholder
  
  static const Color background = PhongSangColors.paper;      // Nền app (--paper #F3F6FB)
  static const Color surface = PhongSangColors.card;          // Thẻ card (--card #FFFFFF)
  static const Color surfaceVariant = PhongSangColors.priceSoft; // Nền tag/chip lọc (--price-soft #F2F4F7)
  static const Color priceSoft = PhongSangColors.priceSoft;      // Nền tag/chip lọc chuẩn PhongSangColors
  static const Color border = PhongSangColors.line;           // Viền (--line #E4E7EC)
  static const Color borderDark = PhongSangColors.ink;        // Viền đậm nét
  static const Color noteHighlight = Color(0xFFFEFFDD);       // Màu ghi chú vàng nhạt

  // Màu trạng thái phòng chuẩn Phòng Sáng
  static const Color hold = PhongSangColors.hold;             // Giữ chỗ (--hold #B54708)
  static const Color live = PhongSangColors.live;             // Đang ở (--live #067647)
  static const Color empty = PhongSangColors.empty;           // Trống (--empty #667085)
  static const Color price = PhongSangColors.price;           // Giá (#101828)

  // Màu cảnh báo / Trạng thái hệ thống
  static const Color danger = Color(0xFFD92D20);
  static const Color dangerContainer = Color(0xFFFEE4E2);

  static const Color warning = PhongSangColors.hold;
  static const Color warningContainer = Color(0xFFFEF0C7);

  static const Color info = PhongSangColors.accent;
  static const Color infoContainer = PhongSangColors.accentSoft;

  static const Color success = PhongSangColors.live;
  static const Color successContainer = Color(0xFFD1FADF);

  // Gradient ảnh phòng đặc trưng Phòng Sáng
  static const LinearGradient photoA = PhongSangColors.photoA;
  static const LinearGradient photoB = PhongSangColors.photoB;
}
