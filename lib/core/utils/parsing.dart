/// Whole number within [min]..[max], or null when blank, invalid or out of
/// range.
int? parseIntInRange(String raw, {required int min, required int max}) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  final n = int.tryParse(t);
  if (n == null || n < min || n > max) return null;
  return n;
}

/// Decimal number (accepts "12,5" as well as "12.5"), or null when blank or
/// invalid.
double? parseDecimal(String raw) {
  final t = raw.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  final n = double.tryParse(t);
  if (n == null || n.isNaN || n.isInfinite) return null;
  return n;
}

/// "120", "120.5", "120.67": at most two decimals, no trailing zeros.
String formatNumber(double v) {
  final s = v.toStringAsFixed(2);
  var t = s.replaceFirst(RegExp(r'0+$'), '');
  if (t.endsWith('.')) t = t.substring(0, t.length - 1);
  if (t == '-0' || t.isEmpty) return '0';
  return t;
}
