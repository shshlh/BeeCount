import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_investment_repository.dart';
import 'package:beecount/services/data/investment_service.dart';

void main() {
  late BeeDatabase db;
  late LocalInvestmentRepository repo;
  late InvestmentService service;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalInvestmentRepository(db);
    service = InvestmentService(repo);

    // 种子数据：账本 + 投资账户
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, type, currency) "
        "VALUES (10, 1, '投资账户', 'investment', 'CNY')");
  });

  tearDown(() async => db.close());

  // ---- 组合摘要 ----

  test('getPortfolioSummary：无持仓时返回全零摘要', () async {
    final summary = await service.getPortfolioSummary(1);
    expect(summary.totalMarketValue, 0);
    expect(summary.totalCost, 0);
    expect(summary.unrealizedPnL, 0);
    expect(summary.returnRate, 0);
    expect(summary.holdingCount, 0);
  });

  test('getPortfolioSummary：有持仓时计算总市值/成本/盈亏/收益率', () async {
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 2000,
        shares: 1000,
        nav: 2.0); // 成本 2000，市值 2000
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000002',
        fundName: '基金B',
        amount: 1500,
        shares: 500,
        nav: 3.0); // 成本 1500，市值 1500
    // 更新 B 的净值模拟浮盈
    await repo.updateNav(2, 4.0); // 市值 → 2000

    final summary = await service.getPortfolioSummary(1);

    expect(summary.holdingCount, 2);
    expect(summary.totalCost, closeTo(3500, 0.01)); // 2000 + 1500
    expect(summary.totalMarketValue, closeTo(4000, 0.01)); // 2000 + 2000
    expect(summary.unrealizedPnL, closeTo(500, 0.01));
    expect(summary.returnRate, closeTo(500 / 3500, 0.001));
  });

  // ---- 批量净值刷新 ----

  test('batchUpdateNav：批量更新多支持仓净值', () async {
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 1000,
        shares: 1000,
        nav: 1.0);
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000002',
        fundName: '基金B',
        amount: 500,
        shares: 500,
        nav: 1.0);

    await service.batchUpdateNav({1: 2.0, 2: 3.0});

    final a = await repo.getHolding(1);
    expect(a!.currentNav, 2.0);
    expect(a.marketValue, 2000.0); // 1000 * 2.0

    final b = await repo.getHolding(2);
    expect(b!.currentNav, 3.0);
    expect(b.marketValue, 1500.0); // 500 * 3.0
  });

  // ---- 单持仓收益 ----

  test('getHoldingReturn：计算未实现盈亏和收益率', () async {
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 2000,
        shares: 1000,
        nav: 2.0); // 成本 2000
    await repo.updateNav(1, 2.5); // 市值 2500

    final r = await service.getHoldingReturn(1);
    expect(r.unrealizedPnL, closeTo(500, 0.01)); // 2500 - 2000
    expect(r.returnRate, closeTo(0.25, 0.001)); // 500 / 2000
  });

  test('getHoldingReturn：持仓不存在时返回零', () async {
    final r = await service.getHoldingReturn(999);
    expect(r.unrealizedPnL, 0);
    expect(r.returnRate, 0);
  });

  test('getHoldingReturn：Decimal 精度用例', () async {
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 0.005,
        shares: 0.1,
        nav: 0.1); // 市值 0.01，成本 0.005

    final r = await service.getHoldingReturn(1);
    expect(r.unrealizedPnL, 0.005);
    expect(r.returnRate, 1.0);
  });

  // ---- 验证 ----

  test('validateBuy：份额 <= 0 抛异常', () {
    expect(
      () => service.validateBuy(amount: 100, shares: 0, nav: 1.0),
      throwsArgumentError,
    );
    expect(
      () => service.validateBuy(amount: 100, shares: -1, nav: 1.0),
      throwsArgumentError,
    );
  });

  test('validateBuy：净值 <= 0 抛异常', () {
    expect(
      () => service.validateBuy(amount: 100, shares: 100, nav: 0),
      throwsArgumentError,
    );
    expect(
      () => service.validateBuy(amount: 100, shares: 100, nav: -1),
      throwsArgumentError,
    );
  });

  test('validateBuy：本金 <= 0 抛异常', () {
    expect(
      () => service.validateBuy(amount: 0, shares: 100, nav: 1.0),
      throwsArgumentError,
    );
    expect(
      () => service.validateBuy(amount: -1, shares: 100, nav: 1.0),
      throwsArgumentError,
    );
  });

  test('validateSell：份额不足时抛异常', () async {
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 100,
        shares: 100,
        nav: 1.0);

    await expectLater(
      () => service.validateSell(1, 200),
      throwsA(isA<StateError>()),
    );
  });

  test('validateSell：份额 <= 0 抛异常', () {
    expect(
      () => service.validateSell(1, 0),
      throwsArgumentError,
    );
    expect(
      () => service.validateSell(1, -10),
      throwsArgumentError,
    );
  });

  test('validateConvert：份额不足时抛异常', () async {
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 100,
        shares: 100,
        nav: 1.0);

    await expectLater(
      () => service.validateConvert(1, 200),
      throwsA(isA<StateError>()),
    );
  });

  // ---- 委托验证 ----

  test('buy：委托 repo，返回交易 ID', () async {
    final txId = await service.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 1000,
        shares: 500,
        nav: 2.0);
    expect(txId, isPositive);

    final h = await repo.getHolding(1);
    expect(h!.totalShares, 500);
    expect(h.totalCost, 1000.0); // 投入本金
  });

  test('sell：委托 repo，按比例扣减成本', () async {
    await service.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 2000,
        shares: 1000,
        nav: 2.0);

    await service.sell(holdingId: 1, shares: 500, nav: 3.0, fee: 5);

    final h = await repo.getHolding(1);
    expect(h!.totalShares, 500);
    expect(h.totalCost, closeTo(1000, 0.01)); // 2000 * 500/1000
  });

  test('convert：委托 repo，A减B增', () async {
    await service.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 1000,
        shares: 1000,
        nav: 1.0);
    await service.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000002',
        fundName: '基金B',
        amount: 500,
        shares: 500,
        nav: 1.0);

    await service.convert(
        fromHoldingId: 1,
        toHoldingId: 2,
        fromShares: 500,
        fromNav: 1.2,
        toShares: 480,
        toNav: 1.25,
        fee: 5);

    final from = await repo.getHolding(1);
    expect(from!.totalShares, 500); // 1000 - 500

    final to = await repo.getHolding(2);
    expect(to!.totalShares, 980); // 500 + 480
  });

  // ---- watchHoldings/watchTransactions 委托 ----

  test('watchHoldings：委托 repo 返回持仓流', () async {
    await service.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 100,
        shares: 100,
        nav: 1.0);

    final holdings = await service.watchHoldings(ledgerId: 1).first;
    expect(holdings.length, 1);
    expect(holdings.single.fundCode, '000001');
  });
}
