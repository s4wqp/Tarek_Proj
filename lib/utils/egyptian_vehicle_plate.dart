/// Normalizes and validates Egyptian license plate strings from vision/OCR.
/// Expected display form: Western digits (3–4) then 2–3 Arabic letters, e.g. "7291 ف د ل".
class EgyptianVehiclePlate {
  EgyptianVehiclePlate._();

  static final RegExp _wellFormed = RegExp(
    r'^(\d{3,4})(\s+[\u0621-\u064A]){2,3}$',
  );

  /// Arabic-Indic and Persian digits → Western; collapse spaces.
  static String normalizeDigitsAndSpaces(String raw) {
    var t = raw.replaceAll(RegExp(r'[|\-–—_/،,:]'), ' ');
    final buf = StringBuffer();
    for (final r in t.runes) {
      const western = '0123456789';
      const indic = '٠١٢٣٤٥٦٧٨٩';
      final ch = String.fromCharCode(r);
      final i = indic.indexOf(ch);
      if (i >= 0) {
        buf.write(western[i]);
      } else if (western.contains(ch) || ch == ' ' || _isArabicLetterRune(r)) {
        buf.write(ch);
      }
    }
    return buf
        .toString()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _isArabicLetterRune(int r) =>
      r >= 0x0621 && r <= 0x064A;

  /// True if [normalized] matches "7291 ف د ل" style (digits + 2–3 spaced Arabic letters).
  static bool isWellFormed(String normalized) {
    if (normalized.isEmpty) return false;
    return _wellFormed.hasMatch(normalized);
  }

  /// Returns null if the string cannot be normalized to a valid plate.
  static String? acceptOrNull(String? raw) {
    if (raw == null) return null;
    var s = normalizeDigitsAndSpaces(raw);
    if (s.isEmpty) return null;
    if (isWellFormed(s)) return s;
    // Some models output letters then digits (RTL habit).
    final rev = RegExp(
            r'^((?:[\u0621-\u064A]\s*){2,3})\s+(\d{3,4})$')
        .firstMatch(s);
    if (rev != null) {
      final letterPart = rev.group(1)!;
      final digits = rev.group(2)!;
      final compact = letterPart.replaceAll(RegExp(r'\s+'), '');
      if (compact.length >= 2 && compact.length <= 3) {
        final spaced = compact.runes
            .map((r) => String.fromCharCode(r))
            .join(' ');
        s = '$digits $spaced';
        if (isWellFormed(s)) return s;
      }
    }
    // "7591 فنو" — letters run together without spaces.
    final merged = RegExp(r'^(\d{3,4})\s+([\u0621-\u064A]{2,3})$').firstMatch(s);
    if (merged != null) {
      final digits = merged.group(1)!;
      final letters = merged.group(2)!;
      final spaced = letters.runes
          .map((r) => String.fromCharCode(r))
          .join(' ');
      s = '$digits $spaced';
      if (isWellFormed(s)) return s;
    }
    return null;
  }
}
