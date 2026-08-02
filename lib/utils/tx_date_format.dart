import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

/// 记账表单日期显示（v5.3）：`2026年8月2日 今天` / `2026年8月1日 周六`；
/// 开启时间显示时追加 `HH:mm`。周几由日期自动算出。
String formatEntryDateTime(
  BuildContext context,
  DateTime date, {
  required bool showTime,
}) {
  final dayPart = txDayLabel(context, date);
  final base = '${date.year}年${date.month}月${date.day}日 $dayPart';
  if (!showTime) return base;
  final hh = date.hour.toString().padLeft(2, '0');
  final mm = date.minute.toString().padLeft(2, '0');
  return '$base $hh:$mm';
}

/// 短日期标签：今天显示「今天」，其它显示周几（周六/周日…）
String txDayLabel(BuildContext context, DateTime date) {
  final l10n = AppLocalizations.of(context);
  final now = DateTime.now();
  final isToday =
      date.year == now.year && date.month == now.month && date.day == now.day;
  return isToday ? l10n.txDateToday : _weekdayLabel(l10n, date.weekday);
}

String _weekdayLabel(AppLocalizations l10n, int weekday) {
  switch (weekday) {
    case 1:
      return l10n.txDateMonday;
    case 2:
      return l10n.txDateTuesday;
    case 3:
      return l10n.txDateWednesday;
    case 4:
      return l10n.txDateThursday;
    case 5:
      return l10n.txDateFriday;
    case 6:
      return l10n.txDateSaturday;
    default:
      return l10n.txDateSunday;
  }
}
