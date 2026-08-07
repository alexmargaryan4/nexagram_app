import 'package:intl/intl.dart';

/// Telegram-style relative timestamp formatting for chat lists and
/// message bubbles.
class DateFormatter {
  DateFormatter._();

  /// "14:32" style clock time, used inside message bubbles.
  static String messageTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return DateFormat.Hm().format(dateTime);
  }

  /// Chat-list timestamp: time for today, weekday for this week, date
  /// otherwise — mirrors how Telegram/iMessage summarize recency.
  static String chatListTimestamp(DateTime? dateTime) {
    if (dateTime == null) return '';
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime target =
        DateTime(dateTime.year, dateTime.month, dateTime.day);
    final int dayDiff = today.difference(target).inDays;

    if (dayDiff == 0) return DateFormat.Hm().format(dateTime);
    if (dayDiff == 1) return 'Yesterday';
    if (dayDiff < 7) return DateFormat.E().format(dateTime);
    if (dateTime.year == now.year) return DateFormat.MMMd().format(dateTime);
    return DateFormat.yMd().format(dateTime);
  }

  /// Section-header date shown above a run of messages, e.g. "Today",
  /// "Yesterday", or "12 March 2026".
  static String messageDateHeader(DateTime? dateTime) {
    if (dateTime == null) return '';
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime target =
        DateTime(dateTime.year, dateTime.month, dateTime.day);
    final int dayDiff = today.difference(target).inDays;

    if (dayDiff == 0) return 'Today';
    if (dayDiff == 1) return 'Yesterday';
    if (dayDiff < 7) return DateFormat.EEEE().format(dateTime);
    return DateFormat.yMMMMd().format(dateTime);
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// "last seen 5 minutes ago" / "online" style presence string.
  static String lastSeen(DateTime? lastSeen, {required bool isOnline}) {
    if (isOnline) return 'online';
    if (lastSeen == null) return 'last seen recently';

    final Duration diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 1) return 'last seen just now';
    if (diff.inMinutes < 60) return 'last seen ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'last seen ${diff.inHours}h ago';
    if (diff.inDays == 1) return 'last seen yesterday';
    if (diff.inDays < 7) return 'last seen ${diff.inDays}d ago';
    return 'last seen ${DateFormat.yMMMd().format(lastSeen)}';
  }

  static String fileSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String voiceDuration(int? milliseconds) {
    if (milliseconds == null) return '0:00';
    final Duration d = Duration(milliseconds: milliseconds);
    final String minutes = d.inMinutes.toString();
    final String seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
