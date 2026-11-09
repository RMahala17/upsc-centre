import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/platform/platform_services.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';

class UpscApp extends ConsumerWidget {
  const UpscApp({super.key});

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'UPSC Command Centre',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      routerConfig: appRouter,
      builder: (context, child) {
        // Keep the browser's address bar in step with the current theme.
        setBrowserThemeColor(_hex(Theme.of(context).scaffoldBackgroundColor));
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
