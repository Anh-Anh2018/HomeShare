import 'package:flutter/material.dart';

class AppColors {
  // Bảng màu nhận diện thương hiệu chuẩn từ sơ đồ Database homeShare
  static const Color primary = Color(0xFF038048);         // Xanh ngọc Emerald Green thương hiệu (#038048)
  static const Color primaryLight = Color(0xFF0EA363);    // Xanh sáng phụ trợ
  static const Color primaryDark = Color(0xFF025831);     // Xanh đậm tương phản
  static const Color primaryContainer = Color(0xFFE6F4EA);// Nền nhẹ nhàng cho badge, container
  
  static const Color textDark = Color(0xFF181818);        // Đen đậm kỹ thuật Database homeShare (#181818)
  static const Color textPrimary = Color(0xFF181818);     // Màu chữ chính
  static const Color textSecondary = Color(0xFF3D4A42);   // Chữ phụ
  static const Color textMuted = Color(0xFF6D7A72);       // Chữ mờ / placeholder
  
  static const Color background = Color(0xFFF8FAF9);      // Nền tổng thể Scaffold
  static const Color surface = Color(0xFFFFFFFF);         // Nền bề mặt chính (Card, Dialog)
  static const Color surfaceVariant = Color(0xFFF1F1F1);  // Nền phụ bảng dữ liệu Database homeShare (#F1F1F1)
  static const Color border = Color(0xFFE5E7EB);          // Viền mặc định
  static const Color borderDark = Color(0xFF181818);      // Viền sắc nét chuẩn diagram (#181818)

  // Màu ghi chú / highlight nổi bật từ Database homeShare (#FEFFDD)
  static const Color noteHighlight = Color(0xFFFEFFDD);

  // Màu cảnh báo / Trạng thái chuẩn Figma & Material
  static const Color danger = Color(0xFFBA1A1A);
  static const Color dangerContainer = Color(0xFFFFDAD6);

  static const Color warning = Color(0xFF825100);
  static const Color warningContainer = Color(0xFFFFDDB8);

  static const Color info = Color(0xFF006591);
  static const Color infoContainer = Color(0xFFE2E7FF);

  static const Color success = Color(0xFF16A34A);
  static const Color successContainer = Color(0xFFDCFCE7);
}
