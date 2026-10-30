import 'package:cloud_firestore/cloud_firestore.dart';

/// Small helpers for message times and "Today / Yesterday / date" labels.
/// No external packages needed.
class TimeFormat {
  static const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// Firestore Timestamp -> local DateTime. Returns null while the server
  /// timestamp is still pending (a just-sent message), so callers can show "now".
  static DateTime? fromTs(dynamic ts) => ts is Timestamp ? ts.toDate().toLocal() : null;

  /// "2:45 PM"
  static String clock(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  static bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// "Today", "Yesterday", a weekday name for the last week, otherwise "12 Mar 2026".
  static String dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return _weekdays[d.weekday - 1];
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  /// "Today, 2:45 PM" - used for status views.
  static String dayAndClock(DateTime d) => '${dayLabel(d)}, ${clock(d)}';
}
