import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_mode_controller.dart';
import '../answers/answer_controller.dart';
import '../anthropology/anthro_controller.dart';
import '../currentaffairs/ca_controller.dart';
import '../dashboard/dashboard_prefs.dart';
import '../planner/planner_controller.dart';
import '../pyq/pyq_controller.dart';
import '../revision/revision_controller.dart';
import '../syllabus/syllabus_controller.dart';
import '../tests/test_controller.dart';
import '../timer/sessions_controller.dart';
import '../timer/timer_controller.dart';

/// Re-reads every store from the database. Call after a restore so no screen
/// keeps showing the old data.
void reloadAllProviders(WidgetRef ref) {
  ref.read(syllabusProvider.notifier).reload();
  ref.read(anthroProvider.notifier).reload();
  ref.read(revisionProvider.notifier).reload();
  ref.read(plannerProvider.notifier).reload();
  ref.read(sessionsProvider.notifier).reload();
  ref.read(timerProvider.notifier).reload();
  ref.read(answerProvider.notifier).reload();
  ref.read(pyqProvider.notifier).reload();
  ref.read(testProvider.notifier).reload();
  ref.read(caProvider.notifier).reload();
  ref.read(dashboardPrefsProvider.notifier).reload();
  ref.read(themeModeProvider.notifier).reload();
}
