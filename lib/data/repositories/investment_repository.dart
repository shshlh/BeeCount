import '../db.dart';

/// 投资 Repository 接口。
/// 定义投资持仓和投资交易相关的所有数据操作。
/// 阶段 1-4 为本地专用，不进同步。
abstract class InvestmentRepository {
  /// 监听账本下所有持仓（持仓份额 > 0 的才返回）。
  Stream<List<InvestmentHolding>> watchHoldings({required int ledgerId});

  /// 获取单个持仓。
  Future<InvestmentHolding?> getHolding(int id);

  /// 买入基金/股票。
  ///
  /// 返回插入的交易 ID。
  /// 若 [holdingId] 为 null，则按 (ledgerId, fundCode, accountId) 查找
  /// 已有持仓——找到则追加份额，未找到则新建持仓。
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
  });

  /// 卖出基金/股票。
  ///
  /// 成本基数按比例扣减：sellCost = (shares / holding.totalShares) × holding.totalCost。
  /// 返回插入的交易 ID。
  Future<int> sell({
    required int holdingId,
    required double shares,
    required double nav,
    double fee = 0,
    DateTime? happenedAt,
    String? note,
  });

  /// 基金转换（A → B）。
  ///
  /// 同一事务内执行 A 卖出 + B 买入，两笔交易共享 batchId。
  /// 返回买入交易 ID。
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
  });

  /// 更新持仓净值，同时重算市值（marketValue = totalShares × nav）。
  Future<void> updateNav(int holdingId, double nav);

  /// 监听某个持仓的所有投资交易（按 happenedAt 降序）。
  Stream<List<Transaction>> watchTransactions(int holdingId);
}
