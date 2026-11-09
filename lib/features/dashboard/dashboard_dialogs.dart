import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/parsing.dart';
import 'dashboard_prefs.dart';

/// Edits the daily goal and exam dates. Returns the new settings, or null if
/// cancelled.
Future<DashboardPrefsState?> showDashboardSettingsDialog(
  BuildContext context, {
  required DashboardPrefsState current,
}) {
  return showDialog<DashboardPrefsState>(
    context: context,
    builder: (_) => _SettingsDialog(current: current),
  );
}

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog({required this.current});

  final DashboardPrefsState current;

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late final TextEditingController _goal = TextEditingController(
    text: formatNumber(widget.current.dailyGoalMin / 60),
  );
  late final Map<String, String> _dates =
      Map<String, String>.of(widget.current.examDates);
  String? _goalError;

  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  Future<void> _pick(String key) async {
    final first = DateTime(2020);
    final last = DateTime(2035);
    final today = dateOnly(DateTime.now());
    var initial = _dates[key] == null ? today : parseDateKey(_dates[key]!);
    if (initial.isBefore(first) || initial.isAfter(last)) initial = today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      setState(() => _dates[key] = dateKey(picked));
    }
  }

  void _submit() {
    final hours = parseDecimal(_goal.text);
    final minHours = kMinDailyGoalMin / 60;
    final maxHours = kMaxDailyGoalMin / 60;
    if (hours == null || hours < minHours || hours > maxHours) {
      setState(() {
        _goalError = 'Enter hours from ${formatNumber(minHours)} to '
            '${formatNumber(maxHours)}.';
      });
      return;
    }
    Navigator.pop(
      context,
      DashboardPrefsState(
        dailyGoalMin: (hours * 60).round(),
        examDates: Map<String, String>.of(_dates),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Goal and exam dates'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _goal,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Daily study goal (hours)',
                  errorText: _goalError,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Exam dates',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Not pre-filled. Enter them from the official notification '
                'and the dashboard will count down.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              for (final m in kExamMilestones)
                Row(
                  children: [
                    Expanded(child: Text(m.label)),
                    TextButton(
                      onPressed: () => _pick(m.key),
                      child: Text(
                        _dates[m.key] == null
                            ? 'Set date'
                            : DateFormat('d MMM y')
                                .format(parseDateKey(_dates[m.key]!)),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: _dates[m.key] == null
                          ? null
                          : IconButton(
                              tooltip: 'Clear date',
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () =>
                                  setState(() => _dates.remove(m.key)),
                            ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
