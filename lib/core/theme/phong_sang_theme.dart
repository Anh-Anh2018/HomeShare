import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Theme Flutter cho moodboard **Phòng sáng** (hướng 2 · sàn tìm phòng).
///
/// Nền xanh xám, chữ Inter, nút xanh hành động, giá cùng màu mực với tiêu đề,
/// góc cạnh gọn. Ảnh phòng dùng ánh sáng ban ngày.
///
/// Gắn vào app:
/// ```dart
/// MaterialApp(
///   theme: PhongSangTheme.light,
/// )
/// ```
/// Token riêng (giá, trạng thái phòng, tag, ảnh) lấy qua [PhongSangTokens.of].
class PhongSangColors {
  const PhongSangColors._();

  /// Nền app `--paper`.
  static const Color paper = Color(0xFFF3F6FB);

  /// Chữ tiêu đề, giá `--ink` / `--price`.
  static const Color ink = Color(0xFF101828);

  /// Chữ phụ `--muted`.
  static const Color muted = Color(0xFF667085);

  /// Nút chính `--accent`.
  static const Color accent = Color(0xFF155EEF);

  /// Nền chip / badge nhấn `--accent-soft`.
  static const Color accentSoft = Color(0xFFE8F0FE);

  /// Chữ trên nút chính `--on-accent`.
  static const Color onAccent = Color(0xFFFFFFFF);

  /// Giá. Cùng mực với tiêu đề, không tách màu.
  static const Color price = Color(0xFF101828);

  /// Nền tag, chip lọc `--price-soft`.
  static const Color priceSoft = Color(0xFFF2F4F7);

  /// Thẻ `--card`.
  static const Color card = Color(0xFFFFFFFF);

  /// Viền `--line`.
  static const Color line = Color(0xFFE4E7EC);

  /// Trạng thái giữ chỗ `--hold`.
  static const Color hold = Color(0xFFB54708);

  /// Trạng thái đang ở `--live`.
  static const Color live = Color(0xFF067647);

  /// Trạng thái trống `--empty`.
  static const Color empty = Color(0xFF667085);

  /// Khung máy trong moodboard `--bezel`.
  static const Color bezel = Color(0xFFE4EAF3);

  /// Nút phụ (ví dụ gửi yêu cầu ở ghép) `--alt`.
  static const Color alt = ink;

  /// Chữ trên nút phụ `--alt-fg`.
  static const Color onAlt = Color(0xFFFFFFFF);

  /// Ảnh phòng A: 165°, #D5E4F2 → #9BB4C9 → #5E7C90.
  static const LinearGradient photoA = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFD5E4F2),
      Color(0xFF9BB4C9),
      Color(0xFF5E7C90),
    ],
    stops: [0.0, 0.48, 1.0],
  );

  /// Ảnh phòng B: 200°, #EEF3F8 → #C5D4E2 → #6D88A0.
  static const LinearGradient photoB = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      Color(0xFFEEF3F8),
      Color(0xFFC5D4E2),
      Color(0xFF6D88A0),
    ],
    stops: [0.0, 0.50, 1.0],
  );
}

/// Bo góc đúng số trên moodboard.
class PhongSangRadii {
  const PhongSangRadii._();

  /// Thẻ phòng, thẻ thống kê `--radius-card` 8.
  static const double card = 8;

  /// Nút, ô tìm `--radius-ctl` 8.
  static const double control = 8;

  /// Khung điện thoại `--radius-phone` 18.
  static const double phone = 18;

  /// Chip lọc `--pill-radius` 6.
  static const double pill = 6;

  /// Avatar `--avatar-radius` 6.
  static const double avatar = 6;

  /// Tag lối sống `--tag-radius` 4.
  static const double tag = 4;

  /// Badge hàng chờ `--badge-radius` 4.
  static const double badge = 4;

  /// Nhãn trạng thái phòng.
  static const double status = 4;
}

/// Cỡ chữ trên bảng "Chữ" của moodboard. Tracking CSS `-0.02em`.
class PhongSangText {
  const PhongSangText._();

  static double tracking(double fontSize) => fontSize * -0.02;

  static TextStyle get display => GoogleFonts.inter(
        fontSize: 40,
        fontWeight: FontWeight.w600,
        height: 1.15,
        letterSpacing: tracking(40),
        color: PhongSangColors.ink,
      );

  /// Tiêu đề màn 28 / 600.
  static TextStyle get screenTitle => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: tracking(28),
        color: PhongSangColors.ink,
      );

  /// Tên phòng, title app bar 18 / 600.
  static TextStyle get roomName => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: tracking(18),
        color: PhongSangColors.ink,
      );

  /// Giá lớn trên bảng chữ 32 / 600.
  static TextStyle get priceLarge => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: tracking(32),
        color: PhongSangColors.price,
      );

  /// Giá trên thẻ 15 / 600.
  static TextStyle get price => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: tracking(15),
        color: PhongSangColors.price,
      );

  /// Nội dung 14 / 400.
  static TextStyle get body => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: PhongSangColors.muted,
      );

  /// Ô tìm 13 / 500, màu mực.
  static TextStyle get search => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: PhongSangColors.ink,
      );

  /// Nút 13 / 600.
  static TextStyle get button => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: PhongSangColors.onAccent,
      );

  /// Chú thích, meta 12 / 400.
  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: PhongSangColors.muted,
      );

  /// Tag, badge, trạng thái 11–12 / 600.
  static TextStyle label({
    required Color color,
    double fontSize = 12,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: color,
    );
  }
}

/// Token không nằm trong [ColorScheme]: giá, trạng thái, tag, bóng, ảnh.
@immutable
class PhongSangTokens extends ThemeExtension<PhongSangTokens> {
  const PhongSangTokens({
    required this.price,
    required this.priceSoft,
    required this.muted,
    required this.line,
    required this.hold,
    required this.live,
    required this.empty,
    required this.bezel,
    required this.tagBackground,
    required this.tagForeground,
    required this.badgeBackground,
    required this.badgeForeground,
    required this.badgeOkBackground,
    required this.badgeOkForeground,
    required this.photoA,
    required this.photoB,
    required this.shadow,
  });

  final Color price;
  final Color priceSoft;
  final Color muted;
  final Color line;
  final Color hold;
  final Color live;
  final Color empty;
  final Color bezel;
  final Color tagBackground;
  final Color tagForeground;
  final Color badgeBackground;
  final Color badgeForeground;
  final Color badgeOkBackground;
  final Color badgeOkForeground;
  final LinearGradient photoA;
  final LinearGradient photoB;

  /// `0 12px 28px rgba(16, 24, 40, 0.08)`.
  final List<BoxShadow> shadow;

  static const PhongSangTokens standard = PhongSangTokens(
    price: PhongSangColors.price,
    priceSoft: PhongSangColors.priceSoft,
    muted: PhongSangColors.muted,
    line: PhongSangColors.line,
    hold: PhongSangColors.hold,
    live: PhongSangColors.live,
    empty: PhongSangColors.empty,
    bezel: PhongSangColors.bezel,
    tagBackground: PhongSangColors.priceSoft,
    tagForeground: PhongSangColors.ink,
    badgeBackground: PhongSangColors.accentSoft,
    badgeForeground: PhongSangColors.accent,
    badgeOkBackground: PhongSangColors.accentSoft,
    badgeOkForeground: PhongSangColors.live,
    photoA: PhongSangColors.photoA,
    photoB: PhongSangColors.photoB,
    shadow: [
      BoxShadow(
        color: Color.fromRGBO(16, 24, 40, 0.08),
        offset: Offset(0, 12),
        blurRadius: 28,
      ),
    ],
  );

  static PhongSangTokens of(BuildContext context) {
    final tokens = Theme.of(context).extension<PhongSangTokens>();
    assert(tokens != null, 'Gắn PhongSangTheme.light vào MaterialApp.theme');
    return tokens ?? standard;
  }

  /// Tag lối sống: nền xám nhạt, chữ mực, bo 4, có viền.
  BoxDecoration get tagDecoration => BoxDecoration(
        color: tagBackground,
        borderRadius: BorderRadius.circular(PhongSangRadii.tag),
        border: Border.all(color: line),
      );

  /// Badge "Chờ duyệt": nền xanh nhạt, chữ xanh, bo 4.
  BoxDecoration get badgeDecoration => BoxDecoration(
        color: badgeBackground,
        borderRadius: BorderRadius.circular(PhongSangRadii.badge),
      );

  /// Badge "Đã chuyển": nền xanh nhạt, chữ đang ở.
  BoxDecoration get badgeOkDecoration => BoxDecoration(
        color: badgeOkBackground,
        borderRadius: BorderRadius.circular(PhongSangRadii.badge),
      );

  /// Nhãn trạng thái: nền thẻ, viền, không chấm tròn.
  BoxDecoration get statusDecoration => BoxDecoration(
        color: PhongSangColors.card,
        borderRadius: BorderRadius.circular(PhongSangRadii.status),
        border: Border.all(color: line),
      );

  TextStyle statusStyle(Color color) => PhongSangText.label(color: color);

  @override
  PhongSangTokens copyWith({
    Color? price,
    Color? priceSoft,
    Color? muted,
    Color? line,
    Color? hold,
    Color? live,
    Color? empty,
    Color? bezel,
    Color? tagBackground,
    Color? tagForeground,
    Color? badgeBackground,
    Color? badgeForeground,
    Color? badgeOkBackground,
    Color? badgeOkForeground,
    LinearGradient? photoA,
    LinearGradient? photoB,
    List<BoxShadow>? shadow,
  }) {
    return PhongSangTokens(
      price: price ?? this.price,
      priceSoft: priceSoft ?? this.priceSoft,
      muted: muted ?? this.muted,
      line: line ?? this.line,
      hold: hold ?? this.hold,
      live: live ?? this.live,
      empty: empty ?? this.empty,
      bezel: bezel ?? this.bezel,
      tagBackground: tagBackground ?? this.tagBackground,
      tagForeground: tagForeground ?? this.tagForeground,
      badgeBackground: badgeBackground ?? this.badgeBackground,
      badgeForeground: badgeForeground ?? this.badgeForeground,
      badgeOkBackground: badgeOkBackground ?? this.badgeOkBackground,
      badgeOkForeground: badgeOkForeground ?? this.badgeOkForeground,
      photoA: photoA ?? this.photoA,
      photoB: photoB ?? this.photoB,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  PhongSangTokens lerp(ThemeExtension<PhongSangTokens>? other, double t) {
    if (other is! PhongSangTokens) return this;
    return PhongSangTokens(
      price: Color.lerp(price, other.price, t)!,
      priceSoft: Color.lerp(priceSoft, other.priceSoft, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      hold: Color.lerp(hold, other.hold, t)!,
      live: Color.lerp(live, other.live, t)!,
      empty: Color.lerp(empty, other.empty, t)!,
      bezel: Color.lerp(bezel, other.bezel, t)!,
      tagBackground: Color.lerp(tagBackground, other.tagBackground, t)!,
      tagForeground: Color.lerp(tagForeground, other.tagForeground, t)!,
      badgeBackground: Color.lerp(badgeBackground, other.badgeBackground, t)!,
      badgeForeground: Color.lerp(badgeForeground, other.badgeForeground, t)!,
      badgeOkBackground:
          Color.lerp(badgeOkBackground, other.badgeOkBackground, t)!,
      badgeOkForeground:
          Color.lerp(badgeOkForeground, other.badgeOkForeground, t)!,
      photoA: LinearGradient.lerp(photoA, other.photoA, t) ?? photoA,
      photoB: LinearGradient.lerp(photoB, other.photoB, t) ?? photoB,
      shadow: BoxShadow.lerpList(shadow, other.shadow, t) ?? shadow,
    );
  }
}

/// [ThemeData] Material 3 cho Phòng sáng.
class PhongSangTheme {
  const PhongSangTheme._();

  static ThemeData get light {
    final base = GoogleFonts.interTextTheme().apply(
      bodyColor: PhongSangColors.ink,
      displayColor: PhongSangColors.ink,
    );

    final textTheme = base.copyWith(
      displayLarge: PhongSangText.display,
      headlineMedium: PhongSangText.screenTitle,
      titleLarge: PhongSangText.roomName,
      titleMedium: PhongSangText.price,
      bodyLarge: PhongSangText.body,
      bodyMedium: PhongSangText.caption.copyWith(fontSize: 13),
      bodySmall: PhongSangText.caption,
      labelLarge: PhongSangText.button,
    );

    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(PhongSangRadii.control)),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: PhongSangColors.paper,
      canvasColor: PhongSangColors.paper,
      dividerColor: PhongSangColors.line,
      splashColor: PhongSangColors.accent.withValues(alpha: 0.08),
      highlightColor: PhongSangColors.accent.withValues(alpha: 0.04),
      extensions: const [PhongSangTokens.standard],
      colorScheme: const ColorScheme.light(
        primary: PhongSangColors.accent,
        onPrimary: PhongSangColors.onAccent,
        primaryContainer: PhongSangColors.accentSoft,
        onPrimaryContainer: PhongSangColors.accent,
        secondary: PhongSangColors.alt,
        onSecondary: PhongSangColors.onAlt,
        secondaryContainer: PhongSangColors.priceSoft,
        onSecondaryContainer: PhongSangColors.ink,
        surface: PhongSangColors.card,
        onSurface: PhongSangColors.ink,
        onSurfaceVariant: PhongSangColors.muted,
        outline: PhongSangColors.line,
        outlineVariant: PhongSangColors.line,
        error: PhongSangColors.hold,
        onError: PhongSangColors.onAccent,
        shadow: Color(0xFF101828),
      ),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: PhongSangColors.paper,
        foregroundColor: PhongSangColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: PhongSangText.roomName,
      ),
      cardTheme: const CardThemeData(
        color: PhongSangColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(PhongSangRadii.card)),
          side: BorderSide(color: PhongSangColors.line),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: PhongSangColors.accent,
          foregroundColor: PhongSangColors.onAccent,
          disabledBackgroundColor: PhongSangColors.line,
          disabledForegroundColor: PhongSangColors.muted,
          elevation: 0,
          minimumSize: const Size.fromHeight(44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          shape: shape,
          textStyle: PhongSangText.button,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PhongSangColors.accent,
          foregroundColor: PhongSangColors.onAccent,
          elevation: 0,
          minimumSize: const Size.fromHeight(44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          shape: shape,
          textStyle: PhongSangText.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PhongSangColors.ink,
          backgroundColor: PhongSangColors.card,
          side: const BorderSide(color: PhongSangColors.line),
          minimumSize: const Size.fromHeight(44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          shape: shape,
          textStyle: PhongSangText.button.copyWith(color: PhongSangColors.ink),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: PhongSangColors.accent,
          textStyle: PhongSangText.button.copyWith(
            color: PhongSangColors.accent,
          ),
          shape: shape,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: PhongSangColors.card,
        selectedColor: PhongSangColors.accent,
        disabledColor: PhongSangColors.priceSoft,
        labelStyle: PhongSangText.label(
          color: PhongSangColors.ink,
          fontSize: 12,
        ),
        secondaryLabelStyle: PhongSangText.label(
          color: PhongSangColors.onAccent,
          fontSize: 12,
        ),
        side: const BorderSide(color: PhongSangColors.line),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(PhongSangRadii.pill)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        showCheckmark: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PhongSangColors.card,
        hintStyle: PhongSangText.search.copyWith(color: PhongSangColors.muted),
        labelStyle: PhongSangText.search,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(PhongSangRadii.control)),
          borderSide: BorderSide(color: PhongSangColors.accent),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(PhongSangRadii.control)),
          borderSide: BorderSide(color: PhongSangColors.accent),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(PhongSangRadii.control)),
          borderSide: BorderSide(color: PhongSangColors.accent, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(PhongSangRadii.control)),
          borderSide: BorderSide(color: PhongSangColors.hold),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: PhongSangColors.line,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: PhongSangColors.accent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: PhongSangColors.ink,
        contentTextStyle: PhongSangText.body.copyWith(
          color: PhongSangColors.card,
        ),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(PhongSangRadii.control)),
        ),
      ),
    );
  }

  /// Nút mực: "Gửi yêu cầu ở ghép".
  static ButtonStyle get altButton => ElevatedButton.styleFrom(
        backgroundColor: PhongSangColors.alt,
        foregroundColor: PhongSangColors.onAlt,
        elevation: 0,
        minimumSize: const Size.fromHeight(44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(PhongSangRadii.control)),
        ),
        textStyle: PhongSangText.button.copyWith(color: PhongSangColors.onAlt),
      );
}
