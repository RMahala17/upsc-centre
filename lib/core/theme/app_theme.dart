import 'package:flutter/material.dart';

/// Colours shared by both themes. The accent colours were chosen to stay
/// readable (about 3:1 or better) on both the dark navy and the white
/// surfaces. `bg`, `card`, `border` and `text` are the DARK theme's surface
/// colours; screens should use `Theme.of(context)` for surfaces so they follow
/// the light / dark setting.
class AppColors {
  static const bg = Color(0xFF0B0F19);
  static const card = Color(0xFF131B2E);
  static const border = Color(0xFF1F2A44);
  static const violet = Color(0xFF8B5CF6);
  static const teal = Color(0xFF0D9488);
  static const text = Color(0xFFE5E7EB);
  static const muted = Color(0xFF6F7F95);
  static const danger = Color(0xFFEF4444);
}

/// Surface colours of the light theme.
class LightColors {
  static const bg = Color(0xFFF8FAFC);
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E8F0);
  static const text = Color(0xFF0F172A);
}

class AppTheme {
  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final bg = dark ? AppColors.bg : LightColors.bg;
    final card = dark ? AppColors.card : LightColors.card;
    final border = dark ? AppColors.border : LightColors.border;
    final text = dark ? AppColors.text : LightColors.text;

    final ColorScheme scheme;
    if (dark) {
      scheme = ColorScheme.dark(
        primary: AppColors.violet,
        secondary: AppColors.teal,
        surface: card,
        onSurface: text,
        error: AppColors.danger,
      );
    } else {
      scheme = ColorScheme.light(
        primary: AppColors.violet,
        secondary: AppColors.teal,
        surface: card,
        onSurface: text,
        error: AppColors.danger,
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border),
        ),
      ),
      dialogTheme: DialogThemeData(backgroundColor: card),
      popupMenuTheme: PopupMenuThemeData(color: card),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: AppColors.violet.withValues(alpha: dark ? 0.25 : 0.15),
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(fontSize: 12, color: text),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: card,
        indicatorColor: AppColors.violet.withValues(alpha: dark ? 0.25 : 0.15),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
      ),
      dividerColor: border,
    );
  }
}
