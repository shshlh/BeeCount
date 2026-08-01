import 'dart:math';

import 'package:drift/drift.dart' as d;
import 'package:uuid/uuid.dart';

import '../../db.dart';
import '../../repositories/investment_repository.dart';
import '../../../utils/account_type_utils.dart';

const _uuid = Uuid();

/// 基于 Drift 的本地投资 Repository 实现。
/// 所有写操作（buy/sell/convert）在 db.transaction() 中原子执行。
/// v4.7: buy/sell 改为 transfer 类型（买卖即转账），初始持仓使用 investType='initial'。
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

  /// 解析买入的持仓归属账户。
  ///
  /// 传入的投资账户直接复用；传入 null 或非投资类型（例如扣款账户）时，
  /// 改为查找账本内已有投资账户，仍无则新建一个。保证持仓永远挂在投资账户下。
  Future<int> _resolveInvestmentAccount(int ledgerId, int? accountId) async {
    if (accountId != null) {
      final account = await (db.select(db.accounts)
            ..where((a) => a.id.equals(accountId)))
          .getSingleOrNull();
      if (account != null &&
          normalizeAccountType(account.type) == accountTypeInvestment) {
        return account.id;
      }
    }

    final existing = await (db.select(db.accounts)
          ..where((a) => a.type.equals(accountTypeInvestment))
          ..orderBy(
              [(a) => d.OrderingTerm(expression: a.sortOrder)]))
        .getSingleOrNull();
    if (existing != null) return existing.id;

    final ledger = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(ledgerId)))
        .getSingleOrNull();
    final currency = ledger?.currency ?? 'CNY';

    // 账户名全局唯一，直接插库前先避开同名账户。
    var name = '投资账户';
    var suffix = 2;
    while (true) {
      final dup = await (db.select(db.accounts)
            ..where((a) => a.name.equals(name)))
          .getSingleOrNull();
      if (dup == null) break;
      name = '投资账户 $suffix';
      suffix++;
    }

    return db.into(db.accounts).insert(AccountsCompanion.insert(
      ledgerId: ledgerId,
      name: name,
      type: d.Value(accountTypeInvestment),
      currency: d.Value(currency),
      initialBalance: const d.Value(0.0),
      createdAt: d.Value(DateTime.now()),
      syncId: d.Value(_uuid.v4()),
    ));
  }

  /// 把投资账户的缓存市值（initial_balance）同步为名下全部持仓市值之和。
  /// 账户页对投资账户直接读 initial_balance，必须在投资事务内同步更新。
  Future<void> _syncInvestmentAccountValue(int accountId) async {
    final account = await (db.select(db.accounts)
          ..where((a) => a.id.equals(accountId)))
        .getSingleOrNull();
    // 只同步投资账户；历史脏数据若把持仓挂在日常账户下，不能反向改写其余额。
    if (account == null ||
        normalizeAccountType(account.type) != accountTypeInvestment) {
      return;
    }

    final holdings = await (db.select(db.investmentHoldings)
          ..where((h) => h.accountId.equals(accountId)))
        .get();
    final total =
        holdings.fold<double>(0, (sum, h) => sum + h.marketValue);
    await (db.update(db.accounts)..where((a) => a.id.equals(accountId)))
        .write(AccountsCompanion(
      initialBalance: d.Value(total),
      updatedAt: d.Value(DateTime.now()),
    ));
  }

  /// 按该持仓的全部投资交易重算统计（与 buy/sell/convert 的成本口径一致）。
  ///
  /// 买入/初始登记按交易金额累加成本（金额缺失时按「份额 × 净值 + 手续费」，
  /// 转换买入只按份额 × 净值）；卖出/赎回/转换转出按卖出份额占比扣减成本。
  /// 当前净值取最后一笔交易净值，市值 = 份额 × 当前净值。
  Future<void> _recomputeHolding(int holdingId) async {
    final txs = await (db.select(db.transactions)
          ..where((t) => t.holdingId.equals(holdingId))
          ..orderBy([
            (t) => d.OrderingTerm(
                expression: t.happenedAt, mode: d.OrderingMode.asc),
            (t) => d.OrderingTerm(expression: t.id, mode: d.OrderingMode.asc),
          ]))
        .get();

    // 转换产生跨持仓的一对交易（batchId 相同、holdingId 不同），买入侧不记手续费。
    final batchIds =
        txs.map((t) => t.batchId).whereType<String>().toSet();
    final convertBatches = <String>{};
    for (final batchId in batchIds) {
      final batchTxs = await (db.select(db.transactions)
            ..where((t) => t.batchId.equals(batchId)))
          .get();
      final holdingIds =
          batchTxs.map((t) => t.holdingId).whereType<int>().toSet();
      if (holdingIds.length > 1) convertBatches.add(batchId);
    }

    double shares = 0;
    double cost = 0;
    double lastNav = 0;
    for (final tx in txs) {
      final invShares = tx.investShares ?? 0;
      final nav = tx.investNav ?? 0;
      final fee = tx.investFee ?? 0;
      final isConvert =
          tx.batchId != null && convertBatches.contains(tx.batchId);

      if (invShares < 0) {
        // 卖出方向：按份额比例扣减成本
        if (shares > 0) {
          final ratio = (-invShares).clamp(0.0, shares) / shares;
          cost -= cost * ratio;
        }
        shares += invShares;
      } else {
        shares += invShares;
        if (tx.investType == 'initial') {
          cost += tx.amount > 0 ? tx.amount : invShares * nav;
        } else if (isConvert) {
          cost += invShares * nav;
        } else {
          cost += tx.amount > 0 ? tx.amount : invShares * nav + fee;
        }
      }
      if (nav > 0) lastNav = nav;
    }

    final safeShares = max(0.0, shares);
    await _updateHolding(
      holdingId,
      totalShares: safeShares,
      totalCost: max(0.0, cost),
      currentNav: lastNav > 0 ? lastNav : null,
      marketValue: safeShares * lastNav,
      updatedAt: DateTime.now(),
    );
  }

  /// 插入投资交易（v4.7: type='transfer' 替代原有的 'invest'）。
  /// [toAccountId] 为转账目标账户（买入时=投资账户，卖出时=回款账户或null）。
  Future<int> _insertTx({
    required int ledgerId,
    required int? accountId,
    int? toAccountId,
    required String investType,
    required double amount,
    required double investShares,
    required double investNav,
    required double investFee,
    required int holdingId,
    required DateTime happenedAt,
    String? note,
    String? batchId,
    bool excludeFromStats = false,
  }) {
    return db.into(db.transactions).insert(TransactionsCompanion.insert(
      ledgerId: ledgerId,
      type: 'transfer',
      amount: amount,
      accountId: d.Value(accountId),
      toAccountId: d.Value(toAccountId),
      happenedAt: d.Value(happenedAt),
      note: d.Value(note),
      syncId: d.Value(_uuid.v4()),
      investType: d.Value(investType),
      investShares: d.Value(investShares),
      investNav: d.Value(investNav),
      investFee: d.Value(investFee),
      holdingId: d.Value(holdingId),
      batchId: d.Value(batchId),
      excludeFromStats: d.Value(excludeFromStats),
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
    int? accountId,
    required String fundCode,
    required String fundName,
    required double shares,
    required double nav,
    double fee = 0,
    DateTime? happenedAt,
    String? note,
    int? holdingId,
    int? sourceAccountId,
  }) async {
    final total = shares * nav + fee;
    final effectiveHappenedAt = happenedAt ?? DateTime.now();

    return db.transaction(() async {
      // v4.7 返工：持仓归属必须是投资账户，禁止用扣款账户顶替。
      final investmentAccountId =
          await _resolveInvestmentAccount(ledgerId, accountId);

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
        final existing =
            await _findHolding(ledgerId, fundCode, investmentAccountId);
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
                  accountId: investmentAccountId,
                  note: d.Value(note),
                ),
              );
        }
      }

      // 2. 插入交易（v4.7: transfer 类型）
      //    转账方向: sourceAccountId → accountId（投资账户）
      //    若未指定 sourceAccountId，则仅记到 accountId
      final txId = await _insertTx(
        ledgerId: ledgerId,
        accountId: sourceAccountId ?? investmentAccountId,
        toAccountId: investmentAccountId,
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

      // 同步投资账户市值
      await _syncInvestmentAccountValue(investmentAccountId);

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
    int? targetAccountId,
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

      // 插入交易（v4.7: transfer 类型，从投资账户 → targetAccount）
      final txId = await _insertTx(
        ledgerId: holding.ledgerId,
        accountId: holding.accountId,
        toAccountId: targetAccountId,
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

      // 同步投资账户市值
      await _syncInvestmentAccountValue(holding.accountId);

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
        toAccountId: null, // 转换无实际资金流动
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
        accountId: null,
        toAccountId: toHolding.accountId,
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

      // 同步双方投资账户市值（可能同一账户，重复同步无害）
      await _syncInvestmentAccountValue(fromHolding.accountId);
      await _syncInvestmentAccountValue(toHolding.accountId);

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

    // 净值变化联动投资账户市值
    await _syncInvestmentAccountValue(holding.accountId);
  }

  @override
  Future<void> updateTransaction(int transactionId, {
    String? note,
    DateTime? happenedAt,
    double? investShares,
    double? investNav,
    double? investFee,
    double? amount,
  }) async {
    await db.transaction(() async {
      await (db.update(db.transactions)
            ..where((t) => t.id.equals(transactionId)))
          .write(TransactionsCompanion(
        note: note != null ? d.Value(note) : const d.Value.absent(),
        happenedAt:
            happenedAt != null ? d.Value(happenedAt) : const d.Value.absent(),
        investShares: investShares != null
            ? d.Value(investShares)
            : const d.Value.absent(),
        investNav:
            investNav != null ? d.Value(investNav) : const d.Value.absent(),
        investFee:
            investFee != null ? d.Value(investFee) : const d.Value.absent(),
        amount: amount != null ? d.Value(amount) : const d.Value.absent(),
      ));

      // v4.7 返工：编辑交易后重算持仓统计并联动账户市值。
      final tx = await (db.select(db.transactions)
            ..where((t) => t.id.equals(transactionId)))
          .getSingleOrNull();
      final holdingId = tx?.holdingId;
      if (holdingId != null) {
        await _recomputeHolding(holdingId);
        final holding = await getHolding(holdingId);
        if (holding != null) {
          await _syncInvestmentAccountValue(holding.accountId);
        }
      }
    });
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
      // 1. 复用已有持仓（同账本+基金代码+账户），否则新建
      final existing =
          await _findHolding(ledgerId, fundCode, accountId);
      final int holdingId;
      if (existing != null) {
        holdingId = existing.id;
      } else {
        holdingId = await db.into(db.investmentHoldings).insert(
              InvestmentHoldingsCompanion.insert(
                ledgerId: ledgerId,
                fundCode: fundCode,
                fundName: fundName,
                accountId: accountId,
                note: d.Value(note),
                createdAt: d.Value(effectiveHappenedAt),
                updatedAt: d.Value(effectiveHappenedAt),
              ),
            );
      }

      // 2. 插入初始投资交易记录（v4.7: investType='initial', excludeFromStats=true）
      await _insertTx(
        ledgerId: ledgerId,
        accountId: accountId,
        toAccountId: null,
        investType: 'initial',
        amount: cost,
        investShares: shares,
        investNav: nav,
        investFee: 0,
        holdingId: holdingId,
        happenedAt: effectiveHappenedAt,
        note: note ?? '初始持仓 $fundCode',
        excludeFromStats: true,
      );

      // 3. 按全部投资交易重算持仓（复用场景自动累加份额/成本），并联动账户市值
      await _recomputeHolding(holdingId);
      await _syncInvestmentAccountValue(accountId);

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

