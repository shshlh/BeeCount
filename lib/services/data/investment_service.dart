/// 投资 Service，包装 InvestmentRepository 的高阶操作。
///
/// 职责：组合摘要、批量净值刷新、盈亏计算、前端验证。
/// 买入/卖出/转换/净值更新直接委托给 Repository。
library;

import '../../data/db.dart';
import '../../data/repositories/investment_repository.dart';
import 'package:decimal/decimal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'daily_return_calculator.dart';
import 'holiday_calendar.dart';
import 'nav_fetch_service.dart';

Decimal _toDecimal(double value) => Decimal.parse(value.toString());

Decimal _divide(Decimal a, Decimal b) =>
    (a / b).toDecimal(scaleOnInfinitePrecision: 18);

/// 账本投资组合摘要。
class PortfolioSummary {
  final double totalMarketValue;
  final double totalCost;
  final double unrealizedPnL;
  final double returnRate;
  final int holdingCount;
  final Decimal? todayProfit;
  final Decimal? yesterdayProfit;
  final Decimal? todayChangePct;
  final Decimal? yesterdayChangePct;
  final DailyNavStatus dailyStatus;

  const PortfolioSummary({
    required this.totalMarketValue,
    required this.totalCost,
    required this.unrealizedPnL,
    required this.returnRate,
    required this.holdingCount,
    this.todayProfit,
    this.yesterdayProfit,
    this.todayChangePct,
    this.yesterdayChangePct,
    this.dailyStatus = DailyNavStatus.pending,
  });

  @override
  String toString() =>
      'PortfolioSummary(mv=$totalMarketValue, cost=$totalCost, pnl=$unrealizedPnL, rate=$returnRate, count=$holdingCount)';
}

/// 今日/昨日净值更新状态（7.17.5）。
enum DailyNavStatus { pending, partialUpdated, allUpdated, nonTradingDay }

/// 单持仓未实现收益。
class HoldingReturn {
  final double unrealizedPnL;
  final double returnRate;

  const HoldingReturn({required this.unrealizedPnL, required this.returnRate});
}

/// 一次净值刷新结果（6.13.3）。
class NavRefreshResult {
  final int updatedCount;
  final int advancedCount;
  final int totalAdvancedCount;
  final List<String> skippedCodes;
  final bool throttled;

  const NavRefreshResult({
    required this.updatedCount,
    this.advancedCount = 0,
    this.totalAdvancedCount = 0,
    required this.skippedCodes,
    this.throttled = false,
  });
}

class InvestmentService {
  final InvestmentRepository _repo;
  NavFetchService? _navFetch;
  final DateTime Function() _clock;

  InvestmentService(
    this._repo, {
    NavFetchService? navFetch,
    DateTime Function()? clock,
  })  : _navFetch = navFetch,
        _clock = clock ?? DateTime.now;

  NavFetchService get _navFetchService => _navFetch ??= NavFetchService();

  static const Duration _navRefreshThrottle = Duration(minutes: 15);

  /// 拉取天天基金最新净值并批量更新账本持仓。
  ///
  /// 返回成功更新的持仓数；15 分钟内不重复请求（[force]=true 忽略节流，
  /// 供下拉刷新使用）。整批失败抛 [StateError]，单只失败跳过不影响其余。
  Future<int> refreshNavsForLedger(int ledgerId, {bool force = false}) async {
    final result = await refreshNavsForLedgerDetailed(ledgerId, force: force);
    if (result.updatedCount == 0 && result.skippedCodes.isNotEmpty) {
      throw StateError('净值刷新失败');
    }
    return result.updatedCount;
  }

  /// 拉取天天基金最新净值并返回详细刷新结果（6.13.3）。
  ///
  /// [skippedCodes] 为当前账本持仓代码中未抓取成功的集合（无效代码/无日期/
  /// 单只失败）；整批失败时返回 `updatedCount=0` 与全部 skipped，不抛异常。
  Future<NavRefreshResult> refreshNavsForLedgerDetailed(
    int ledgerId, {
    bool force = false,
  }) async {
    if (!force) {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt('investment_nav_refresh_at_$ledgerId');
      if (last != null) {
        final elapsed = _clock()
            .difference(DateTime.fromMillisecondsSinceEpoch(last));
        if (elapsed < _navRefreshThrottle) {
          return const NavRefreshResult(
            updatedCount: 0,
            skippedCodes: [],
            throttled: true,
          );
        }
      }
    }

    final holdings = await _repo.watchHoldings(ledgerId: ledgerId).first;
    if (holdings.isEmpty) {
      return const NavRefreshResult(updatedCount: 0, skippedCodes: []);
    }

    // 一次性清理所有基金的旧历史，避免 7.18.1 前积压超过 3 档的数据长期残留。
    await _repo.pruneAllNavHistories();

    final codes = holdings.map((h) => h.fundCode).toSet().toList();
    final histories = await _navFetchService.fetchNavHistories(codes);
    final successCodes = histories.keys.toSet();
    final moneyFundCodes = holdings
        .where((h) =>
            isMoneyFund(fundName: h.fundName, holdingType: h.holdingType))
        .map((h) => h.fundCode)
        .toSet();
    final skippedCodes = codes
        .toSet()
        .difference(successCodes)
        .difference(moneyFundCodes)
        .toList()
      ..sort();

    final navMap = <int, FundNavQuote>{};
    final advancedIds = <int>{};
    final allAdvancedIds = <int>{};
    for (final h in holdings) {
      final quotes = histories[h.fundCode];
      if (quotes == null || quotes.isEmpty) continue;
      final quote = quotes.last;
      navMap[h.id] = quote;
      final previous = h.navDate;
      final isMoney =
          isMoneyFund(fundName: h.fundName, holdingType: h.holdingType);
      if (previous == null || quote.navDate.isAfter(previous)) {
        allAdvancedIds.add(h.id);
        if (!isMoney) advancedIds.add(h.id);
      }
    }
    if (navMap.isEmpty) {
      return NavRefreshResult(
        updatedCount: 0,
        advancedCount: 0,
        totalAdvancedCount: 0,
        skippedCodes: skippedCodes,
      );
    }

    for (final entry in histories.entries) {
      for (final quote in entry.value) {
        await _repo.upsertNavHistory(entry.key, quote.navDate, quote.nav);
      }
    }

    await batchUpdateNav(navMap);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'investment_nav_refresh_at_$ledgerId',
      _clock().millisecondsSinceEpoch,
    );
    return NavRefreshResult(
      updatedCount: navMap.length,
      advancedCount: advancedIds.length,
      totalAdvancedCount: allAdvancedIds.length,
      skippedCodes: skippedCodes,
    );
  }

  /// 7.17.5 每日净值刷新：0:01~20:00 不拉取（待更新），20:00 后进入页面
  /// 即拉取，部分/全部更新状态按 [NavRefreshResult.advancedCount] 汇总。
  Future<NavRefreshResult> refreshDailyNavsForLedger(
    int ledgerId, {
    bool force = false,
  }) async {
    final now = _clock();
    if (!HolidayCalendar.isTradingDay(now)) {
      await _saveDailyStatus(ledgerId, DailyNavStatus.nonTradingDay);
      return const NavRefreshResult(updatedCount: 0, skippedCodes: []);
    }
    if (now.hour < 20) {
      await _saveDailyStatus(ledgerId, DailyNavStatus.pending);
      return const NavRefreshResult(updatedCount: 0, skippedCodes: []);
    }

    final result = await refreshNavsForLedgerDetailed(ledgerId, force: force);
    if (result.throttled) return result;

    final holdings = await _repo.watchHoldings(ledgerId: ledgerId).first;
    final eligibleHoldings = holdings
        .where((h) =>
            !isMoneyFund(fundName: h.fundName, holdingType: h.holdingType))
        .toList();
    final status = eligibleHoldings.isEmpty ||
            result.advancedCount >= eligibleHoldings.length
        ? DailyNavStatus.allUpdated
        : (result.totalAdvancedCount > 0
            ? DailyNavStatus.partialUpdated
            : DailyNavStatus.pending);
    await _saveDailyStatus(ledgerId, status);
    return result;
  }

  /// 当前账本今日净值状态（读取上次刷新结果，未刷新时按时间兜底）。
  Future<DailyNavStatus> getDailyNavStatus(int ledgerId) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_dailyStatusKey(ledgerId));
    if (stored != null) {
      return DailyNavStatus.values.firstWhere(
        (s) => s.name == stored,
        orElse: () => DailyNavStatus.pending,
      );
    }
    final now = _clock();
    if (!HolidayCalendar.isTradingDay(now)) {
      return DailyNavStatus.nonTradingDay;
    }
    return DailyNavStatus.pending;
  }

  Future<void> _saveDailyStatus(int ledgerId, DailyNavStatus status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _dailyStatusKey(ledgerId),
      status.name,
    );
  }

  /// 状态按自然日隔离，跨日自动回退 pending/非交易日，避免残留昨日状态。
  String _dailyStatusKey(int ledgerId) {
    final now = _clock();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return 'investment_nav_daily_status_${ledgerId}_${now.year}$month$day';
  }

  // ---- 组合摘要 ----

  Future<PortfolioSummary> getPortfolioSummary(int ledgerId) async {
    final holdings = await _repo.watchHoldings(ledgerId: ledgerId).first;
    if (holdings.isEmpty) {
      return const PortfolioSummary(
        totalMarketValue: 0,
        totalCost: 0,
        unrealizedPnL: 0,
        returnRate: 0,
        holdingCount: 0,
      );
    }

    Decimal totalMv = Decimal.zero;
    Decimal totalCost = Decimal.zero;
    Decimal? todayProfit;
    Decimal? yesterdayProfit;
    Decimal todayBase = Decimal.zero;
    Decimal yesterdayBase = Decimal.zero;
    for (final h in holdings) {
      totalMv += _toDecimal(h.marketValue);
      totalCost += _toDecimal(h.totalCost);
      if (isMoneyFund(fundName: h.fundName, holdingType: h.holdingType)) {
        continue;
      }
      final history = await _repo.getNavHistory(h.fundCode, limit: 3);
      if (history.length < 3) continue;
      final quotes = [
        for (final row in history)
          FundNavQuote(nav: row.unitNav, navDate: row.navDate),
      ];
      final snapshot =
          calculateDailyReturn(history: quotes, shares: h.totalShares);
      if (snapshot == null) continue;
      todayProfit = (todayProfit ?? Decimal.zero) + snapshot.todayProfit;
      yesterdayProfit =
          (yesterdayProfit ?? Decimal.zero) + snapshot.yesterdayProfit;
      final navsByDate = [...quotes]
        ..sort((a, b) => a.navDate.compareTo(b.navDate));
      final navs = navsByDate
          .map((q) => q.nav)
          .where((nav) => nav > 0)
          .toList();
      if (navs.length >= 3) {
        todayBase +=
            _toDecimal(navs[navs.length - 2]) * _toDecimal(h.totalShares);
        yesterdayBase +=
            _toDecimal(navs[navs.length - 3]) * _toDecimal(h.totalShares);
      }
    }

    final pnl = totalMv - totalCost;
    final rate =
        totalCost > Decimal.zero ? _divide(pnl, totalCost) : Decimal.zero;
    final dailyStatus = await getDailyNavStatus(ledgerId);

    return PortfolioSummary(
      totalMarketValue: totalMv.toDouble(),
      totalCost: totalCost.toDouble(),
      unrealizedPnL: pnl.toDouble(),
      returnRate: rate.toDouble(),
      holdingCount: holdings.length,
      todayProfit: todayProfit,
      yesterdayProfit: yesterdayProfit,
      todayChangePct: todayBase > Decimal.zero
          ? _divide(todayProfit ?? Decimal.zero, todayBase)
          : null,
      yesterdayChangePct: yesterdayBase > Decimal.zero
          ? _divide(yesterdayProfit ?? Decimal.zero, yesterdayBase)
          : null,
      dailyStatus: dailyStatus,
    );
  }

  // ---- 批量净值刷新 ----

  Future<void> batchUpdateNav(Map<int, FundNavQuote> navMap) async {
    for (final entry in navMap.entries) {
      await _repo.updateNav(
        entry.key,
        entry.value.nav,
        navDate: entry.value.navDate,
      );
    }
  }

  // ---- 单持仓收益 ----

  Future<HoldingReturn> getHoldingReturn(int holdingId) async {
    final holding = await _repo.getHolding(holdingId);
    if (holding == null) {
      return const HoldingReturn(unrealizedPnL: 0, returnRate: 0);
    }
    final marketValue = _toDecimal(holding.marketValue);
    final cost = _toDecimal(holding.totalCost);
    final pnl = marketValue - cost;
    final rate = cost > Decimal.zero ? _divide(pnl, cost) : Decimal.zero;
    return HoldingReturn(
      unrealizedPnL: pnl.toDouble(),
      returnRate: rate.toDouble(),
    );
  }

  /// 单持仓今日/昨日收益与涨跌幅（7.17.3）。
  ///
  /// 历史不足 3 档返回 null；货币基金返回
  /// [DailyReturnSnapshot.notApplicable]（UI 显示「--」）。
  Future<DailyReturnSnapshot?> getHoldingDailyReturn(int holdingId) async {
    final holding = await _repo.getHolding(holdingId);
    if (holding == null) return null;
    if (isMoneyFund(
      fundName: holding.fundName,
      holdingType: holding.holdingType,
    )) {
      return DailyReturnSnapshot.notApplicable;
    }
    final history = await _repo.getNavHistory(holding.fundCode, limit: 3);
    if (history.isEmpty) return null;
    return calculateDailyReturn(
      history: [
        for (final row in history)
          FundNavQuote(nav: row.unitNav, navDate: row.navDate),
      ],
      shares: holding.totalShares,
    );
  }

  // ---- 前端验证 ----

  Future<void> validateSell(
    int holdingId,
    double shares, {
    double? nav,
    double? fee,
  }) async {
    if (shares <= 0) throw ArgumentError('卖出份额必须大于 0');
    if (nav != null && nav <= 0) throw ArgumentError('卖出净值必须大于 0');
    if (fee != null && fee < 0) throw ArgumentError('手续费不能为负数');
    final holding = await _repo.getHolding(holdingId);
    if (holding == null) throw StateError('持仓 $holdingId 不存在');
    if (holding.totalShares < shares) {
      throw StateError('持仓份额不足：持有 ${holding.totalShares}，试图卖出 $shares');
    }
  }

  Future<void> validateConvert(
    int fromHoldingId,
    double shares, {
    int? toHoldingId,
    String? fundCode,
    String? fundName,
    double? fromNav,
    double? toShares,
    double? toNav,
    required double toCost,
    double? fee,
    double refundAmount = 0,
    int? refundAccountId,
  }) async {
    if (shares <= 0) throw ArgumentError('转换份额必须大于 0');
    if (fromNav != null && fromNav <= 0) {
      throw ArgumentError('转出净值必须大于 0');
    }
    if (toShares != null && toShares <= 0) {
      throw ArgumentError('转入份额必须大于 0');
    }
    if (toNav != null && toNav <= 0) {
      throw ArgumentError('转入净值必须大于 0');
    }
    if (toCost <= 0) throw ArgumentError('转入成本必须大于 0');
    if (fee != null && fee < 0) throw ArgumentError('手续费不能为负数');
    if (refundAmount < 0) throw ArgumentError('退回金额不能为负数');
    if (refundAmount > 0 && refundAccountId == null) {
      throw ArgumentError('退回金额大于 0 时必须指定退回账户');
    }
    if (toHoldingId == null &&
        ((fundCode == null || fundCode.trim().isEmpty) ||
            (fundName == null || fundName.trim().isEmpty))) {
      throw ArgumentError('目标基金代码和名称必填');
    }
    final holding = await _repo.getHolding(fromHoldingId);
    if (holding == null) throw StateError('来源持仓 $fromHoldingId 不存在');
    if (holding.totalShares < shares) {
      throw StateError('来源持仓份额不足：持有 ${holding.totalShares}，试图转换 $shares');
    }
  }

  void validateBuy({
    required double shares,
    required double nav,
    required double amount,
  }) {
    if (amount <= 0) throw ArgumentError('投入本金必须大于 0');
    if (shares <= 0) throw ArgumentError('买入份额必须大于 0');
    if (nav <= 0) throw ArgumentError('净值必须大于 0');
  }

  // ---- 直接委托 Repository ----

  Future<int> buy({
    required int ledgerId,
    int? accountId,
    required String fundCode,
    required String fundName,
    required double shares,
    required double nav,
    required double amount,
    DateTime? happenedAt,
    DateTime? navDate,
    String? note,
    int? holdingId,
    int? sourceAccountId,
  }) {
    return _repo.buy(
      ledgerId: ledgerId,
      accountId: accountId,
      fundCode: fundCode,
      fundName: fundName,
      shares: shares,
      nav: nav,
      amount: amount,
      happenedAt: happenedAt,
      navDate: navDate,
      note: note,
      holdingId: holdingId,
      sourceAccountId: sourceAccountId,
    );
  }

  Future<int> sell({
    required int holdingId,
    required double shares,
    required double nav,
    double fee = 0,
    DateTime? happenedAt,
    DateTime? navDate,
    String? note,
    int? targetAccountId,
  }) {
    return _repo.sell(
      holdingId: holdingId,
      shares: shares,
      nav: nav,
      fee: fee,
      happenedAt: happenedAt,
      navDate: navDate,
      note: note,
      targetAccountId: targetAccountId,
    );
  }

  Future<int> convert({
    required int fromHoldingId,
    int? toHoldingId,
    required double fromShares,
    required double fromNav,
    required double toShares,
    required double toNav,
    required double toCost,
    double fee = 0,
    double refundAmount = 0,
    int? refundAccountId,
    String? fundCode,
    String? fundName,
    DateTime? happenedAt,
    DateTime? navDate,
    String? note,
  }) {
    return _repo.convert(
      fromHoldingId: fromHoldingId,
      toHoldingId: toHoldingId,
      fromShares: fromShares,
      fromNav: fromNav,
      toShares: toShares,
      toNav: toNav,
      toCost: toCost,
      fee: fee,
      refundAmount: refundAmount,
      refundAccountId: refundAccountId,
      fundCode: fundCode,
      fundName: fundName,
      happenedAt: happenedAt,
      navDate: navDate,
      note: note,
    );
  }

  /// 更新一整笔转换（A 卖出 + B 买入 + 关联退回），按 batchId 原子更新。
  Future<void> updateConversion(
    String batchId, {
    required double fromShares,
    required double fromNav,
    required double toShares,
    required double toNav,
    required double toCost,
    double fee = 0,
    double refundAmount = 0,
    int? refundAccountId,
    DateTime? happenedAt,
    String? note,
    bool clearNote = false,
  }) {
    return _repo.updateConversion(
      batchId,
      fromShares: fromShares,
      fromNav: fromNav,
      toShares: toShares,
      toNav: toNav,
      toCost: toCost,
      fee: fee,
      refundAmount: refundAmount,
      refundAccountId: refundAccountId,
      happenedAt: happenedAt,
      note: note,
      clearNote: clearNote,
    );
  }

  /// 删除一整笔转换（A 卖出 + B 买入 + 关联退回）。
  Future<void> deleteConversion(String batchId) {
    return _repo.deleteConversion(batchId);
  }

  /// 按 batchId 取转换批次下的全部交易，供编辑预填。
  Future<List<Transaction>> getTransactionsByBatchId(String batchId) {
    return _repo.getTransactionsByBatchId(batchId);
  }

  Future<void> updateNav(int holdingId, double nav, {DateTime? navDate}) {
    return _repo.updateNav(holdingId, nav, navDate: navDate);
  }

  Future<InvestmentHolding?> getHolding(int id) => _repo.getHolding(id);

  Stream<List<InvestmentHolding>> watchHoldings({required int ledgerId}) =>
      _repo.watchHoldings(ledgerId: ledgerId);

  Stream<List<Transaction>> watchTransactions(int holdingId) =>
      _repo.watchTransactions(holdingId);

  /// 更新投资交易的可编辑字段（note / happenedAt / shares / nav / fee / amount）。
  /// [note] 为 null 表示不更新；[clearNote] 为 true 时把备注清空。
  /// 保存后重算持仓统计并联动投资账户市值。
  Future<void> updateTransaction(
    int transactionId, {
    String? note,
    bool clearNote = false,
    DateTime? happenedAt,
    double? investShares,
    double? investNav,
    double? investFee,
    double? amount,
  }) {
    return _repo.updateTransaction(
      transactionId,
      note: note,
      clearNote: clearNote,
      happenedAt: happenedAt,
      investShares: investShares,
      investNav: investNav,
      investFee: investFee,
      amount: amount,
    );
  }

  /// 创建初始持仓（导入已有投资记录）。
  Future<int> createInitialHolding({
    required int ledgerId,
    required int accountId,
    required String fundCode,
    required String fundName,
    required double shares,
    required double cost,
    required double nav,
    DateTime? happenedAt,
    DateTime? navDate,
    String? note,
  }) {
    return _repo.createInitialHolding(
      ledgerId: ledgerId,
      accountId: accountId,
      fundCode: fundCode,
      fundName: fundName,
      shares: shares,
      cost: cost,
      nav: nav,
      happenedAt: happenedAt,
      navDate: navDate,
      note: note,
    );
  }

  /// 更新持仓基金代码/名称（6.13 防错）。
  Future<void> updateHoldingInfo(
    int holdingId, {
    required String fundCode,
    String? fundName,
  }) {
    return _repo.updateHoldingInfo(
      holdingId,
      fundCode: fundCode,
      fundName: fundName,
    );
  }

  /// 删除整个持仓（6.13.4）。
  Future<void> deleteHolding(int holdingId) {
    return _repo.deleteHolding(holdingId);
  }

  // ---- 基金分组（v6.2）----

  Future<int> createGroup({
    required int ledgerId,
    required String name,
    int sortOrder = 0,
  }) {
    return _repo.createGroup(
      ledgerId: ledgerId,
      name: name,
      sortOrder: sortOrder,
    );
  }

  Future<void> renameGroup(int groupId, String name) {
    return _repo.renameGroup(groupId, name);
  }

  Future<void> deleteGroup(int groupId) {
    return _repo.deleteGroup(groupId);
  }

  Future<void> addHoldingsToGroup(int groupId, List<int> holdingIds) {
    return _repo.addHoldingsToGroup(groupId, holdingIds);
  }

  Future<void> removeHoldingFromGroup(int groupId, int holdingId) {
    return _repo.removeHoldingFromGroup(groupId, holdingId);
  }

  Future<void> setGroupMembers(int groupId, List<int> holdingIds) {
    return _repo.setGroupMembers(groupId, holdingIds);
  }

  Stream<List<InvestmentGroup>> watchGroups({required int ledgerId}) {
    return _repo.watchGroups(ledgerId: ledgerId);
  }

  Stream<List<int>> watchGroupHoldingIds(int groupId) {
    return _repo.watchGroupHoldingIds(groupId);
  }
}
