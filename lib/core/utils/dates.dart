/// Calendar-day helpers. Dates in storage are "yyyy-MM-dd" strings so that
/// time zones and daylight-saving never shift a day.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int daysBetween(DateTime a, DateTime b) => DateTime.utc(b.year, b.month, b.day)
    .difference(DateTime.utc(a.year, a.month, a.day))
    .inDays;

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime parseDateKey(String s) {
  final parts = s.split('-');
  if (parts.length == 3) {
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y != null && m != null && d != null) return DateTime(y, m, d);
  }
  return dateOnly(DateTime.now());
}
