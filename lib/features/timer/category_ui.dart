import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'models/session_models.dart';

IconData categoryIcon(String c) {
  switch (c) {
    case StudyCategory.gs:
      return Icons.menu_book_outlined;
    case StudyCategory.anthro:
      return Icons.psychology_outlined;
    case StudyCategory.revision:
      return Icons.replay_outlined;
    case StudyCategory.pyq:
      return Icons.quiz_outlined;
    case StudyCategory.answers:
      return Icons.edit_note_outlined;
    case StudyCategory.test:
      return Icons.fact_check_outlined;
    case StudyCategory.prelims:
      return Icons.checklist_outlined;
    case StudyCategory.currentAffairs:
      return Icons.newspaper_outlined;
    default:
      return Icons.bookmark_border;
  }
}

Color categoryColor(String c) {
  switch (c) {
    case StudyCategory.gs:
      return AppColors.violet;
    case StudyCategory.anthro:
      return AppColors.teal;
    case StudyCategory.revision:
      return const Color(0xFFFBBF24);
    case StudyCategory.pyq:
      return const Color(0xFF60A5FA);
    case StudyCategory.answers:
      return const Color(0xFFF472B6);
    case StudyCategory.test:
      return const Color(0xFFFB923C);
    case StudyCategory.prelims:
      return const Color(0xFF34D399);
    case StudyCategory.currentAffairs:
      return const Color(0xFFA78BFA);
    default:
      return AppColors.muted;
  }
}

/// Single-choice category picker.
class CategoryChips extends StatelessWidget {
  const CategoryChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in StudyCategory.all)
          ChoiceChip(
            label: Text(StudyCategory.label(c)),
            selected: c == selected,
            onSelected: (_) => onChanged(c),
          ),
      ],
    );
  }
}
