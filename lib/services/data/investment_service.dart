/// 投资 Service，包装 InvestmentRepository 的高阶操作。
///
/// 职责：组合摘要、批量净值刷新、盈亏计算、前端验证。
/// 买入/卖出/转换/净值更新直接委托给 Repository。
library;

import '../../data/db.dart';
import '../../data/repositories/investment_repository.dart';

/// 账本投资组合摘要。
class PortfolioSummary {
  final double totalMarketValue;
  final double totalCost;
  final double unrealizedPnL;
  final double returnRate;
  final int holdingCount;

  const PortfolioSummary({
    required this.totalMarketValue,
    required this.totalCost,
    required this.unrealizedPnL,
    required this.returnRate,
    required this.holdingCount,
  });

  @override
  String toString() =>
      'PortfolioSummary(mv=$totalMarketValue, cost=$totalCost, pnl=$unrealizedPnL, rate=$returnRate, count=$holdingCount)';
}

/// 单持仓未实现收益。
class HoldingReturn {
  final double unrealizedPnL;
  final double returnRate;

  const HoldingReturn({required this.unrealizedPnL, required this.returnRate});
}

class InvestmentService {
  final InvestmentRepository _repo;

  InvestmentService(this._repo);

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

    double totalMv = 0;
    double totalCost = 0;
    for (final h in holdings) {
      totalMv += h.marketValue;
      totalCost += h.totalCost;
    }

    final pnl = totalMv - totalCost;
    final rate = totalCost > 0 ? pnl / totalCost : 0.0;

    return PortfolioSummary(
      totalMarketValue: totalMv,
      totalCost: totalCost,
      unrealizedPnL: pnl,
      returnRate: rate,
      holdingCount: holdings.length,
    );
  }

  // ---- 批量净值刷新 ----

  Future<void> batchUpdateNav(Map<int, double> navMap) async {
    for (final entry in navMap.entries) {
      await _repo.updateNav(entry.key, entry.value);
    }
  }

  // ---- 单持仓收益 ----

  Future<HoldingReturn> getHoldingReturn(int holdingId) async {
    final holding = await _repo.getHolding(holdingId);
    if (holding == null) {
      return const HoldingReturn(unrealizedPnL: 0, returnRate: 0);
    }
    final pnl = holding.marketValue - holding.totalCost;
    final rate = holding.totalCost > 0 ? pnl / holding.totalCost : 0.0;
    return HoldingReturn(unrealizedPnL: pnl, returnRate: rate);
  }

  // ---- 前端验证 ----

  Future<void> validateSell(int holdingId, double shares) async {
    if (shares <= 0) throw ArgumentError('卖出份额必须大于 0');
    final holding = await _repo.getHolding(holdingId);
    if (holding == null) throw StateError('持仓 $holdingId 不存在');
    if (holding.totalShares < shares) {
      throw StateError('持仓份额不足：持有 ${holding.totalShares}，试图卖出 $shares');
    }
  }

  Future<void> validateConvert(int fromHoldingId, double shares) async {
    if (shares <= 0) throw ArgumentError('转换份额必须大于 0');
    final holding = await _repo.getHolding(fromHoldingId);
    if (holding == null) throw StateError('来源持仓 $fromHoldingId 不存在');
    if (holding.totalShares < shares) {
      throw StateError('来源持仓份额不足：持有 ${holding.totalShares}，试图转换 $shares');
    }
  }

  void validateBuy({required double shares, required double nav}) {
    if (shares <= 0) throw ArgumentError('买入份额必须大于 0');
    if (nav <= 0) throw ArgumentError('净值必须大于 0');
  }

  // ---- 直接委托 Repository ----

  Future<int> buy({
    required int ledgerId,
    required int accountId,
    required String fundCode,
    required String fundName,
    required double shares,
    required double nav,
    double fee = 0,
    DateTime? happenedAt,
    String? note,
    int? holdingId,
  }) {
    return _repo.buy(
      ledgerId: ledgerId,
      accountId: accountId,
      fundCode: fundCode,
      fundName: fundName,
      shares: shares,
      nav: nav,
      fee: fee,
      happenedAt: happenedAt,
      note: note,
      holdingId: holdingId,
    );
  }

  Future<int> sell({
    required int holdingId,
    required double shares,
    required double nav,
    double fee = 0,
    DateTime? happenedAt,
    String? note,
  }) {
    return _repo.sell(
      holdingId: holdingId,
      shares: shares,
      nav: nav,
      fee: fee,
      happenedAt: happenedAt,
      note: note,
    );
  }

  Future<int> convert({
    required int fromHoldingId,
    required int toHoldingId,
    required double fromShares,
    required double fromNav,
    required double toShares,
    required double toNav,
    double fee = 0,
    DateTime? happenedAt,
    String? note,
  }) {
    return _repo.convert(
      fromHoldingId: fromHoldingId,
      toHoldingId: toHoldingId,
      fromShares: fromShares,
      fromNav: fromNav,
      toShares: toShares,
      toNav: toNav,
      fee: fee,
      happenedAt: happenedAt,
      note: note,
    );
  }

  Future<void> updateNav(int holdingId, double nav) {
    return _repo.updateNav(holdingId, nav);
  }

  Future<InvestmentHolding?> getHolding(int id) => _repo.getHolding(id);

  Stream<List<InvestmentHolding>> watchHoldings({required int ledgerId}) =>
      _repo.watchHoldings(ledgerId: ledgerId);

 Stream<List<Transaction>> watchTransactions(int holdingId) =>
     _repo.watchTransactions(holdingId);

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
      note: note,
    );
  }
}
