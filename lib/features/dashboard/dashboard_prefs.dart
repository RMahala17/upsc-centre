import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/db.dart';
import '../../core/storage/settings_store.dart';
import 'dashboard_logic.dart';

/// An exam date the dashboard can count down to. Dates are never pre-filled:
/// the user enters them from the official notification.
class ExamMilestone {
  const ExamMilestone(this.key, this.label);
  final String key;
  final String label;
}

const kExamMilestones = [
  ExamMilestone('upsc_prelims', 'UPSC Prelims'),
  ExamMilestone('upsc_mains', 'UPSC Mains'),
  ExamMilestone('uppcs_prelims', 'UPPCS Prelims'),
  ExamMilestone('uppcs_mains', 'UPPCS Mains'),
];

const int kDefaultDailyGoalMin = 6 * 60;
const int kMinDailyGoalMin = 30;
const int kMaxDailyGoalMin = 16 * 60;

class DashboardPrefsKeys {
  static const dailyGoal = 'dash_daily_goal_min';
  static String exam(String milestoneKey) => 'dash_exam_$milestoneKey';
}

class DashboardPrefsState {
  const DashboardPrefsState({
    required this.dailyGoalMin,
    required this.examDates,
  });

  final int dailyGoalMin;

  /// Milestone key -> "yyyy-MM-dd". Milestones without a date are absent.
  final Map<String, String> examDates;
}

/// Daily study goal and exam dates, kept in the `settings` collection (so
/// they are part of backups).
class DashboardPrefsController extends Notifier<DashboardPrefsState> {
  final Db _db = Db.instance;

  @override
  DashboardPrefsState build() => _load();

  DashboardPrefsState _load() {
    final dates = <String, String>{};
    for (final m in kExamMilestones) {
      final v = _db.get(
        Collections.settings,
        DashboardPrefsKeys.exam(m.key),
      )?['value'];
      if (v is String && isValidDateKey(v)) dates[m.key] = v;
    }
    final goal = SettingsStore.getInt(
      DashboardPrefsKeys.dailyGoal,
      kDefaultDailyGoalMin,
    );
    return DashboardPrefsState(
      dailyGoalMin: goal.clamp(kMinDailyGoalMin, kMaxDailyGoalMin).toInt(),
      examDates: dates,
    );
  }

  /// Re-read from storage (e.g. after a backup restore).
  void reload() => state = _load();

  Future<void> save({
    required int dailyGoalMin,
    required Map<String, String> examDates,
  }) async {
    final goal =
        dailyGoalMin.clamp(kMinDailyGoalMin, kMaxDailyGoalMin).toInt();
    await SettingsStore.setInt(DashboardPrefsKeys.dailyGoal, goal);
    for (final m in kExamMilestones) {
      final key = DashboardPrefsKeys.exam(m.key);
      final value = examDates[m.key];
      if (value != null && isValidDateKey(value)) {
        await _db.put(Collections.settings, key, {'value': value});
      } else {
        await _db.delete(Collections.settings, key);
      }
    }
    state = _load();
  }
}

final dashboardPrefsProvider =
    NotifierProvider<DashboardPrefsController, DashboardPrefsState>(
  DashboardPrefsController.new,
);
