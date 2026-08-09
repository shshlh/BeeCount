import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/ai/core/financial_analyst_context.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_investment_repository.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalRepository repo;
  late LocalInvestmentRepository investRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    investRepo = LocalInvestmentRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('账本与投资摘要内容完整', () async {
    final ledgerId = await repo.createLedger(name: '测试账本', currency: 'CNY');
    final cashId = await repo.createAccount(
      ledgerId: ledgerId,
      name: '现金',
      type: 'cash',
      currency: 'CNY',
      initialBalance: 2000,
    );
    final foodCat = await repo.createCategory(name: '餐饮', kind: 'expense');
    await repo.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 100,
      categoryId: foodCat,
      accountId: cashId,
      happenedAt: DateTime.now().subtract(const Duration(days: 1)),
    );
    await repo.addTransaction(
      ledgerId: ledgerId,
      type: 'income',
      amount: 500,
      accountId: cashId,
      happenedAt: DateTime.now().subtract(const Duration(days: 1)),
    );

    final investAccountId = await repo.createAccount(
      ledgerId: ledgerId,
      name: '投资账户',
      type: 'investment',
      currency: 'CNY',
    );
    await investRepo.buy(
      ledgerId: ledgerId,
      accountId: investAccountId,
      fundCode: '000001',
      fundName: '华夏成长混合',
      amount: 1500,
      shares: 1000,
      nav: 1.5,
      happenedAt: DateTime.now().subtract(const Duration(days: 2)),
    );
    final holding =
        (await investRepo.watchHoldings(ledgerId: ledgerId).first).single;
    await investRepo.updateNav(holding.id, 2.0);

    final ctx = await FinancialAnalystContext.forLedger(
      repository: repo,
      investmentRepository: investRepo,
      ledgerId: ledgerId,
      recentTxLimit: 5,
      holdingsLimit: 5,
    );

    expect(ctx.accounts.map((a) => a.name), contains('现金'));
    expect(ctx.holdings.single.fundName, '华夏成长混合');
    expect(ctx.holdings.single.pnl, closeTo(500, 0.001));
    expect(ctx.holdings.single.returnRate, closeTo(0.333333, 0.001));
    expect(ctx.recentInvestmentTransactions.single.type, 'buy');
    expect(ctx.recent30!.expense, 100);
    expect(ctx.recent30!.income, 500);
    expect(ctx.thisMonth!.expense, 100);
    expect(ctx.topExpenseCategories.single.name, '餐饮');
    expect(ctx.scopeLabel(), contains('1 只持仓'));
    expect(ctx.toPromptText(), contains('华夏成长混合'));
  });

  test('隐藏账户 / 不计入资产 / 不计入统计按口径过滤', () async {
    final ledgerId = await repo.createLedger(name: '过滤', currency: 'CNY');
    await repo.createAccount(
      ledgerId: ledgerId,
      name: '可见现金',
      type: 'cash',
      currency: 'CNY',
      initialBalance: 2000,
    );
    final hiddenId = await repo.createAccount(
      ledgerId: ledgerId,
      name: '隐藏账户',
      type: 'cash',
      currency: 'CNY',
      initialBalance: 1000,
    );
    await repo.setAccountHidden(hiddenId, true);
    await repo.createAccount(
      ledgerId: ledgerId,
      name: '不计资产',
      type: 'cash',
      currency: 'CNY',
      initialBalance: 3000,
      excludeFromAssets: true,
    );
    final usdId = await repo.createAccount(
      ledgerId: ledgerId,
      name: '美元账户',
      type: 'cash',
      currency: 'USD',
      initialBalance: 100,
    );
    await repo.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 999,
      accountId: usdId,
      happenedAt: DateTime.now().subtract(const Duration(days: 1)),
      excludeFromStats: true,
    );

    final ctx = await FinancialAnalystContext.forLedger(
      repository: repo,
      investmentRepository: investRepo,
      ledgerId: ledgerId,
    );

    expect(ctx.accounts.map((a) => a.name), isNot(contains('隐藏账户')));
    expect(ctx.netWorth!.assets, closeTo(2000, 0.001));
    expect(ctx.recent30!.expense, 0);
    expect(ctx.missingRateCurrencies, contains('USD'));
    expect(ctx.toPromptText(), contains('缺少汇率'));
  });

  test('表外账户不进入 AI 摘要', () async {
    final ledgerId = await repo.createLedger(name: '表外', currency: 'CNY');
    await repo.createAccount(
      ledgerId: ledgerId,
      name: '自有现金',
      type: 'cash',
      currency: 'CNY',
      initialBalance: 2000,
    );
    await repo.createAccount(
      ledgerId: ledgerId,
      name: '受托资金',
      type: 'cash',
      currency: 'CNY',
      initialBalance: 500,
      isOffBalance: true,
    );
    await repo.createAccount(
      ledgerId: ledgerId,
      name: '受托美元',
      type: 'cash',
      currency: 'USD',
      initialBalance: 100,
      isOffBalance: true,
    );

    final ctx = await FinancialAnalystContext.forLedger(
      repository: repo,
      investmentRepository: investRepo,
      ledgerId: ledgerId,
    );

    expect(ctx.accounts.map((a) => a.name), isNot(contains('受托资金')));
    expect(ctx.accounts.map((a) => a.name), isNot(contains('受托美元')));
    expect(ctx.netWorth!.assets, closeTo(2000, 0.001));
    expect(ctx.missingRateCurrencies, isNot(contains('USD')));
    expect(ctx.toPromptText(), isNot(contains('受托资金')));
    expect(ctx.toPromptText(), isNot(contains('受托美元')));
  });

  test('toPromptText 受 maxChars 限制', () async {
    final ledgerId = await repo.createLedger(name: 'Token', currency: 'CNY');
    final cashId = await repo.createAccount(
      ledgerId: ledgerId,
      name: '现金',
      type: 'cash',
      currency: 'CNY',
      initialBalance: 2000,
    );
    final catId = await repo.createCategory(name: '餐饮', kind: 'expense');
    for (var i = 0; i < 20; i++) {
      await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 100.0 + i,
        categoryId: catId,
        accountId: cashId,
        happenedAt: DateTime.now().subtract(Duration(days: i % 10)),
      );
    }

    final ctx = await FinancialAnalystContext.forLedger(
      repository: repo,
      investmentRepository: investRepo,
      ledgerId: ledgerId,
    );
    final text = ctx.toPromptText(maxChars: 200);

    expect(text.length, lessThanOrEqualTo(200));
    expect(text, endsWith('...'));
  });

  test('空数据兜底', () async {
    final ledgerId = await repo.createLedger(name: '空账本', currency: 'CNY');

    final ctx = await FinancialAnalystContext.forLedger(
      repository: repo,
      investmentRepository: investRepo,
      ledgerId: ledgerId,
    );

    expect(ctx.accounts, isEmpty);
    expect(ctx.holdings, isEmpty);
    expect(ctx.recentInvestmentTransactions, isEmpty);
    expect(ctx.scopeLabel(), contains('无持仓'));
    expect(ctx.toPromptText(), contains('无持仓'));
  });

  test('FinancialAnalystSnapshot.empty 可安全使用', () {
    const snapshot = FinancialAnalystSnapshot.empty;
    expect(snapshot.accounts, isEmpty);
    expect(snapshot.holdings, isEmpty);
    expect(snapshot.scopeLabel(), contains('无持仓'));
    expect(snapshot.toPromptText(maxChars: 100), isNotEmpty);
  });
}
