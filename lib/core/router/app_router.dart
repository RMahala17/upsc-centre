import 'package:go_router/go_router.dart';

import '../../features/analytics/analytics_screen.dart';
import '../../features/answers/answers_screen.dart';
import '../../features/anthropology/anthro_chapter_screen.dart';
import '../../features/anthropology/anthropology_screen.dart';
import '../../features/backup/backup_screen.dart';
import '../../features/currentaffairs/ca_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/planner/planner_screen.dart';
import '../../features/pyq/pyq_screen.dart';
import '../../features/revision/cycle_detail_screen.dart';
import '../../features/revision/revision_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/shell/more_screen.dart';
import '../../features/syllabus/history_setup_screen.dart';
import '../../features/syllabus/subject_detail_screen.dart';
import '../../features/syllabus/syllabus_screen.dart';
import '../../features/tests/tests_screen.dart';
import '../../features/timer/timer_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/planner',
          builder: (context, state) => const PlannerScreen(),
        ),
        GoRoute(
          path: '/syllabus',
          builder: (context, state) => const SyllabusScreen(),
          routes: [
            GoRoute(
              path: 'setup',
              builder: (context, state) => const HistorySetupScreen(),
            ),
            GoRoute(
              path: ':id',
              builder: (context, state) => SubjectDetailScreen(
                subjectId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/revision',
          builder: (context, state) => const RevisionScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) => CycleDetailScreen(
                cycleId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
        GoRoute(path: '/more', builder: (c, s) => const MoreScreen()),
        GoRoute(
          path: '/optional',
          builder: (context, state) => const AnthropologyScreen(),
          routes: [
            GoRoute(
              path: 'chapter/:id',
              builder: (context, state) => AnthroChapterScreen(
                chapterId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/timer',
          builder: (context, state) => const TimerScreen(),
        ),
        GoRoute(
          path: '/answers',
          builder: (context, state) => const AnswersScreen(),
        ),
        GoRoute(
          path: '/pyq',
          builder: (context, state) => const PyqScreen(),
        ),
        GoRoute(
          path: '/tests',
          builder: (context, state) => const TestsScreen(),
        ),
        GoRoute(
          path: '/notes',
          builder: (context, state) => const CurrentAffairsScreen(),
        ),
        GoRoute(
          path: '/analytics',
          builder: (context, state) => const AnalyticsScreen(),
        ),
        GoRoute(
          path: '/backup',
          builder: (context, state) => const BackupScreen(),
        ),
      ],
    ),
  ],
);
