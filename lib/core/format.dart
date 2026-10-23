import 'package:intl/intl.dart';

/// NFR-L10N-02 — every user-visible date/time goes through here, `id_ID`.
class DateFormats {
  const DateFormats._();

  static String Function(DateTime) _pattern(String pattern) =>
      DateFormat(pattern, 'id_ID').format;

  /// `Sen, 12 Des 2027`
  static String weekdayDate(DateTime local) =>
      _pattern('EEE, d MMM yyyy')(local.toLocal());

  /// `12 Des 2027`
  static String date(DateTime local) => _pattern('d MMM yyyy')(local.toLocal());

  /// `20.00`
  static String timeHm(DateTime local) => _pattern('HH.mm')(local.toLocal());

  /// `Sen, 12 Des 2027 • 20.00`
  static String dateTime(DateTime local) {
    final value = local.toLocal();
    return '${weekdayDate(value)} • ${timeHm(value)}';
  }

  /// Today shows the time only; other days show the date (§5.4).
  static String dueLabel(DateTime dueUtc, DateTime nowUtc, String zoneId) {
    final due = dueUtc.toLocal();
    final now = nowUtc.toLocal();
    final sameDay =
        due.year == now.year && due.month == now.month && due.day == now.day;
    return sameDay ? timeHm(due) : weekdayDate(due);
  }

  /// `23 Okt 2026 • 09.12`
  static String timestamp(DateTime local) {
    final value = local.toLocal();
    return '${date(value)} • ${timeHm(value)}';
  }

  /// Local wall-clock fields of a UTC instant, for pre-filling pickers.
  static String isoDate(DateTime local) =>
      _pattern('yyyy-MM-dd')(local.toLocal());
}
