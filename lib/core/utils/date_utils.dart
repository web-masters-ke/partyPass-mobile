import 'package:intl/intl.dart';

class AppDateUtils {
  AppDateUtils._();

  static String formatDate(DateTime date) =>
      DateFormat('EEE, MMM d yyyy').format(date);

  static String formatTime(DateTime date) =>
      DateFormat('h:mm a').format(date);

  static String formatDateTime(DateTime date) =>
      DateFormat('EEE, MMM d • h:mm a').format(date);

  static String formatShortDate(DateTime date) =>
      DateFormat('MMM d').format(date);

  static String formatDayNumber(DateTime date) =>
      DateFormat('d').format(date);

  static String formatMonth(DateTime date) =>
      DateFormat('MMM').format(date).toUpperCase();

  static String formatDayOfWeek(DateTime date) =>
      DateFormat('EEE').format(date).toUpperCase();

  static String timeUntil(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now);
    if (diff.isNegative) return 'Ended';
    if (diff.inDays > 30) {
      final months = (diff.inDays / 30).floor();
      return 'In $months month${months > 1 ? 's' : ''}';
    }
    if (diff.inDays > 0) return 'In ${diff.inDays} day${diff.inDays > 1 ? 's' : ''}';
    if (diff.inHours > 0) return 'In ${diff.inHours}h';
    return 'Starting soon';
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
