import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/db.dart';

const String kThemeModeKey = 'theme_mode';

/// Unknown or missing values mean "follow the system".
ThemeMode parseThemeMode(Object? v) {
  switch (v) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

String themeModeName(ThemeMode m) {
  switch (m) {
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
  }
}

String themeModeLabel(ThemeMode m) {
  switch (m) {
    case ThemeMode.light:
      return 'Light';
    case ThemeMode.dark:
      return 'Dark';
    case ThemeMode.system:
      return 'System';
  }
}

/// The appearance setting, kept in the `settings` collection (so it is part of
/// backups). Default: follow the device.
class ThemeModeController extends Notifier<ThemeMode> {
  final Db _db = Db.instance;

  @override
  ThemeMode build() => _load();

  ThemeMode _load() =>
      parseThemeMode(_db.get(Collections.settings, kThemeModeKey)?['value']);

  /// Re-read from storage (e.g. after a backup restore).
  void reload() => state = _load();

  Future<void> set(ThemeMode mode) async {
    await _db.put(Collections.settings, kThemeModeKey, {
      'value': themeModeName(mode),
    });
    state = mode;
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
