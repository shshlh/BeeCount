import '../db.dart';

/// 投资 Repository 接口。
/// 定义投资持仓和投资交易相关的所有数据操作。
/// 阶段 1-4 为本地专用，不进同步。
abstract class InvestmentRepository {
  /// 监听账本下所有持仓（持仓份额 > 0 的才返回）。
  Stream<List<InvestmentHolding>> watchHoldings({required int ledgerId});

  /// 获取账本下全部持仓（含 0 份额历史行），供 CSV 导出归档。
  Future<List<InvestmentHolding>> getHoldingsForLedger(int ledgerId);

  /// 获取账本下全部投资流水（含转换内部卖出/买入与退回），供 CSV 导出归档。
  Future<List<Transaction>> getInvestmentTransactionsForLedger(int ledgerId);

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
    DateTime? navDate,
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
    DateTime? navDate,
    String? note,
    int? targetAccountId,
  });

  /// 基金转换（A → B）。
  ///
  /// 同一事务内执行 A 卖出 + B 买入，两笔交易共享 batchId。
  /// [toCost] 为转入成本（确认的转入金额，必填且 >0），B 持仓成本与
  /// 买入侧交易 amount 均以它为准；手续费只记在转出侧。
  /// [refundAmount] 为转换确认后退回金额（>=0），[refundAccountId] 为退回账户，
  /// refundAmount > 0 时必填；退回差额生成独立 transfer 记录，不进持仓。
  /// [toHoldingId] 为空时支持手填新目标基金：[fundCode] / [fundName] 必填，
  /// 先按 (ledgerId, fundCode, 来源投资账户) 查找已有持仓，未找到则创建。
  /// 返回买入交易 ID。
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
  });

  /// 更新一整笔转换（A 卖出 + B 买入 + 关联退回），按 batchId 原子更新。
  ///
  /// 仅允许调整确认份额/净值、转入成本、手续费、退回金额/账户、日期与备注；
  /// 不改变双方基金与持仓归属。保存后重算双方持仓并联动投资账户市值。
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
  });

  /// 删除一整笔转换（A 卖出 + B 买入 + 关联退回），按 batchId 原子删除。
  ///
  /// 删除后重算双方持仓并联动投资账户市值；与单笔流水删除一样清理标签/附件。
  Future<void> deleteConversion(String batchId);

  /// 按 batchId 取转换批次下的全部交易（卖出/买入/退回），供编辑预填。
  Future<List<Transaction>> getTransactionsByBatchId(String batchId);

  /// 更新持仓净值，同时重算市值（marketValue = totalShares × nav）。
  Future<void> updateNav(int holdingId, double nav, {DateTime? navDate});

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
    DateTime? navDate,
    String? note,
  });

  /// 更新持仓的基金代码/名称（6.13 防错）。
  ///
  /// [fundCode] 必须为 6 位数字；同账本+账户下已存在相同代码时拒绝，
  /// 避免误改造成持仓静默合并。只改元信息，保留份额/成本/净值/市值。
  Future<void> updateHoldingInfo(
    int holdingId, {
    required String fundCode,
    String? fundName,
  });

  /// 删除整个持仓（6.13.4）。
  ///
  /// 在同一事务内删除持仓关联交易、分组关联与持仓行，并同步投资账户市值，
  /// 避免 0 份额历史行残留。
  Future<void> deleteHolding(int holdingId);

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

  /// 7.10.3 投资 CSV 导入：按 (ledgerId, fundCode, accountId) 幂等恢复持仓。
  Future<int> upsertHoldingForImport({
    required int ledgerId,
    required int accountId,
    required String fundCode,
    required String fundName,
    required double totalShares,
    required double totalCost,
    double currentNav = 0,
    DateTime? navDate,
    double marketValue = 0,
    String? note,
  });

  /// 7.10.3 投资 CSV 导入：按名称查找分组，不存在则创建并返回 ID。
  Future<int> ensureGroupForImport({
    required int ledgerId,
    required String name,
    int sortOrder = 0,
  });

  /// 7.10.3 投资 CSV 导入后刷新投资账户市值缓存。
  Future<void> syncInvestmentAccountValue(int accountId);
}
