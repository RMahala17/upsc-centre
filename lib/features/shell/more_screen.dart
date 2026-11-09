import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/theme_mode_button.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static const _items = [
    ('/optional', 'Anthropology Optional', Icons.psychology_outlined),
    ('/timer', 'Study Timer', Icons.timer_outlined),
    ('/answers', 'Answer Writing', Icons.edit_note_outlined),
    ('/pyq', 'PYQ Manager', Icons.quiz_outlined),
    ('/tests', 'Test Series', Icons.fact_check_outlined),
    ('/notes', 'Current Affairs', Icons.newspaper_outlined),
    ('/analytics', 'Analytics', Icons.insights_outlined),
    ('/backup', 'Backup & Settings', Icons.backup_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
        actions: const [ThemeModeButton()],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final (path, label, icon) = _items[i];
          return Card(
            child: ListTile(
              leading: Icon(icon),
              title: Text(label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(path),
            ),
          );
        },
      ),
    );
  }
}
