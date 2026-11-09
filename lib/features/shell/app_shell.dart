import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../timer/running_timer_bar.dart';

class _Dest {
  final String path;
  final String label;
  final IconData icon;
  const _Dest(this.path, this.label, this.icon);
}

const _primary = [
  _Dest('/', 'Home', Icons.dashboard_outlined),
  _Dest('/planner', 'Planner', Icons.event_note_outlined),
  _Dest('/syllabus', 'Syllabus', Icons.menu_book_outlined),
  _Dest('/revision', 'Revision', Icons.replay_outlined),
  _Dest('/more', 'More', Icons.apps_outlined),
];

class AppShell extends StatelessWidget {
  final String location;
  final Widget child;
  const AppShell({super.key, required this.location, required this.child});

  int get _index {
    for (var i = 0; i < _primary.length - 1; i++) {
      final p = _primary[i].path;
      if (p == '/' ? location == '/' : location.startsWith(p)) return i;
    }
    return _primary.length - 1; // everything else lives under "More"
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 800;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (i) => context.go(_primary[i].path),
              destinations: [
                for (final d in _primary)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    label: Text(d.label),
                  ),
              ],
            ),
            Expanded(
              child: Column(
                children: [
                  RunningTimerBar(location: location),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            RunningTimerBar(location: location),
            Expanded(child: child),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => context.go(_primary[i].path),
        destinations: [
          for (final d in _primary)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }
}
