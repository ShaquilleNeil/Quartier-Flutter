import 'package:intl/intl.dart';

import '../models/events.dart';

/// `NumberFormatter` with `.currency` / `CAD` / 0 fraction digits.
String cad(double price, {int decimals = 0}) => NumberFormat.currency(
        locale: 'en_CA', symbol: '\$', decimalDigits: decimals)
    .format(price);

/// `"$1,850.00"` as used on the listing cards and detail page.
String dollars2(double price) =>
    '\$${NumberFormat('#,##0.00', 'en_US').format(price)}';

/// Same output as the iOS `formatEventTime` helpers.
String formatEventTime(ScheduleEvent e) => e.allDay
    ? '${DateFormat.yMMMd().format(e.startAt)} • All day'
    : DateFormat.yMMMd().add_jm().format(e.startAt);

/// `ConversationRow.relativeTime`.
String relativeTime(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  if (day == today) return DateFormat.jm().format(d);
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return DateFormat.yMd().format(d);
}

String monthYear(DateTime d) => DateFormat('MMMM yyyy').format(d);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
