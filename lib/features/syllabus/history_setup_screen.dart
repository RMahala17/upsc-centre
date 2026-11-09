import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/page_body.dart';
import 'data/seed_data.dart';
import 'models/syllabus_models.dart';
import 'syllabus_controller.dart';

class _Row {
  _Row(this.seed, this.subject, {required this.hasLectures})
      : completed = TextEditingController(text: '${seed.completed}'),
        total = TextEditingController(text: '${seed.total}');

  final HistoricalSeed seed;
  final Subject subject;
  final bool hasLectures;
  final TextEditingController completed;
  final TextEditingController total;

  void dispose() {
    completed.dispose();
    total.dispose();
  }
}

class HistorySetupScreen extends ConsumerStatefulWidget {
  const HistorySetupScreen({super.key});

  @override
  ConsumerState<HistorySetupScreen> createState() => _HistorySetupScreenState();
}

class _HistorySetupScreenState extends ConsumerState<HistorySetupScreen> {
  late final List<_Row> _rows;

  @override
  void initState() {
    super.initState();
    final st = ref.read(syllabusProvider);
    _rows = [
      for (final h in historicalSeed)
        if (st.subjectById(h.subjectId) != null)
          _Row(
            h,
            st.subjectById(h.subjectId)!,
            hasLectures: st.lecturesOf(h.subjectId).isNotEmpty,
          ),
    ];
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _load() async {
    final loads = <HistoricalLoad>[];
    for (final r in _rows) {
      if (r.hasLectures) continue;
      final c = int.tryParse(r.completed.text.trim());
      final t = int.tryParse(r.total.text.trim());
      if (c == null || t == null || c < 0 || t < 0) {
        _toast('Enter whole numbers for ${r.subject.name}.');
        return;
      }
      if (c > t) {
        _toast('Completed cannot be more than total for ${r.subject.name}.');
        return;
      }
      if (t > 500) {
        _toast('Total looks too large for ${r.subject.name} (max 500).');
        return;
      }
      loads.add(HistoricalLoad(subjectId: r.subject.id, completed: c, total: t));
    }

    final loaded = await ref.read(syllabusProvider.notifier).loadHistorical(loads);
    if (!mounted) return;
    _toast(loaded == 0
        ? 'Nothing to load.'
        : 'Loaded lectures for $loaded subject${loaded == 1 ? '' : 's'}.');
    context.go('/syllabus');
  }

  Future<void> _skip() async {
    await ref.read(syllabusProvider.notifier).markHistoryHandled();
    if (!mounted) return;
    context.go('/syllabus');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Previous lecture counts')),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'These counts were reported earlier and may be out of date. '
                  'Edit them to match where you are now, then load. Lectures '
                  'are created as "Lecture 1, 2, 3…" and the first N are '
                  'marked completed. You can rename them later. '
                  'Subjects not listed here start empty.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final r in _rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.subject.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Reported earlier as: ${r.seed.label}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (r.hasLectures)
                          const Text(
                            'Already has lectures, so this one will be skipped.',
                            style: TextStyle(color: AppColors.muted),
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: r.completed,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Completed',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: r.total,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Total',
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            FilledButton(
              onPressed: _load,
              child: const Text('Load these counts'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _skip,
              child: const Text("Skip — I'll enter lectures myself"),
            ),
          ],
        ),
      ),
    );
  }
}
