import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decimal/decimal.dart';

import '../data/db.dart';
import '../data/repositories/investment_repository.dart';
import '../data/repositories/local/local_investment_repository.dart';
import '../services/data/daily_return_calculator.dart';
import '../services/data/investment_service.dart';
import 'database_providers.dart';

Decimal _toDecimal(double value) => Decimal.parse(value.toString());

Decimal _divide(Decimal a, Decimal b) =>
    (a / b).toDecimal(scaleOnInfinitePrecision: 18);

Decimal _holdingReturnRate(InvestmentHolding holding) {
  final cost = _toDecimal(holding.totalCost);
  if (cost <= Decimal.zero) return Decimal.zero;
  return _divide(_toDecimal(holding.marketValue) - cost, cost);
}

List<InvestmentHolding> _sortHoldings(
    List<InvestmentHolding> holdings, HoldingsSort sort) {
  final sorted = [...holdings];
  sorted.sort((a, b) {
    final cmp = switch (sort) {
      HoldingsSort.marketValue =>
        _toDecimal(b.marketValue).compareTo(_toDecimal(a.marketValue)),
      HoldingsSort.pnl => (_toDecimal(b.marketValue) - _toDecimal(b.totalCost))
          .compareTo(_toDecimal(a.marketValue) - _toDecimal(a.totalCost)),
      HoldingsSort.returnRate =>
        _holdingReturnRate(b).compareTo(_holdingReturnRate(a)),
    };
    if (cmp != 0) return cmp;
    final mvCmp =
        _toDecimal(b.marketValue).compareTo(_toDecimal(a.marketValue));
    if (mvCmp != 0) return mvCmp;
    return a.id.compareTo(b.id);
  });
  return sorted;
}

/// 持仓排序维度。
enum HoldingsSort { marketValue, pnl, returnRate }

/// 持仓排序状态，默认按持有金额（市值）降序。
final holdingsSortProvider =
    StateProvider<HoldingsSort>((ref) => HoldingsSort.marketValue);

/// 当前选中的分组（null = 全部）；切换账本时自动重置，避免旧账本
/// 分组 id 过滤新账本持仓导致列表为空。
class SelectedGroupNotifier extends Notifier<int?> {
  @override
  int? build() {
    ref.listen<int>(currentLedgerIdProvider, (prev, next) {
      if (prev != next) {
        state = null;
      }
    });
    return null;
  }

  /// 选中指定分组（null = 全部）。
  void select(int? groupId) => state = groupId;

  /// 回到「全部」。
  void reset() => state = null;
}

final selectedGroupProvider =
    NotifierProvider<SelectedGroupNotifier, int?>(SelectedGroupNotifier.new);

// ---- Repository ----

/// 投资 Repository Provider。
/// 阶段 1-4 不进 BaseRepository / 不同步，直接用 LocalInvestmentRepository。
final investmentRepositoryProvider = Provider<InvestmentRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return LocalInvestmentRepository(db);
});

// ---- Service ----

/// 投资 Service Provider。
final investmentServiceProvider = Provider<InvestmentService>((ref) {
  final repo = ref.watch(investmentRepositoryProvider);
  return InvestmentService(repo);
});

// ---- 数据查询 Provider ----

/// 当前账本持仓列表（Stream，份额 > 0）。
/// 按市值降序排列。
final currentHoldingsProvider =
    StreamProvider.autoDispose<List<InvestmentHolding>>((ref) {
  final ledgerId = ref.watch(currentLedgerIdProvider);
  final repo = ref.watch(investmentRepositoryProvider);
  return repo.watchHoldings(ledgerId: ledgerId);
});

/// 持仓交易流水（Stream，按 happenedAt 降序）。
final holdingTransactionsProvider =
    StreamProvider.family.autoDispose<List<Transaction>, int>((ref, holdingId) {
  final repo = ref.watch(investmentRepositoryProvider);
  return repo.watchTransactions(holdingId);
});

/// 持仓详情（Future，单次查询，监听 currentHoldings 变化自动刷新）。
final holdingProvider = FutureProvider.family
    .autoDispose<InvestmentHolding?, int>((ref, holdingId) async {
  ref.watch(currentHoldingsProvider);
  final repo = ref.watch(investmentRepositoryProvider);
  return repo.getHolding(holdingId);
});

/// 投资组合摘要（Future，监听 currentHoldings 变化自动刷新）。
final portfolioSummaryProvider =
    FutureProvider.autoDispose<PortfolioSummary>((ref) async {
  ref.watch(currentHoldingsProvider);
  final ledgerId = ref.watch(currentLedgerIdProvider);
  final service = ref.watch(investmentServiceProvider);
  return service.getPortfolioSummary(ledgerId);
});

/// 单持仓未实现收益（Future）。
final holdingReturnProvider = FutureProvider.family
    .autoDispose<HoldingReturn, int>((ref, holdingId) async {
  ref.watch(currentHoldingsProvider);
  final service = ref.watch(investmentServiceProvider);
  return service.getHoldingReturn(holdingId);
});

/// 当前账本每只持仓的今日/昨日收益与涨跌幅（7.17.6）。
final holdingDailyReturnsProvider =
    FutureProvider.autoDispose<Map<int, DailyReturnSnapshot>>((ref) async {
  final holdings = await ref.watch(currentHoldingsProvider.future);
  final service = ref.watch(investmentServiceProvider);
  final result = <int, DailyReturnSnapshot>{};
  for (final holding in holdings) {
    final daily = await service.getHoldingDailyReturn(holding.id);
    if (daily != null) result[holding.id] = daily;
  }
  return result;
});

// ---- 基金分组与排序（v6.2）----

/// 当前账本的分组列表（按 sortOrder 升序）。
final groupsProvider = StreamProvider.autoDispose<List<InvestmentGroup>>((ref) {
  final ledgerId = ref.watch(currentLedgerIdProvider);
  final repo = ref.watch(investmentRepositoryProvider);
  return repo.watchGroups(ledgerId: ledgerId);
});

/// 某个分组包含的持仓 ID。
final groupHoldingIdsProvider =
    StreamProvider.family.autoDispose<List<int>, int>((ref, groupId) {
  final repo = ref.watch(investmentRepositoryProvider);
  return repo.watchGroupHoldingIds(groupId);
});

/// 当前账本持仓按所选维度排序。
final sortedHoldingsProvider =
    FutureProvider.autoDispose<List<InvestmentHolding>>((ref) async {
  final holdings = await ref.watch(currentHoldingsProvider.future);
  final sort = ref.watch(holdingsSortProvider);
  return _sortHoldings(holdings, sort);
});

/// 先按选中分组过滤，再按排序输出；未选分组时等于全部排序结果。
final filteredHoldingsProvider =
    FutureProvider.autoDispose<List<InvestmentHolding>>((ref) async {
  final sorted = await ref.watch(sortedHoldingsProvider.future);
  final selectedGroupId = ref.watch(selectedGroupProvider);
  if (selectedGroupId == null) return sorted;
  final memberIds =
      await ref.watch(groupHoldingIdsProvider(selectedGroupId).future);
  final memberSet = memberIds.toSet();
  return sorted.where((h) => memberSet.contains(h.id)).toList();
});
