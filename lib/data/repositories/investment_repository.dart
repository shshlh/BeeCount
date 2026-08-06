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
  /// [accountId] 为持仓归属的投资账户；为 null 或非投资类型时，自动查找
  /// 账本内已有投资账户，仍无则新建「投资账户」。禁止把扣款账户当作持仓归属。
  /// [sourceAccountId] 为扣款账户，买入视为从 source → 投资账户的转账。
  /// [amount] 为投入本金（确认金额），交易 amount 记录该本金，investFee 固定为 0；
  /// 持仓 totalCost 累加本金，市值按「份额 × 净值」计算。
  Future<int> buy({
    required int ledgerId,
    int? accountId,
    required String fundCode,
    required String fundName,
    required double shares,
    required double nav,
    required double amount,
    DateTime? happenedAt,
    String? note,
    int? holdingId,
    int? sourceAccountId,
  });

  /// 卖出基金/股票。
  ///
  /// 成本基数按比例扣减：sellCost = (shares / holding.totalShares) × holding.totalCost。
  /// [targetAccountId] 为回款账户，卖出视为从投资账户 → targetAccount 的转账。
  /// 返回插入的交易 ID。
  Future<int> sell({
    required int holdingId,
    required double shares,
    required double nav,
    double fee = 0,
    DateTime? happenedAt,
    String? note,
    int? targetAccountId,
  });

  /// 基金转换（A → B）。
  ///
  /// 同一事务内执行 A 卖出 + B 买入，两笔交易共享 batchId。
  /// [refundAmount] 为转换确认后退回金额（>=0），[refundAccountId] 为退回账户，
  /// refundAmount > 0 时必填；退回差额生成独立 transfer 记录，不进持仓。
  /// 返回买入交易 ID。
  Future<int> convert({
    required int fromHoldingId,
    required int toHoldingId,
    required double fromShares,
    required double fromNav,
    required double toShares,
    required double toNav,
    double fee = 0,
    double refundAmount = 0,
    int? refundAccountId,
    DateTime? happenedAt,
    String? note,
  });

  /// 更新持仓净值，同时重算市值（marketValue = totalShares × nav）。
  Future<void> updateNav(int holdingId, double nav);

  /// 更新投资交易的可编辑字段。
  /// 仅允许编辑 note / happenedAt / investShares / investNav / investFee / amount。
  /// [note] 为 null 表示不更新备注；[clearNote] 为 true 时把备注清空。
  /// 保存后在同一事务内按全部投资交易重算持仓 totalShares / totalCost /
  /// currentNav / marketValue，并同步投资账户市值。
  Future<void> updateTransaction(
    int transactionId, {
    String? note,
    bool clearNote = false,
    DateTime? happenedAt,
    double? investShares,
    double? investNav,
    double? investFee,
    double? amount,
  });

  /// 监听某个持仓的所有投资交易（按 happenedAt 降序）。
  Stream<List<Transaction>> watchTransactions(int holdingId);

  /// 创建初始持仓（导入已有投资记录）。
  ///
  /// 与 buy 不同，此方法直接以指定 [shares] 和 [cost] 建立持仓记录，
  /// 同时插入一条 transfer 类型交易记录（investType='initial', excludeFromStats=true）用于追溯。
  /// 若 (ledgerId, fundCode, accountId) 已存在持仓，则复用该持仓并累加份额/成本，
  /// 不再新建重复持仓（避免唯一索引冲突）。
  /// 返回持仓 ID。
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
  });

  // ---- 基金分组（v6.2，本地数据，不同步）----

  /// 创建自定义分组，返回分组 ID。
  Future<int> createGroup({
    required int ledgerId,
    required String name,
    int sortOrder = 0,
  });

  /// 分组改名。
  Future<void> renameGroup(int groupId, String name);

  /// 删除分组（关联成员行由外键级联清理）。
  Future<void> deleteGroup(int groupId);

  /// 向分组添加持仓（重复成员自动忽略）。
  Future<void> addHoldingsToGroup(int groupId, List<int> holdingIds);

  /// 从分组移除单个持仓。
  Future<void> removeHoldingFromGroup(int groupId, int holdingId);

  /// 整组替换成员（先清空再写入，供「编辑成员」使用）。
  Future<void> setGroupMembers(int groupId, List<int> holdingIds);

  /// 监听账本下所有分组（按 sortOrder 升序）。
  Stream<List<InvestmentGroup>> watchGroups({required int ledgerId});

  /// 监听某个分组包含的持仓 ID。
  Stream<List<int>> watchGroupHoldingIds(int groupId);
}
