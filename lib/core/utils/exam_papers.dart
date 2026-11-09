/// Exam papers shared by answer writing, the PYQ manager and tests.
///
/// Stored as plain strings so backups stay readable. Unknown values (for
/// example from a future version) fall back safely in [normalize].
class ExamPaper {
  static const prelimsGs = 'prelims_gs';
  static const csat = 'csat';
  static const essay = 'essay';
  static const gs1 = 'gs1';
  static const gs2 = 'gs2';
  static const gs3 = 'gs3';
  static const gs4 = 'gs4';
  static const anthro1 = 'anthro1';
  static const anthro2 = 'anthro2';

  static const prelims = [prelimsGs, csat];
  static const mains = [essay, gs1, gs2, gs3, gs4, anthro1, anthro2];
  static const all = [...prelims, ...mains];

  static bool isPrelims(String p) => prelims.contains(p);

  static String label(String p) {
    switch (p) {
      case prelimsGs:
        return 'Prelims GS';
      case csat:
        return 'CSAT';
      case essay:
        return 'Essay';
      case gs1:
        return 'GS 1';
      case gs2:
        return 'GS 2';
      case gs3:
        return 'GS 3';
      case gs4:
        return 'GS 4';
      case anthro1:
        return 'Anthropology 1';
      case anthro2:
        return 'Anthropology 2';
      default:
        return p;
    }
  }

  static String normalize(Object? v, {required String fallback}) {
    for (final p in all) {
      if (p == v) return p;
    }
    return fallback;
  }
}
