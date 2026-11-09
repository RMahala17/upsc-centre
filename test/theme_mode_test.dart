import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:upsc_command_centre/core/theme/app_theme.dart';
import 'package:upsc_command_centre/core/theme/theme_mode_controller.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('theme mode setting', () {
    test('parses saved values, defaulting to system', () {
      expect(parseThemeMode('light'), ThemeMode.light);
      expect(parseThemeMode('dark'), ThemeMode.dark);
      expect(parseThemeMode('system'), ThemeMode.system);
      expect(parseThemeMode(null), ThemeMode.system);
      expect(parseThemeMode('purple'), ThemeMode.system);
      expect(parseThemeMode(42), ThemeMode.system);
    });

    test('names round-trip', () {
      for (final m in ThemeMode.values) {
        expect(parseThemeMode(themeModeName(m)), m);
      }
    });

    test('labels', () {
      expect(themeModeLabel(ThemeMode.light), 'Light');
      expect(themeModeLabel(ThemeMode.system), 'System');
      expect(themeModeLabel(ThemeMode.dark), 'Dark');
    });
  });

  group('themes', () {
    test('light and dark differ in brightness and background', () {
      final light = AppTheme.light();
      final dark = AppTheme.dark();
      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(light.scaffoldBackgroundColor, LightColors.bg);
      expect(dark.scaffoldBackgroundColor, AppColors.bg);
    });

    test('accent colours stay readable on every surface', () {
      final surfaces = [
        AppColors.bg,
        AppColors.card,
        LightColors.bg,
        LightColors.card,
      ];
      const accents = {
        'muted': AppColors.muted,
        'teal': AppColors.teal,
        'danger': AppColors.danger,
        'violet': AppColors.violet,
        'amber': Color(0xFFD97706),
      };
      for (final e in accents.entries) {
        for (final s in surfaces) {
          expect(_contrast(e.value, s), greaterThanOrEqualTo(3.0),
              reason: '${e.key} on $s');
        }
      }
    });

    test('body text has strong contrast in both themes', () {
      expect(_contrast(AppColors.text, AppColors.bg), greaterThan(7));
      expect(_contrast(LightColors.text, LightColors.bg), greaterThan(7));
    });
  });
}
