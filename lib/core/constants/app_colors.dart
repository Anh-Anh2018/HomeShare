import 'package:flutter/material.dart';
import '../theme/phong_sang_theme.dart';

/// Bảng màu ứng dụng, map thẳng token Phòng sáng.
class AppColors {
  static const Color primary = PhongSangColors.accent;
  static const Color primaryLight = Color(0xFF3B76F6);
  static const Color primaryContainer = PhongSangColors.accentSoft;

  static const Color textDark = PhongSangColors.ink;
  static const Color textPrimary = PhongSangColors.ink;
  static const Color textSecondary = PhongSangColors.muted;
  static const Color textMuted = PhongSangColors.muted;

  static const Color background = PhongSangColors.paper;
  static const Color surface = PhongSangColors.card;
  static const Color border = PhongSangColors.line;

  static const Color danger = PhongSangColors.hold;
  static const Color dangerContainer = Color(0xFFFFF4ED);

  static const Color warning = PhongSangColors.hold;
  static const Color warningContainer = Color(0xFFFFF4ED);

  static const Color info = PhongSangColors.accent;
  static const Color infoContainer = PhongSangColors.accentSoft;

  static const Color success = PhongSangColors.live;
  static const Color successContainer = Color(0xFFE6F4EE);
}
