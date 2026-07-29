import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db.dart';
import '../data/repositories/investment_repository.dart';
import '../data/repositories/local/local_investment_repository.dart';
import '../services/data/investment_service.dart';
import 'database_providers.dart';

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
    StreamProvider.family.autoDispose<List<Transaction>, int>(
        (ref, holdingId) {
  final repo = ref.watch(investmentRepositoryProvider);
  return repo.watchTransactions(holdingId);
});

/// 持仓详情（Future，单次查询，监听 currentHoldings 变化自动刷新）。
final holdingProvider =
    FutureProvider.family.autoDispose<InvestmentHolding?, int>(
        (ref, holdingId) async {
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
final holdingReturnProvider =
    FutureProvider.family.autoDispose<HoldingReturn, int>(
        (ref, holdingId) async {
  ref.watch(currentHoldingsProvider);
  final service = ref.watch(investmentServiceProvider);
  return service.getHoldingReturn(holdingId);
});
