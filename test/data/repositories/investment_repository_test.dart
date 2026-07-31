import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_investment_repository.dart';

void main() {
  late BeeDatabase db;
  late LocalInvestmentRepository repo;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalInvestmentRepository(db);

    // 种子数据：一个账本 + 一个投资账户
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, currency) "
        "VALUES (10, 1, '投资账户', 'CNY')");
  });

  tearDown(() async => db.close());

  // ---- 买入 ----

  test('买入：全新持仓正确创建', () async {
    final txId = await repo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000001',
      fundName: '华夏成长混合',
      shares: 1000,
      nav: 1.5,
      fee: 10,
    );

    // 验证交易
    final tx = await db.customSelect(
        'SELECT * FROM transactions WHERE id = ?',
        variables: [Variable<int>(txId)]).getSingle();

    expect(tx.read<String>('type'), 'invest');
    expect(tx.read<String>('invest_type'), 'buy');
    expect(tx.read<double>('amount'), 1510.0); // 1000*1.5+10
    expect(tx.read<double>('invest_shares'), 1000);
    expect(tx.read<double>('invest_nav'), 1.5);
    expect(tx.read<double>('invest_fee'), 10);

    // 验证持仓
    final holdings = db.select(db.investmentHoldings).get();
    final h = (await holdings).single;
   expect(h.totalShares, 1000);
    expect(h.totalCost, 1510.0); // 1000*1.5+10
   expect(h.currentNav, 1.5);
    expect(h.marketValue, 1500.0); // 1000*1.5
    expect(h.fundCode, '000001');
    expect(h.accountId, 10);
  });

  test('买入：追加已有持仓份额', () async {
    // 先买一次
    await repo.buy(
      ledgerId: 1, accountId: 10, fundCode: '000001', fundName: '华夏成长',
      shares: 1000, nav: 1.0);

    // 再买一次（同组基金代码+账户）
    await repo.buy(
      ledgerId: 1, accountId: 10, fundCode: '000001', fundName: '华夏成长',
      shares: 500, nav: 1.2);

    final holdings = db.select(db.investmentHoldings).get();
    expect((await holdings).length, 1); // 同一持仓
    final h = (await holdings).single;
    expect(h.totalShares, 1500);
    expect(h.totalCost, closeTo(1600, 0.01)); // 1000*1.0+500*1.2
  });

  // ---- 卖出 ----

  test('卖出：全额卖出成本减为零', () async {
    // 买入
    await repo.buy(
      ledgerId: 1, accountId: 10, fundCode: '000001', fundName: '华夏成长',
      shares: 1000, nav: 2.0);

    // 卖出全部
    final txId = await repo.sell(
      holdingId: 1, shares: 1000, nav: 2.5, fee: 5);

    final tx = await db.customSelect(
        'SELECT * FROM transactions WHERE id = ?',
        variables: [Variable<int>(txId)]).getSingle();
    expect(tx.read<String>('invest_type'), 'sell');
    expect(tx.read<double>('invest_shares'), -1000);
    expect(tx.read<double>('amount'), 2495.0); // 1000*2.5-5

    // 成本基数清零
    final h = await repo.getHolding(1);
    expect(h!.totalShares, 0);
    expect(h.totalCost, 0);
  });

  test('卖出：部分卖出按比例扣减成本', () async {
    await repo.buy(
      ledgerId: 1, accountId: 10, fundCode: '000001', fundName: '华夏成长',
      shares: 1000, nav: 2.0); // 总成本 2000

    await repo.sell(holdingId: 1, shares: 500, nav: 2.5);

    final h = await repo.getHolding(1);
    expect(h!.totalShares, 500);
    expect(h.totalCost, closeTo(1000, 0.01)); // 2000 * 500/1000
  });

  test('卖出：份额不足应抛异常', () async {
    await repo.buy(
      ledgerId: 1, accountId: 10, fundCode: '000001', fundName: '华夏成长',
      shares: 100, nav: 1.0);

    await expectLater(
      () => repo.sell(holdingId: 1, shares: 200, nav: 1.0),
      throwsA(isA<StateError>()),
    );
  });

  // ---- 转换 ----

  test('转换：A→B 两笔交易共享 batchId', () async {
    // 买入 A
    await repo.buy(
      ledgerId: 1, accountId: 10, fundCode: '000001', fundName: '基金A',
      shares: 1000, nav: 1.0);
    // 买入 B（初始买入，以便转换时有现有持仓）
    await repo.buy(
      ledgerId: 1, accountId: 10, fundCode: '000002', fundName: '基金B',
      shares: 500, nav: 1.0);

    await repo.convert(
      fromHoldingId: 1, toHoldingId: 2,
      fromShares: 500, fromNav: 1.2,
      toShares: 480, toNav: 1.25,
      fee: 5,
    );

    // 来源持仓减少
    final from = await repo.getHolding(1);
    expect(from!.totalShares, 500); // 1000-500
    expect(from.totalCost, closeTo(500, 0.01)); // 1000 * 500/1000

    // 目标持仓增加
    final to = await repo.getHolding(2);
    expect(to!.totalShares, 980); // 500+480
    expect(to.totalCost, closeTo(1100, 0.01)); // 500+480*1.25

    // 两笔交易共享 batchId
    final txs = await repo.watchTransactions(1).first;
    final convertTxs = txs.where((t) => t.batchId != null).toList();
    expect(convertTxs.length, 1); // sell side

    final txs2 = await repo.watchTransactions(2).first;
    final convertTxs2 = txs2.where((t) => t.batchId != null).toList();
    expect(convertTxs2.length, 1); // buy side

    // 两笔交易 batchId 相同
    expect(convertTxs.first.batchId, convertTxs2.first.batchId);
  });

  // ---- 净值更新 ----

  test('更新净值：NAV 和市值联动更新', () async {
    await repo.buy(
      ledgerId: 1, accountId: 10, fundCode: '000001', fundName: '华夏成长',
      shares: 1000, nav: 1.0);

    await repo.updateNav(1, 1.5);

    final h = await repo.getHolding(1);
    expect(h!.currentNav, 1.5);
    expect(h.marketValue, 1500.0); // 1000*1.5
  });

  // ---- 查询 ----

  test('watchHoldings：过滤份额为 0 的持仓', () async {
    // 买入并全卖
    await repo.buy(
      ledgerId: 1, accountId: 10, fundCode: '000001', fundName: '华夏成长',
      shares: 1000, nav: 1.0);
    await repo.sell(holdingId: 1, shares: 1000, nav: 1.0);

    // 再买另一支
    await repo.buy(
      ledgerId: 1, accountId: 10, fundCode: '000002', fundName: '基金B',
      shares: 500, nav: 1.0);

    final holdings = await repo.watchHoldings(ledgerId: 1).first;
    expect(holdings.length, 1);
    expect(holdings.single.fundCode, '000002');
  });
}
