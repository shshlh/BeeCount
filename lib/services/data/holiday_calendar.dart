/// 中国 A 股/基金交易日历（7.17.4）。
///
/// 股票市场在周末与法定节假日休市，不随「调休上班日」开市，因此
/// [isTradingDay] 只排除周末 + 官方节假日。
class HolidayCalendar {
  HolidayCalendar._();

  static const Map<int, List<(String, String)>> _holidayRanges = {
    2026: [
      ('2026-01-01', '2026-01-03'), // 元旦
      ('2026-02-15', '2026-02-23'), // 春节
      ('2026-04-04', '2026-04-06'), // 清明
      ('2026-05-01', '2026-05-05'), // 劳动节
      ('2026-06-19', '2026-06-21'), // 端午
      ('2026-09-25', '2026-09-27'), // 中秋
      ('2026-10-01', '2026-10-07'), // 国庆
    ],
    // 2027 官方通知发布前按现行「13 天法定节假日」规则推算，发布后更新。
    2027: [
      ('2027-01-01', '2027-01-03'), // 元旦
      ('2027-02-05', '2027-02-13'), // 春节（除夕逢周五，9 天）
      ('2027-04-03', '2027-04-05'), // 清明
      ('2027-05-01', '2027-05-05'), // 劳动节
      ('2027-06-09', '2027-06-11'), // 端午
      ('2027-09-15', '2027-09-17'), // 中秋
      ('2027-10-01', '2027-10-07'), // 国庆
    ],
  };

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// 是否为法定节假日（不含周末）。
  static bool isHoliday(DateTime date) {
    final day = _dateOnly(date);
    for (final range in _holidayRanges[day.year] ?? const <(String, String)>[]) {
      final start = DateTime.parse(range.$1);
      final end = DateTime.parse(range.$2);
      if (!day.isBefore(start) && !day.isAfter(end)) return true;
    }
    return false;
  }

  /// 是否为交易日：周一至周五且非法定节假日。
  static bool isTradingDay(DateTime date) {
    final day = _dateOnly(date);
    if (day.weekday == DateTime.saturday ||
        day.weekday == DateTime.sunday) {
      return false;
    }
    return !isHoliday(day);
  }

  /// 最近一个交易日（不含 [date] 当天），QDII 目标净值日判定用（7.19.4）。
  static DateTime previousTradingDay(DateTime date) {
    var day = _dateOnly(date).subtract(const Duration(days: 1));
    while (!isTradingDay(day)) {
      day = day.subtract(const Duration(days: 1));
    }
    return day;
  }
}
