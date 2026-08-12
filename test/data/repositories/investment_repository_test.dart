import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_investment_repository.dart';
import 'package:beecount/data/repositories/local/local_account_repository.dart';
import 'package:beecount/data/repositories/local/local_transaction_repository.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  final String docsDir;
  final String cacheDir;

  _FakePathProviderPlatform()
      : docsDir = Directory.systemTemp.createTempSync('app_docs').path,
        cacheDir = Directory.systemTemp.createTempSync('app_cache').path;

  @override
  Future<String?> getApplicationDocumentsPath() async => docsDir;

  @override
  Future<String?> getTemporaryPath() async => cacheDir;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  PathProviderPlatform.instance = _FakePathProviderPlatform();

  late BeeDatabase db;
  late LocalInvestmentRepository repo;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalInvestmentRepository(db);

    // 种子数据：一个账本 + 一个投资账户
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, type, currency) "
        "VALUES (10, 1, '投资账户', 'investment', 'CNY')");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, type, currency, initial_balance) "
        "VALUES (20, 1, '支付宝', 'virtual_account', 'CNY', 5000)");
  });

  tearDown(() async => db.close());

  // ---- 买入 ----

  test('买入：全新持仓正确创建', () async {
    final txId = await repo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000001',
      fundName: '华夏成长混合',
      amount: 1500,
      shares: 1000,
      nav: 1.5,
    );

    // 验证交易
    final tx = await db.customSelect('SELECT * FROM transactions WHERE id = ?',
        variables: [Variable<int>(txId)]).getSingle();

    expect(tx.read<String>('type'), 'transfer');
    expect(tx.read<String>('invest_type'), 'buy');
    expect(tx.read<double>('amount'), 1500.0); // 投入本金
    expect(tx.read<double>('invest_shares'), 1000);
    expect(tx.read<double>('invest_nav'), 1.5);
    expect(tx.read<double>('invest_fee'), 0);

    // 验证持仓
    final holdings = db.select(db.investmentHoldings).get();
    final h = (await holdings).single;
    expect(h.totalShares, 1000);
    expect(h.totalCost, 1500.0); // 投入本金
    expect(h.currentNav, 1.5);
    expect(h.marketValue, 1500.0); // 1000*1.5
    expect(h.fundCode, '000001');
    expect(h.accountId, 10);
  });

  test('买入：追加已有持仓份额', () async {
    // 先买一次
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '华夏成长',
        amount: 1000,
        shares: 1000,
        nav: 1.0);

    // 再买一次（同组基金代码+账户）
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '华夏成长',
        amount: 600,
        shares: 500,
        nav: 1.2);

    final holdings = db.select(db.investmentHoldings).get();
    expect((await holdings).length, 1); // 同一持仓
    final h = (await holdings).single;
    expect(h.totalShares, 1500);
    expect(h.totalCost, closeTo(1600, 0.01)); // 1000*1.0+500*1.2
  });

  test('买入：投入本金即成本，手续费固定为 0', () async {
    final txId = await repo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000001',
      fundName: '华夏成长混合',
      amount: 1001.5,
      shares: 1000,
      nav: 1.0,
    );

    final tx = await db.customSelect('SELECT * FROM transactions WHERE id = ?',
        variables: [Variable<int>(txId)]).getSingle();
    expect(tx.read<double>('amount'), 1001.5);
    expect(tx.read<double>('invest_fee'), 0);

    final h = await repo.getHolding(1);
    expect(h!.totalCost, 1001.5);
    expect(h.marketValue, 1000.0); // 1000 × 1.0
  });

  test('Decimal 精度：0.1 份额 × 0.1 净值 = 0.01 市值', () async {
    await repo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000001',
      fundName: '华夏成长混合',
      amount: 0.01,
      shares: 0.1,
      nav: 0.1,
    );

    final h = await repo.getHolding(1);
    expect(h!.marketValue, 0.01);
    expect(h.totalCost, 0.01);
  });

  test('买入：多账本各有投资账户时回退不串账本', () async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (2, 'L2', 'CNY')");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, type, currency) "
        "VALUES (30, 2, '投资账户2', 'investment', 'CNY')");

    final txId = await repo.buy(
      ledgerId: 2,
      accountId: null,
      fundCode: '000010',
      fundName: '基金X',
      amount: 100,
      shares: 100,
      nav: 1.0,
    );

    final tx = await db.customSelect('SELECT * FROM transactions WHERE id = ?',
        variables: [Variable<int>(txId)]).getSingle();
    final holding = await db.select(db.investmentHoldings).getSingle();

    expect(holding.accountId, 30);
    expect(tx.read<int>('account_id'), 30);
  });

  test('买入：同账本多个投资账户时回退取首个不抛错', () async {
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, type, currency, sort_order) "
        "VALUES (11, 1, '投资账户2', 'investment', 'CNY', 1)");

    await repo.buy(
      ledgerId: 1,
      accountId: null,
      fundCode: '000001',
      fundName: '基金A',
      amount: 100,
      shares: 100,
      nav: 1.0,
    );

    final holding = await db.select(db.investmentHoldings).getSingle();
    expect(holding.accountId, 10); // sortOrder 0 的投资账户优先
  });

  test('买入：指定不存在的 holdingId 时抛 StateError，不产生孤儿交易', () async {
    await expectLater(
      () => repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 100,
        shares: 100,
        nav: 1.0,
        holdingId: 999,
      ),
      throwsA(isA<StateError>()),
    );

    final txs = await db.select(db.transactions).get();
    expect(txs, isEmpty);
  });

  test('买入：无投资账户时自动创建，不把扣款账户当持仓归属', () async {
    // 删掉种子投资账户，只剩可交易账户
    await db.customStatement('DELETE FROM accounts WHERE id = 10');

    final txId = await repo.buy(
      ledgerId: 1,
      accountId: 20, // 扣款账户（virtual_account）
      fundCode: '000001',
      fundName: '华夏成长混合',
      amount: 1500,
      shares: 1000,
      nav: 1.5,
      sourceAccountId: 20,
    );

    final tx = await db.customSelect('SELECT * FROM transactions WHERE id = ?',
        variables: [Variable<int>(txId)]).getSingle();
    expect(tx.read<int>('account_id'), 20); // 扣款方

    final holding = await db.select(db.investmentHoldings).getSingle();
    expect(holding.accountId, isNot(20));

    final investmentAccount = await (db.select(db.accounts)
          ..where((a) => a.id.equals(holding.accountId)))
        .getSingle();
    expect(investmentAccount.type, 'investment');
    expect(tx.read<int>('to_account_id'), holding.accountId);
  });

  test('买入：accountId 误传扣款账户时仍归属投资账户', () async {
    final txId = await repo.buy(
      ledgerId: 1,
      accountId: 20, // 错误传成扣款账户
      fundCode: '000001',
      fundName: '华夏成长混合',
      amount: 1500,
      shares: 1000,
      nav: 1.5,
      sourceAccountId: 20,
    );

    final holding = await db.select(db.investmentHoldings).getSingle();
    expect(holding.accountId, 10); // 归到种子投资账户

    final tx = await db.customSelect('SELECT * FROM transactions WHERE id = ?',
        variables: [Variable<int>(txId)]).getSingle();
    expect(tx.read<int>('account_id'), 20);
    expect(tx.read<int>('to_account_id'), 10);
  });

  // ---- 余额联动 ----

  test('余额联动：买入/卖出同步扣款账户与投资账户市值', () async {
    final accountRepo = LocalAccountRepository(db);

    // 买入 1000 @ 1.5，投入本金 1510
    await repo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000001',
      fundName: '华夏成长混合',
      amount: 1510,
      shares: 1000,
      nav: 1.5,
      sourceAccountId: 20,
    );

    final afterBuy = await (db.select(db.accounts)
          ..where((a) => a.id.equals(10)))
        .getSingle();
    expect(afterBuy.initialBalance, closeTo(1500, 0.01)); // 1000*1.5
    expect(await accountRepo.getAccountBalance(20),
        closeTo(3490, 0.01)); // 5000-1510

    // 卖出 500 @ 2.0，手续费 5，回款到支付宝
    await repo.sell(
      holdingId: 1,
      shares: 500,
      nav: 2.0,
      fee: 5,
      targetAccountId: 20,
    );

    final afterSell = await (db.select(db.accounts)
          ..where((a) => a.id.equals(10)))
        .getSingle();
    expect(afterSell.initialBalance, closeTo(1000, 0.01)); // 500*2.0
    expect(await accountRepo.getAccountBalance(20),
        closeTo(4485, 0.01)); // 3490 + 995
  });

  test('余额联动：更新净值后投资账户市值同步', () async {
    await repo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000001',
      fundName: '华夏成长混合',
      amount: 1000,
      shares: 1000,
      nav: 1.0,
    );

    await repo.updateNav(1, 2.0);

    final account = await (db.select(db.accounts)
          ..where((a) => a.id.equals(10)))
        .getSingle();
    expect(account.initialBalance, closeTo(2000, 0.01));
  });

  test('余额联动：转换后双方持仓合计市值同步', () async {
    await repo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000001',
      fundName: '基金A',
      amount: 1000,
      shares: 1000,
      nav: 1.0,
    );
    await repo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000002',
      fundName: '基金B',
      amount: 500,
      shares: 500,
      nav: 1.0,
    );

    await repo.convert(
      fromHoldingId: 1,
      toHoldingId: 2,
      fromShares: 500,
      fromNav: 1.2,
      toShares: 480,
      toNav: 1.25,
      toCost: 600,
      fee: 5,
    );

    final account = await (db.select(db.accounts)
          ..where((a) => a.id.equals(10)))
        .getSingle();
    expect(account.initialBalance, closeTo(1825, 0.01)); // 500*1.2 + 980*1.25
  });

  // ---- 交易编辑重算 ----

  test('编辑交易：修改买入份额/净值/手续费后重算持仓', () async {
    final txId = await repo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000001',
      fundName: '华夏成长混合',
      amount: 1510,
      shares: 1000,
      nav: 1.5,
    );

    await repo.updateTransaction(
      txId,
      investShares: 500,
      investNav: 2.0,
      investFee: 5,
      amount: 1005,
    );

    final h = await repo.getHolding(1);
    expect(h!.totalShares, 500);
    expect(h.totalCost, closeTo(1005, 0.01)); // 500*2.0+5
    expect(h.currentNav, 2.0);
    expect(h.marketValue, closeTo(1000, 0.01));

    final account = await (db.select(db.accounts)
          ..where((a) => a.id.equals(10)))
        .getSingle();
    expect(account.initialBalance, closeTo(1000, 0.01));
  });

  test('编辑交易：买入金额即成本，仅改金额也重算成本', () async {
    final txId = await repo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000001',
      fundName: '华夏成长混合',
      amount: 1510,
      shares: 1000,
      nav: 1.5,
    );

    await repo.updateTransaction(txId, amount: 2000);

    final h = await repo.getHolding(1);
    expect(h!.totalShares, 1000);
    expect(h.totalCost, closeTo(2000, 0.01));
    expect(h.marketValue, closeTo(1500, 0.01)); // 市值仍按净值算
  });

  test('编辑交易：clearNote 清空备注，null 不更新备注', () async {
    final txId = await repo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000001',
      fundName: '华夏成长混合',
      amount: 1000,
      shares: 1000,
      nav: 1.0,
      note: '原始备注',
    );

    await repo.updateTransaction(txId, note: '新备注');
    final updated = await (db.select(db.transactions)
          ..where((t) => t.id.equals(txId)))
        .getSingle();
    expect(updated.note, '新备注');

    await repo.updateTransaction(txId, clearNote: true);
    final cleared = await (db.select(db.transactions)
          ..where((t) => t.id.equals(txId)))
        .getSingle();
    expect(cleared.note, isNull);

    final clearedRow = await db.customSelect(
        'SELECT note FROM transactions WHERE id = ?',
        variables: [Variable<int>(txId)]).getSingle();
    expect(clearedRow.readNullable<String>('note'), isNull);

    await repo.updateTransaction(txId, note: '保留我');
    final untouched = await (db.select(db.transactions)
          ..where((t) => t.id.equals(txId)))
        .getSingle();
    expect(untouched.note, '保留我');
  });

  test('买入/更新净值写入 navDate', () async {
    final navDate = DateTime(2026, 8, 7);
    final txId = await repo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000001',
      fundName: '华夏成长混合',
      amount: 1000,
      shares: 1000,
      nav: 1.0,
      navDate: navDate,
    );
    expect(txId, isPositive);

    final bought = await repo.getHolding(1);
    expect(bought!.navDate, navDate);

    final manualDate = DateTime(2026, 8, 8);
    await repo.updateNav(1, 2.0, navDate: manualDate);
    final updated = await repo.getHolding(1);
    expect(updated!.navDate, manualDate);
  });

  test('更新持仓信息：改代码/名称保留统计字段', () async {
    final navDate = DateTime(2026, 8, 7);
    await repo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000001',
      fundName: '基金A',
      amount: 1000,
      shares: 1000,
      nav: 1.0,
      navDate: navDate,
    );
    await repo.updateNav(1, 2.0, navDate: navDate);

    await repo.updateHoldingInfo(
      1,
      fundCode: '110017',
      fundName: '新名称',
    );

    final h = await repo.getHolding(1);
    expect(h!.fundCode, '110017');
    expect(h.fundName, '新名称');
    expect(h.totalShares, 1000);
    expect(h.totalCost, closeTo(1000, 0.01));
    expect(h.currentNav, 2.0);
    expect(h.navDate, navDate);
    expect(h.marketValue, closeTo(2000, 0.01));
  });

  test('更新持仓信息：非法代码拒绝', () async {
    await repo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000001',
      fundName: '基金A',
      amount: 1000,
      shares: 1000,
      nav: 1.0,
    );

    await expectLater(
      () => repo.updateHoldingInfo(1, fundCode: '11017'),
      throwsArgumentError,
    );
    final h = await repo.getHolding(1);
    expect(h!.fundCode, '000001');
  });

  test('更新持仓信息：同账户重复代码拒绝，改回自身允许', () async {
    await repo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000001',
      fundName: '基金A',
      amount: 1000,
      shares: 1000,
      nav: 1.0,
    );
    await repo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000002',
      fundName: '基金B',
      amount: 500,
      shares: 500,
      nav: 1.0,
    );

    await expectLater(
      () => repo.updateHoldingInfo(1, fundCode: '000002'),
      throwsA(isA<StateError>()),
    );
    final a = await repo.getHolding(1);
    expect(a!.fundCode, '000001');

    await repo.updateHoldingInfo(1, fundCode: '000001');
  });

  test('删除持仓：清理流水/分组关联并联动账户市值', () async {
    final buyTx = await repo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000001',
      fundName: '基金A',
      amount: 2000,
      shares: 1000,
      nav: 2.0,
    );
    await repo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000002',
      fundName: '基金B',
      amount: 1500,
      shares: 500,
      nav: 3.0,
    );
    final groupId = await repo.createGroup(ledgerId: 1, name: '组合A');
    await repo.addHoldingsToGroup(groupId, [1, 2]);
    await db.into(db.transactionAttachments).insert(
        TransactionAttachmentsCompanion.insert(
            transactionId: buyTx, fileName: 'a.jpg'));

    await repo.deleteHolding(1);

    final holdings = await db.select(db.investmentHoldings).get();
    expect(holdings.map((h) => h.fundCode).toList(), ['000002']);

    final txs = await (db.select(db.transactions)
          ..where((t) => t.holdingId.equals(1)))
        .get();
    expect(txs, isEmpty);

    final members = await (db.select(db.investmentGroupHoldings)
          ..where((r) => r.groupId.equals(groupId)))
        .get();
    expect(members.map((r) => r.holdingId).toList(), [2]);

    final attachments = await db.select(db.transactionAttachments).get();
    expect(attachments, isEmpty);

    final account = await (db.select(db.accounts)
          ..where((a) => a.id.equals(10)))
        .getSingle();
    expect(account.initialBalance, closeTo(1500, 0.01));
  });

  test('删除持仓：不存在抛错', () async {
    await expectLater(
      () => repo.deleteHolding(999),
      throwsA(isA<StateError>()),
    );
  });

  test('编辑交易：部分卖出后改买入份额按比例重算成本', () async {
    final buyTx = await repo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000001',
      fundName: '华夏成长混合',
      amount: 2000,
      shares: 1000,
      nav: 2.0,
    );
    await repo.sell(holdingId: 1, shares: 500, nav: 2.5);

    await repo.updateTransaction(
      buyTx,
      investShares: 800,
      amount: 1600,
    );

    final h = await repo.getHolding(1);
    expect(h!.totalShares, 300); // 800-500
    expect(h.totalCost, closeTo(600, 0.01)); // 1600 - 1600*500/800
    expect(h.currentNav, 2.5);
    expect(h.marketValue, closeTo(750, 0.01));
  });

  test('编辑交易：初始持仓修改后重算并联动市值', () async {
    await repo.createInitialHolding(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000001',
      fundName: '华夏成长混合',
      shares: 1000,
      cost: 2000,
      nav: 2.0,
    );

    final tx = await (db.select(db.transactions)
          ..where((t) => t.holdingId.equals(1)))
        .getSingle();
    await repo.updateTransaction(
      tx.id,
      investShares: 800,
      amount: 1600,
    );

    final h = await repo.getHolding(1);
    expect(h!.totalShares, 800);
    expect(h.totalCost, closeTo(1600, 0.01));
    expect(h.marketValue, closeTo(1600, 0.01));

    final account = await (db.select(db.accounts)
          ..where((a) => a.id.equals(10)))
        .getSingle();
    expect(account.initialBalance, closeTo(1600, 0.01));
  });

  test('初始持仓：重复登记同基金+账户时复用持仓并累加', () async {
    final firstId = await repo.createInitialHolding(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000001',
      fundName: '华夏成长混合',
      shares: 1000,
      cost: 2000,
      nav: 2.0,
    );

    final secondId = await repo.createInitialHolding(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000001',
      fundName: '华夏成长混合',
      shares: 500,
      cost: 1100,
      nav: 2.2,
    );

    // 同一持仓，不因唯一索引报错
    expect(secondId, firstId);
    final holdings = db.select(db.investmentHoldings).get();
    expect((await holdings).length, 1);
    final h = (await holdings).single;
    expect(h.totalShares, 1500);
    expect(h.totalCost, closeTo(3100, 0.01)); // 2000 + 1100
    expect(h.currentNav, 2.2);
    expect(h.marketValue, closeTo(3300, 0.01)); // 1500 * 2.2

    // 两笔初始登记都保留，且都不进流水统计
    final txs = await (db.select(db.transactions)
          ..where((t) => t.holdingId.equals(firstId)))
        .get();
    expect(txs.length, 2);
    expect(txs.every((t) => t.investType == 'initial'), isTrue);
    expect(txs.every((t) => t.excludeFromStats), isTrue);

    // 投资账户市值联动为合并后的市值
    final account = await (db.select(db.accounts)
          ..where((a) => a.id.equals(10)))
        .getSingle();
    expect(account.initialBalance, closeTo(3300, 0.01));
  });

  // ---- 卖出 ----

  test('卖出：全额卖出成本减为零', () async {
    // 买入
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '华夏成长',
        amount: 2000,
        shares: 1000,
        nav: 2.0);

    // 卖出全部
    final txId = await repo.sell(holdingId: 1, shares: 1000, nav: 2.5, fee: 5);

    final tx = await db.customSelect('SELECT * FROM transactions WHERE id = ?',
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
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '华夏成长',
        amount: 2000,
        shares: 1000,
        nav: 2.0); // 总成本 2000

    await repo.sell(holdingId: 1, shares: 500, nav: 2.5);

    final h = await repo.getHolding(1);
    expect(h!.totalShares, 500);
    expect(h.totalCost, closeTo(1000, 0.01)); // 2000 * 500/1000
  });

  test('卖出：份额不足应抛异常', () async {
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '华夏成长',
        amount: 100,
        shares: 100,
        nav: 1.0);

    await expectLater(
      () => repo.sell(holdingId: 1, shares: 200, nav: 1.0),
      throwsA(isA<StateError>()),
    );
  });

  // ---- 转换 ----

  test('转换：A→B 两笔交易共享 batchId', () async {
    // 买入 A
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 1000,
        shares: 1000,
        nav: 1.0);
    // 买入 B（初始买入，以便转换时有现有持仓）
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000002',
        fundName: '基金B',
        amount: 500,
        shares: 500,
        nav: 1.0);

    await repo.convert(
      fromHoldingId: 1,
      toHoldingId: 2,
      fromShares: 500,
      fromNav: 1.2,
      toShares: 480,
      toNav: 1.25,
      toCost: 600,
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

  test('转换：确认数据记账 + 退回金额/账户', () async {
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
    final accountRepo = LocalAccountRepository(db);

    await repo.convert(
      fromHoldingId: 1,
      toHoldingId: 2,
      fromShares: 500,
      fromNav: 1.2,
      toShares: 480,
      toNav: 1.25,
      toCost: 600,
      fee: 5,
      refundAmount: 100,
      refundAccountId: 20,
    );

    final txs = await db.select(db.transactions).get();
    final batchTxs = txs.where((t) => t.batchId != null).toList();
    expect(batchTxs.length, 3); // 卖出 + 买入 + 退回共享 batchId

    final sell = batchTxs.singleWhere((t) => t.investType == 'sell');
    expect(sell.amount, 0); // 投资账户内部记账，不产生资金流水
    expect(sell.excludeFromStats, isTrue); // 7.5.5: 内部卖出不进明细/统计
    final buy = batchTxs.singleWhere((t) => t.investType == 'buy');
    expect(buy.amount, 600); // 7.5.4: 买入侧 amount = 转入成本
    expect(buy.excludeFromStats, isTrue); // 7.5.5: 内部买入不进明细/统计

    final refunds = txs.where((t) => t.note == '基金转换退回').toList();
    expect(refunds.length, 1);
    final refund = refunds.single;
    expect(refund.investType, isNull);
    expect(refund.holdingId, isNull);
    expect(refund.batchId, sell.batchId); // 7.5.4: 退回属于同一批次
    expect(refund.accountId, 10);
    expect(refund.toAccountId, 20);
    expect(refund.amount, 100.0);
    expect(refund.excludeFromStats, isFalse); // 7.5.5: 退回是真实资金流水

    final from = await repo.getHolding(1);
    expect(from!.totalShares, 500);
    expect(from.totalCost, closeTo(500, 0.01));
    expect(from.marketValue, closeTo(600, 0.01));

    final to = await repo.getHolding(2);
    expect(to!.totalShares, 980);
    expect(to.totalCost, closeTo(1100, 0.01)); // 500 + 480*1.25
    expect(to.marketValue, closeTo(1225, 0.01));

    final investment = await (db.select(db.accounts)
          ..where((a) => a.id.equals(10)))
        .getSingle();
    expect(investment.initialBalance, closeTo(1825, 0.01));

    expect(await accountRepo.getAccountBalance(20), closeTo(5100, 0.01));
  });

  test('转换内部卖出/买入不进明细，退回保留', () async {
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

    await repo.convert(
      fromHoldingId: 1,
      toHoldingId: 2,
      fromShares: 500,
      fromNav: 1.2,
      toShares: 480,
      toNav: 1.25,
      toCost: 600,
      fee: 5,
      refundAmount: 100,
      refundAccountId: 20,
    );

    final detail = await LocalTransactionRepository(db)
        .watchTransactionsWithCategoryAll(ledgerId: 1)
        .first;
    final detailIds = detail.map((r) => r.t.id).toSet();

    final all = await db.select(db.transactions).get();
    final internal = all
        .where((t) =>
            t.batchId != null &&
            (t.investType == 'sell' || t.investType == 'buy'))
        .toList();
    expect(internal, isNotEmpty);
    for (final tx in internal) {
      expect(detailIds, isNot(contains(tx.id)));
    }

    final refund = all.singleWhere((t) => t.note == '基金转换退回');
    expect(detailIds, contains(refund.id));
  });

  test('转换：refund=0 不生成退回记录', () async {
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

    await repo.convert(
      fromHoldingId: 1,
      toHoldingId: 2,
      fromShares: 500,
      fromNav: 1.2,
      toShares: 480,
      toNav: 1.25,
      toCost: 600,
      refundAmount: 0,
    );

    final txs = await db.select(db.transactions).get();
    expect(txs.where((t) => t.note == '基金转换退回'), isEmpty);
  });

  test('转换：refund<0 / refund>0 缺账户抛错', () async {
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

    await expectLater(
      () => repo.convert(
        fromHoldingId: 1,
        toHoldingId: 2,
        fromShares: 500,
        fromNav: 1.2,
        toShares: 480,
        toNav: 1.25,
        toCost: 600,
        refundAmount: -1,
        refundAccountId: 20,
      ),
      throwsArgumentError,
    );
    await expectLater(
      () => repo.convert(
        fromHoldingId: 1,
        toHoldingId: 2,
        fromShares: 500,
        fromNav: 1.2,
        toShares: 480,
        toNav: 1.25,
        toCost: 600,
        refundAmount: 1,
      ),
      throwsArgumentError,
    );
  });

  test('转换：toHoldingId 为空时创建新目标持仓并记账', () async {
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 1000,
        shares: 1000,
        nav: 1.0);

    await repo.convert(
      fromHoldingId: 1,
      toHoldingId: null,
      fundCode: '000009',
      fundName: '新基金',
      fromShares: 500,
      fromNav: 1.2,
      toShares: 480,
      toNav: 1.25,
      toCost: 600,
      fee: 5,
    );

    final holdings = await db.select(db.investmentHoldings).get();
    expect(holdings.length, 2);
    final target = holdings.firstWhere((h) => h.fundCode == '000009');
    expect(target.accountId, 10);
    expect(target.totalShares, 480);
    expect(target.totalCost, closeTo(600, 0.01)); // 480*1.25
    expect(target.currentNav, 1.25);
    expect(target.marketValue, closeTo(600, 0.01));

    final txs = await db.select(db.transactions).get();
    final sellTx =
        txs.singleWhere((t) => t.investType == 'sell' && t.batchId != null);
    final buyTx =
        txs.singleWhere((t) => t.investType == 'buy' && t.batchId != null);
    expect(sellTx.amount, 0);
    expect(buyTx.amount, 600); // 7.5.4: 买入侧 amount = 转入成本
    expect(buyTx.holdingId, target.id);
    expect(sellTx.batchId, buyTx.batchId);
  });

  test('转换：手填代码命中已有持仓时复用', () async {
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
    final existingB = await (db.select(db.investmentHoldings)
          ..where((h) => h.fundCode.equals('000002')))
        .getSingle();

    await repo.convert(
      fromHoldingId: 1,
      toHoldingId: null,
      fundCode: '000002',
      fundName: '基金B',
      fromShares: 500,
      fromNav: 1.2,
      toShares: 480,
      toNav: 1.25,
      toCost: 600,
    );

    final holdings = await db.select(db.investmentHoldings).get();
    expect(holdings.length, 2); // 不新建持仓
    final target = await repo.getHolding(existingB.id);
    expect(target!.totalShares, 980);
    expect(target.totalCost, closeTo(1100, 0.01));
  });

  test('转换：toHoldingId 为空且代码/名称为空抛错', () async {
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 1000,
        shares: 1000,
        nav: 1.0);

    await expectLater(
      () => repo.convert(
        fromHoldingId: 1,
        toHoldingId: null,
        fundCode: '',
        fundName: '新基金',
        fromShares: 500,
        fromNav: 1.2,
        toShares: 480,
        toNav: 1.25,
        toCost: 600,
      ),
      throwsArgumentError,
    );
    await expectLater(
      () => repo.convert(
        fromHoldingId: 1,
        toHoldingId: null,
        fundCode: '000009',
        fundName: '   ',
        fromShares: 500,
        fromNav: 1.2,
        toShares: 480,
        toNav: 1.25,
        toCost: 600,
      ),
      throwsArgumentError,
    );
  });

  test('转换：B 成本以转入成本为准，市值按份额×净值', () async {
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

    await repo.convert(
      fromHoldingId: 1,
      toHoldingId: 2,
      fromShares: 500,
      fromNav: 1.2,
      toShares: 480,
      toNav: 1.25,
      toCost: 580, // 实际确认成本，与 480×1.25=600 不同
      fee: 5,
    );

    final to = await repo.getHolding(2);
    expect(to!.totalCost, closeTo(1080, 0.01)); // 500 + 580
    expect(to.marketValue, closeTo(1225, 0.01)); // 980 × 1.25

    final txs = await db.select(db.transactions).get();
    final buyTx =
        txs.singleWhere((t) => t.investType == 'buy' && t.batchId != null);
    expect(buyTx.amount, 580);
    expect(buyTx.investFee, isNull); // 手续费只记转出侧
  });

  test('updateConversion：整批更新 A/B/退回并重算双方持仓', () async {
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 1000,
        shares: 1000,
        nav: 1.0,
        happenedAt: DateTime(2026, 8, 1));
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000002',
        fundName: '基金B',
        amount: 500,
        shares: 500,
        nav: 1.0,
        happenedAt: DateTime(2026, 8, 1));

    await repo.convert(
      fromHoldingId: 1,
      toHoldingId: 2,
      fromShares: 500,
      fromNav: 1.2,
      toShares: 480,
      toNav: 1.25,
      toCost: 600,
      fee: 5,
      refundAmount: 100,
      refundAccountId: 20,
      happenedAt: DateTime(2026, 8, 2),
    );
    final batchId = (await db.select(db.transactions).get())
        .firstWhere((t) => t.investType == 'buy' && t.batchId != null)
        .batchId!;

    final newDate = DateTime(2026, 8, 3, 9, 30);
    await repo.updateConversion(
      batchId,
      fromShares: 400,
      fromNav: 1.1,
      toShares: 420,
      toNav: 1.2,
      toCost: 500,
      fee: 8,
      refundAmount: 120,
      refundAccountId: 20,
      happenedAt: newDate,
      note: '改后备注',
    );

    final from = await repo.getHolding(1);
    expect(from!.totalShares, closeTo(600, 0.01)); // 1000 - 400
    expect(from.totalCost, closeTo(600, 0.01)); // 1000 × 400/1000
    expect(from.currentNav, 1.1);
    expect(from.marketValue, closeTo(660, 0.01));

    final to = await repo.getHolding(2);
    expect(to!.totalShares, closeTo(920, 0.01)); // 500 + 420
    expect(to.totalCost, closeTo(1000, 0.01)); // 500 + 500
    expect(to.currentNav, 1.2);
    expect(to.marketValue, closeTo(1104, 0.01));

    final txs = await db.select(db.transactions).get();
    final sell = txs.singleWhere((t) => t.investType == 'sell');
    expect(sell.investShares, -400);
    expect(sell.investNav, 1.1);
    expect(sell.investFee, 8);
    expect(sell.amount, 0);
    expect(sell.happenedAt, newDate);
    expect(sell.note, '改后备注');

    final buy =
        txs.singleWhere((t) => t.investType == 'buy' && t.batchId != null);
    expect(buy.investShares, 420);
    expect(buy.investNav, 1.2);
    expect(buy.amount, 500);
    expect(buy.investFee, isNull);

    final refund = txs.singleWhere((t) => t.note == '基金转换退回');
    expect(refund.amount, 120);
    expect(refund.toAccountId, 20);
    expect(refund.batchId, batchId);
  });

  test('deleteConversion：删除整批（含退回）并重算双方持仓', () async {
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

    await repo.convert(
      fromHoldingId: 1,
      toHoldingId: 2,
      fromShares: 500,
      fromNav: 1.2,
      toShares: 480,
      toNav: 1.25,
      toCost: 600,
      fee: 5,
      refundAmount: 100,
      refundAccountId: 20,
    );
    final batchId = (await db.select(db.transactions).get())
        .firstWhere((t) => t.investType == 'buy' && t.batchId != null)
        .batchId!;

    await repo.deleteConversion(batchId);

    final remaining = await db.select(db.transactions).get();
    expect(remaining.where((t) => t.batchId == batchId), isEmpty);
    expect(remaining.where((t) => t.note == '基金转换退回'), isEmpty);

    final from = await repo.getHolding(1);
    expect(from!.totalShares, 1000);
    expect(from.totalCost, closeTo(1000, 0.01));
    final to = await repo.getHolding(2);
    expect(to!.totalShares, 500);
    expect(to.totalCost, closeTo(500, 0.01));

    final account = await (db.select(db.accounts)
          ..where((a) => a.id.equals(10)))
        .getSingle();
    expect(account.initialBalance, closeTo(1500, 0.01));
  });

  test('转换旧记录兼容：买入侧 amount=0 时成本回退份额×净值', () async {
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

    await repo.convert(
      fromHoldingId: 1,
      toHoldingId: 2,
      fromShares: 500,
      fromNav: 1.2,
      toShares: 480,
      toNav: 1.25,
      toCost: 600,
      fee: 5,
    );
    final buyTxId = (await db.select(db.transactions).get())
        .firstWhere((t) => t.investType == 'buy' && t.batchId != null)
        .id;

    // 模拟 7.5.4 之前的旧数据：买入侧 amount 未写转入成本。
    await repo.updateTransaction(buyTxId, amount: 0);
    await repo.recomputeHolding(2);

    final to = await repo.getHolding(2);
    expect(to!.totalCost, closeTo(1100, 0.01)); // 500 + 480 × 1.25
    expect(to.marketValue, closeTo(1225, 0.01));
  });

  // ---- 7.6.1 删除转换后清理空持仓 ----

  test('deleteConversion：纯转换新建的 B 空持仓被清理', () async {
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 1000,
        shares: 1000,
        nav: 1.0);

    await repo.convert(
      fromHoldingId: 1,
      toHoldingId: null,
      fundCode: '000009',
      fundName: '新基金',
      fromShares: 500,
      fromNav: 1.2,
      toShares: 480,
      toNav: 1.25,
      toCost: 600,
      fee: 5,
    );
    final batchId = (await db.select(db.transactions).get())
        .firstWhere((t) => t.investType == 'buy' && t.batchId != null)
        .batchId!;

    final before = await db.select(db.investmentHoldings).get();
    expect(before.any((h) => h.fundCode == '000009'), isTrue);

    await repo.deleteConversion(batchId);

    final after = await db.select(db.investmentHoldings).get();
    expect(after.any((h) => h.fundCode == '000009'), isFalse);
    final from = await repo.getHolding(1);
    expect(from!.totalShares, 1000);
    expect(from.totalCost, closeTo(1000, 0.01));

    final account = await (db.select(db.accounts)
          ..where((a) => a.id.equals(10)))
        .getSingle();
    expect(account.initialBalance, closeTo(1000, 0.01));
  });

  // ---- 7.6.2 通用更新投资流水兜底重算 ----

  test('通用 updateTransaction 改备注/加标签不改变持仓', () async {
    final txId = await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 1000,
        shares: 1000,
        nav: 1.0);
    final before = await repo.getHolding(1);

    await LocalTransactionRepository(db).updateTransaction(
      id: txId,
      type: 'transfer',
      amount: 1000,
      categoryId: null,
      note: '新备注',
      happenedAt: DateTime(2026, 8, 1, 10, 0),
      accountId: 10,
      excludeFromStats: false,
      excludeFromBudget: true,
      currencyCode: null,
      nativeAmount: null,
    );
    final tagId = await LocalRepository(db).createTag(name: '测试');
    await LocalRepository(db).updateTransactionTags(
      transactionId: txId,
      tagIds: [tagId],
    );

    final after = await repo.getHolding(1);
    expect(after!.totalShares, before!.totalShares);
    expect(after.totalCost, closeTo(before.totalCost, 0.01));
    expect(after.marketValue, closeTo(before.marketValue, 0.01));

    final tags = await LocalRepository(db).getTagsForTransaction(txId);
    expect(tags.single.name, '测试');
  });

  test('通用 updateTransaction 直接改金额时持仓成本同步重算', () async {
    final txId = await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 1000,
        shares: 1000,
        nav: 1.0);

    await LocalTransactionRepository(db).updateTransaction(
      id: txId,
      type: 'transfer',
      amount: 1500,
      categoryId: null,
      note: null,
      happenedAt: DateTime(2026, 8, 1, 10, 0),
      accountId: 10,
      excludeFromStats: false,
      excludeFromBudget: true,
      currencyCode: null,
      nativeAmount: null,
    );

    final h = await repo.getHolding(1);
    expect(h!.totalCost, closeTo(1500, 0.01));
    expect(h.marketValue, closeTo(1000, 0.01)); // 份额 × 净值不变
  });

  // ---- 净值更新 ----

  test('更新净值：NAV 和市值联动更新', () async {
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '华夏成长',
        amount: 1000,
        shares: 1000,
        nav: 1.0);

    await repo.updateNav(1, 1.5);

    final h = await repo.getHolding(1);
    expect(h!.currentNav, 1.5);
    expect(h.marketValue, 1500.0); // 1000*1.5
  });

  // ---- 查询 ----

  test('watchHoldings：过滤份额为 0 的持仓', () async {
    // 买入并全卖
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '华夏成长',
        amount: 1000,
        shares: 1000,
        nav: 1.0);
    await repo.sell(holdingId: 1, shares: 1000, nav: 1.0);

    // 再买另一支
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000002',
        fundName: '基金B',
        amount: 500,
        shares: 500,
        nav: 1.0);

    final holdings = await repo.watchHoldings(ledgerId: 1).first;
    expect(holdings.length, 1);
    expect(holdings.single.fundCode, '000002');
  });
}
