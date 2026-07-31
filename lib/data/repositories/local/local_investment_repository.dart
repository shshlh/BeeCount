import 'dart:math';

import 'package:drift/drift.dart' as d;
import 'package:uuid/uuid.dart';

import '../../db.dart';
import '../../repositories/investment_repository.dart';

const _uuid = Uuid();

/// 基于 Drift 的本地投资 Repository 实现。
/// 所有写操作（buy/sell/convert）在 db.transaction() 中原子执行。
class LocalInvestmentRepository implements InvestmentRepository {
  final BeeDatabase db;

  LocalInvestmentRepository(this.db);

  @override
  Stream<List<InvestmentHolding>> watchHoldings({required int ledgerId}) {
    return (db.select(db.investmentHoldings)
          ..where((h) => h.ledgerId.equals(ledgerId) & h.totalShares.isBiggerThanValue(0.0))
          ..orderBy(
              [(h) => d.OrderingTerm(expression: h.marketValue, mode: d.OrderingMode.desc)]))
        .watch();
  }

  @override
  Future<InvestmentHolding?> getHolding(int id) {
    return (db.select(db.investmentHoldings)..where((h) => h.id.equals(id)))
        .getSingleOrNull();
  }

  // ---- 读辅助 ----

  Future<InvestmentHolding?> _findHolding(int ledgerId, String fundCode, int accountId) {
    return (db.select(db.investmentHoldings)
          ..where((h) =>
              h.ledgerId.equals(ledgerId) &
              h.fundCode.equals(fundCode) &
              h.accountId.equals(accountId)))
        .getSingleOrNull();
  }

  // ---- 写辅助 ----

  Future<int> _insertTx({
    required int ledgerId,
    required int? accountId,
    required String investType,
    required double amount,
    required double investShares,
    required double investNav,
    required double investFee,
    required int holdingId,
    required DateTime happenedAt,
    String? note,
    String? batchId,
  }) {
    return db.into(db.transactions).insert(TransactionsCompanion.insert(
      ledgerId: ledgerId,
      type: 'invest',
      amount: amount,
      accountId: d.Value(accountId),
      happenedAt: d.Value(happenedAt),
      note: d.Value(note),
      syncId: d.Value(_uuid.v4()),
      investType: d.Value(investType),
      investShares: d.Value(investShares),
      investNav: d.Value(investNav),
      investFee: d.Value(investFee),
      holdingId: d.Value(holdingId),
      batchId: d.Value(batchId),
      excludeFromStats: const d.Value(false),
      excludeFromBudget: const d.Value(true),
      currencyCode: d.Value(null),
      nativeAmount: d.Value(null),
    ));
  }

  Future<void> _updateHolding(int id, {
    double? totalShares,
    double? totalCost,
    double? currentNav,
    double? marketValue,
    DateTime? updatedAt,
  }) async {
    await (db.update(db.investmentHoldings)..where((h) => h.id.equals(id)))
        .write(InvestmentHoldingsCompanion(
      totalShares: totalShares != null ? d.Value(totalShares) : const d.Value.absent(),
      totalCost: totalCost != null ? d.Value(totalCost) : const d.Value.absent(),
      currentNav: currentNav != null ? d.Value(currentNav) : const d.Value.absent(),
      marketValue: marketValue != null ? d.Value(marketValue) : const d.Value.absent(),
      updatedAt: updatedAt != null ? d.Value(updatedAt) : const d.Value.absent(),
    ));
  }

  // ---- 核心操作 ----

  @override
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
  }) async {
    final total = shares * nav + fee;
    final effectiveHappenedAt = happenedAt ?? DateTime.now();

    return db.transaction(() async {
      // 1. 查找或创建持仓
      int effectiveHoldingId;
      double oldShares = 0;
      double oldCost = 0;

      if (holdingId != null) {
        effectiveHoldingId = holdingId;
        final h = await getHolding(holdingId);
        if (h != null) {
          oldShares = h.totalShares;
          oldCost = h.totalCost;
        }
      } else {
        final existing = await _findHolding(ledgerId, fundCode, accountId);
        if (existing != null) {
          effectiveHoldingId = existing.id;
          oldShares = existing.totalShares;
          oldCost = existing.totalCost;
        } else {
          // 新建持仓
          effectiveHoldingId = await db.into(db.investmentHoldings).insert(
                InvestmentHoldingsCompanion.insert(
                  ledgerId: ledgerId,
                  fundCode: fundCode,
                  fundName: fundName,
                  accountId: accountId,
                  note: d.Value(note),
                ),
              );
        }
      }

      // 2. 插入交易
      final txId = await _insertTx(
        ledgerId: ledgerId,
        accountId: accountId,
        investType: 'buy',
        amount: total,
        investShares: shares,
        investNav: nav,
        investFee: fee,
        holdingId: effectiveHoldingId,
        happenedAt: effectiveHappenedAt,
        note: note,
      );

      // 3. 更新持仓
     final newShares = oldShares + shares;
      final newCost = oldCost + shares * nav + fee;
     await _updateHolding(
        effectiveHoldingId,
        totalShares: newShares,
        totalCost: newCost,
        currentNav: nav,
        marketValue: newShares * nav,
        updatedAt: effectiveHappenedAt,
      );

      return txId;
    });
  }

  @override
  Future<int> sell({
    required int holdingId,
    required double shares,
    required double nav,
    double fee = 0,
    DateTime? happenedAt,
    String? note,
  }) async {
    final effectiveHappenedAt = happenedAt ?? DateTime.now();
    final proceeds = shares * nav - fee;

    return db.transaction(() async {
      final holding = await getHolding(holdingId);
      if (holding == null) throw StateError('持仓 $holdingId 不存在');
      if (holding.totalShares < shares) {
        throw StateError('持仓份额不足：持有 ${holding.totalShares}，试图卖出 $shares');
      }

      // 比例成本基数
      final costRatio =
          holding.totalShares > 0 ? shares / holding.totalShares : 1.0;
      final deductedCost = holding.totalCost * costRatio;
      final remainingShares = holding.totalShares - shares;

      // 插入交易
      final txId = await _insertTx(
        ledgerId: holding.ledgerId,
        accountId: holding.accountId,
        investType: 'sell',
        amount: proceeds,
        investShares: -shares,
        investNav: nav,
        investFee: fee,
        holdingId: holdingId,
        happenedAt: effectiveHappenedAt,
        note: note,
      );

      // 更新持仓
      await _updateHolding(
        holdingId,
        totalShares: max(0, remainingShares),
        totalCost: max(0, holding.totalCost - deductedCost),
        currentNav: nav,
        marketValue: max(0, remainingShares) * nav,
        updatedAt: effectiveHappenedAt,
      );

      return txId;
    });
  }

  @override
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
  }) async {
    final effectiveHappenedAt = happenedAt ?? DateTime.now();
    final batchId = _uuid.v4();

    return db.transaction(() async {
      final fromHolding = await getHolding(fromHoldingId);
      if (fromHolding == null) throw StateError('来源持仓 $fromHoldingId 不存在');
      if (fromHolding.totalShares < fromShares) {
        throw StateError(
            '来源持仓份额不足：持有 ${fromHolding.totalShares}，试图转换 $fromShares');
      }
      final toHolding = await getHolding(toHoldingId);
      if (toHolding == null) throw StateError('目标持仓 $toHoldingId 不存在');

      // 卖出来源持仓
      final costRatio =
          fromHolding.totalShares > 0 ? fromShares / fromHolding.totalShares : 1.0;
      final deductedCost = fromHolding.totalCost * costRatio;
      final fromRemaining = fromHolding.totalShares - fromShares;

      await _insertTx(
        ledgerId: fromHolding.ledgerId,
        accountId: fromHolding.accountId,
        investType: 'sell',
        amount: 0, // 转换无现金流
        investShares: -fromShares,
        investNav: fromNav,
        investFee: fee,
        holdingId: fromHoldingId,
        happenedAt: effectiveHappenedAt,
        note: note,
        batchId: batchId,
      );

      await _updateHolding(
        fromHoldingId,
        totalShares: max(0, fromRemaining),
        totalCost: max(0, fromHolding.totalCost - deductedCost),
        currentNav: fromNav,
        marketValue: max(0, fromRemaining) * fromNav,
        updatedAt: effectiveHappenedAt,
      );

      // 买入目标持仓
      final toNewShares = toHolding.totalShares + toShares;
      final txId = await _insertTx(
        ledgerId: toHolding.ledgerId,
        accountId: toHolding.accountId,
        investType: 'buy',
        amount: fee, // 转换手续费记为支出
        investShares: toShares,
        investNav: toNav,
        investFee: fee,
        holdingId: toHoldingId,
        happenedAt: effectiveHappenedAt,
        note: note,
        batchId: batchId,
      );

      await _updateHolding(
        toHoldingId,
        totalShares: toNewShares,
        totalCost: toHolding.totalCost + toShares * toNav,
        currentNav: toNav,
        marketValue: toNewShares * toNav,
        updatedAt: effectiveHappenedAt,
      );

      return txId;
    });
  }

  @override
  Future<void> updateNav(int holdingId, double nav) async {
    final holding = await getHolding(holdingId);
    if (holding == null) throw StateError('持仓 $holdingId 不存在');

    await _updateHolding(
      holdingId,
      currentNav: nav,
      marketValue: holding.totalShares * nav,
      updatedAt: DateTime.now(),
    );
  }

  @override
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
  }) async {
    final effectiveHappenedAt = happenedAt ?? DateTime.now();

    return db.transaction(() async {
      // 1. 新建持仓
      final holdingId = await db.into(db.investmentHoldings).insert(
            InvestmentHoldingsCompanion.insert(
              ledgerId: ledgerId,
              fundCode: fundCode,
              fundName: fundName,
              accountId: accountId,
              totalShares: d.Value(shares),
              totalCost: d.Value(cost),
              currentNav: d.Value(nav),
              marketValue: d.Value(shares * nav),
              note: d.Value(note),
              createdAt: d.Value(effectiveHappenedAt),
              updatedAt: d.Value(effectiveHappenedAt),
            ),
          );

      // 2. 插入初始投资交易记录
      await _insertTx(
        ledgerId: ledgerId,
        accountId: accountId,
        investType: 'buy',
        amount: cost,
        investShares: shares,
        investNav: nav,
        investFee: 0,
        holdingId: holdingId,
        happenedAt: effectiveHappenedAt,
        note: note ?? '初始持仓 $fundCode',
      );

      return holdingId;
    });
  }

  @override
  Stream<List<Transaction>> watchTransactions(int holdingId) {
    return (db.select(db.transactions)
          ..where((t) => t.holdingId.equals(holdingId))
          ..orderBy(
              [(t) => d.OrderingTerm(expression: t.happenedAt, mode: d.OrderingMode.desc)]))
        .watch();
  }
}
