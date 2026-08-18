import 'package:decimal/decimal.dart';

import 'nav_fetch_service.dart';

Decimal _divide(Decimal a, Decimal b) =>
    (a / b).toDecimal(scaleOnInfinitePrecision: 18);

/// 今日/昨日收益与涨跌幅快照（7.17.3）。
class DailyReturnSnapshot {
  final Decimal todayProfit;
  final Decimal yesterdayProfit;
  final Decimal todayChangePct;
  final Decimal yesterdayChangePct;
  final bool isNotApplicable;

  const DailyReturnSnapshot({
    required this.todayProfit,
    required this.yesterdayProfit,
    required this.todayChangePct,
    required this.yesterdayChangePct,
    this.isNotApplicable = false,
  });

  /// 货币基金等不适用场景。
  static final notApplicable = DailyReturnSnapshot(
    todayProfit: Decimal.zero,
    yesterdayProfit: Decimal.zero,
    todayChangePct: Decimal.zero,
    yesterdayChangePct: Decimal.zero,
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

  final sharesDecimal = Decimal.parse(shares.toString());
  final third = Decimal.parse(navs[navs.length - 3].toString());
  final second = Decimal.parse(navs[navs.length - 2].toString());
  final latest = Decimal.parse(navs[navs.length - 1].toString());
  return DailyReturnSnapshot(
    todayProfit: (latest - second) * sharesDecimal,
    yesterdayProfit: (second - third) * sharesDecimal,
    todayChangePct: second > Decimal.zero
        ? _divide(latest - second, second)
        : Decimal.zero,
    yesterdayChangePct: third > Decimal.zero
        ? _divide(second - third, third)
        : Decimal.zero,
  );
}

/// 货币基金等按「不适用」展示：名称含「货币」或持仓类型为 money。
bool isMoneyFund({required String fundName, String? holdingType}) {
  return holdingType == 'money' || fundName.contains('货币');
}
