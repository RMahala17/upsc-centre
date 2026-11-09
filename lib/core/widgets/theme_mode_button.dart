import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_mode_controller.dart';

IconData themeModeIcon(ThemeMode m) {
  switch (m) {
    case ThemeMode.light:
      return Icons.light_mode_outlined;
    case ThemeMode.dark:
      return Icons.dark_mode_outlined;
    case ThemeMode.system:
      return Icons.brightness_auto_outlined;
  }
}

const _order = [ThemeMode.light, ThemeMode.system, ThemeMode.dark];

/// App bar button that opens a Light / System / Dark menu.
class ThemeModeButton extends ConsumerWidget {
  const ThemeModeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return PopupMenuButton<ThemeMode>(
      tooltip: 'Appearance',
      icon: Icon(themeModeIcon(mode)),
      onSelected: (m) => ref.read(themeModeProvider.notifier).set(m),
      itemBuilder: (_) => [
        for (final m in _order)
          CheckedPopupMenuItem<ThemeMode>(
            value: m,
            checked: m == mode,
            child: Text(themeModeLabel(m)),
          ),
      ],
    );
  }
}

/// Inline three-way selector (used on the Backup & Settings screen).
class ThemeModeSelector extends ConsumerWidget {
  const ThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return SegmentedButton<ThemeMode>(
      segments: [
        for (final m in _order)
          ButtonSegment<ThemeMode>(
            value: m,
            icon: Icon(themeModeIcon(m)),
            label: Text(themeModeLabel(m)),
          ),
      ],
      selected: {mode},
      onSelectionChanged: (s) =>
          ref.read(themeModeProvider.notifier).set(s.first),
    );
  }
}
