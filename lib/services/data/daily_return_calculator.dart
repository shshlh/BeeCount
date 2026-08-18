import 'nav_fetch_service.dart';

/// 今日/昨日收益与涨跌幅快照（7.17.3）。
class DailyReturnSnapshot {
  final double todayProfit;
  final double yesterdayProfit;
  final double todayChangePct;
  final double yesterdayChangePct;
  final bool isNotApplicable;

  const DailyReturnSnapshot({
    required this.todayProfit,
    required this.yesterdayProfit,
    required this.todayChangePct,
    required this.yesterdayChangePct,
    this.isNotApplicable = false,
  });

  /// 货币基金等不适用场景。
  static const notApplicable = DailyReturnSnapshot(
    todayProfit: 0,
    yesterdayProfit: 0,
    todayChangePct: 0,
    yesterdayChangePct: 0,
    isNotApplicable: true,
  );
}

/// 根据最近 3 档净值计算今日/昨日收益与涨跌幅（纯函数，7.17.3）。
///
/// 今日收益 = `(最新 - 次新) × 份额`；昨日收益 = `(次新 - 第三新) × 份额`；
/// 涨跌幅 = 差值 / 被减净值。历史不足 3 档或份额非法时返回 null。
DailyReturnSnapshot? calculateDailyReturn({
  required List<FundNavQuote> history,
  required double shares,
}) {
  final sorted = [...history]
    ..sort((a, b) => a.navDate.compareTo(b.navDate));
  final navs = sorted
      .map((q) => q.nav)
      .where((nav) => nav > 0)
      .toList();
  if (navs.length < 3 || shares <= 0) return null;

  final third = navs[navs.length - 3];
  final second = navs[navs.length - 2];
  final latest = navs[navs.length - 1];
  return DailyReturnSnapshot(
    todayProfit: (latest - second) * shares,
    yesterdayProfit: (second - third) * shares,
    todayChangePct: second > 0 ? (latest - second) / second : 0,
    yesterdayChangePct: third > 0 ? (second - third) / third : 0,
  );
}

/// 货币基金等按「不适用」展示：名称含「货币」或持仓类型为 money。
bool isMoneyFund({required String fundName, String? holdingType}) {
  return holdingType == 'money' || fundName.contains('货币');
}
