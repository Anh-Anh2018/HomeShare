import 'package:flutter/material.dart';
import 'phong_sang_theme.dart';

/// Lớp đại diện AppTheme chính thức của ứng dụng, kế thừa toàn diện từ PhongSangTheme
class AppTheme {
  const AppTheme._();

  /// Trả về theme sáng chuẩn moodboard "Phòng sáng" (phong_sang_theme.dart)
  static ThemeData get lightTheme => PhongSangTheme.light;
}
