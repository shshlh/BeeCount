// 7.10.1 账户强绑定账本：初始化/清空/删除账本均级联删除账户与投资数据，
// 保留账本、分类与标签结构。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_investment_repository.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late LocalRepository repo;
  late LocalInvestmentRepository investmentRepo;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    investmentRepo = LocalInvestmentRepository(db);
  });

  tearDown(() async => db.close());

  test('初始化账本后流水/持仓/分组/账户为空，分类/标签/账本保留', () async {
    final ledgerId = await repo.createLedger(name: 'L', currency: 'CNY');
    final cashId = await repo.createAccount(
      ledgerId: ledgerId,
      name: '现金',
      type: 'cash',
      currency: 'CNY',
    );
    await repo.createCategory(name: '食', kind: 'expense');
    final tagId = await repo.createTag(name: '标签A');

    final txId = await repo.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 30,
      accountId: cashId,
      happenedAt: DateTime(2026, 8, 1),
      note: '支出',
    );
    await repo.updateTransactionTags(transactionId: txId, tagIds: [tagId]);

    await investmentRepo.buy(
      ledgerId: ledgerId,
      accountId: cashId,
      sourceAccountId: cashId,
      fundCode: '000001',
      fundName: '基金A',
      amount: 1000,
      shares: 1000,
      nav: 1.0,
    );
    final groupId =
        await investmentRepo.createGroup(ledgerId: ledgerId, name: '核心');
    await investmentRepo.addHoldingsToGroup(groupId, [1]);

    await repo.resetLedger(ledgerId);

    expect(await (db.select(db.transactions)).get(), isEmpty);
    expect(await (db.select(db.transactionTags)).get(), isEmpty);
    expect(await (db.select(db.investmentHoldings)).get(), isEmpty);
    expect(await (db.select(db.investmentGroups)).get(), isEmpty);
    expect(await (db.select(db.investmentGroupHoldings)).get(), isEmpty);

    expect(await (db.select(db.ledgers)).get(), isNotEmpty);
    expect(await (db.select(db.accounts)).get(), isEmpty);
    expect(await (db.select(db.categories)).get(), isNotEmpty);
    expect(await (db.select(db.tags)).get(), isNotEmpty);
  });

  test('清空账本后该账本账户级联删除（7.10.1）', () async {
    final ledgerId = await repo.createLedger(name: 'L', currency: 'CNY');
    await repo.createAccount(
      ledgerId: ledgerId,
      name: '现金',
      type: 'cash',
      currency: 'CNY',
    );

    await repo.clearLedgerTransactions(ledgerId);

    expect(await (db.select(db.accounts)).get(), isEmpty);
    expect(await (db.select(db.ledgers)).get(), isNotEmpty);
  });

  test('清空账本后投资持仓/分组/归属与账户全部为空（7.10.1 返工）', () async {
    final ledgerId = await repo.createLedger(name: 'L', currency: 'CNY');
    final cashId = await repo.createAccount(
      ledgerId: ledgerId,
      name: '现金',
      type: 'cash',
      currency: 'CNY',
    );
    await investmentRepo.buy(
      ledgerId: ledgerId,
      accountId: cashId,
      sourceAccountId: cashId,
      fundCode: '000001',
      fundName: '基金A',
      amount: 1000,
      shares: 1000,
      nav: 1.0,
    );
    final groupId =
        await investmentRepo.createGroup(ledgerId: ledgerId, name: '核心');
    await investmentRepo.addHoldingsToGroup(groupId, [1]);

    await repo.clearLedgerTransactions(ledgerId);

    expect(await (db.select(db.transactions)).get(), isEmpty);
    expect(await (db.select(db.investmentHoldings)).get(), isEmpty);
    expect(await (db.select(db.investmentGroups)).get(), isEmpty);
    expect(await (db.select(db.investmentGroupHoldings)).get(), isEmpty);
    expect(await (db.select(db.accounts)).get(), isEmpty);
    expect(await (db.select(db.ledgers)).get(), isNotEmpty);
  });

  test('删除账本后账户/投资持仓/分组一并清理（7.10.1）', () async {
    final ledgerId = await repo.createLedger(name: 'L', currency: 'CNY');
    final cashId = await repo.createAccount(
      ledgerId: ledgerId,
      name: '现金',
      type: 'cash',
      currency: 'CNY',
    );
    await investmentRepo.buy(
      ledgerId: ledgerId,
      accountId: cashId,
      sourceAccountId: cashId,
      fundCode: '000001',
      fundName: '基金A',
      amount: 1000,
      shares: 1000,
      nav: 1.0,
    );
    final groupId =
        await investmentRepo.createGroup(ledgerId: ledgerId, name: '核心');
    await investmentRepo.addHoldingsToGroup(groupId, [1]);

    await repo.deleteLedger(ledgerId);

    expect(await (db.select(db.ledgers)).get(), isEmpty);
    expect(await (db.select(db.accounts)).get(), isEmpty);
    expect(await (db.select(db.transactions)).get(), isEmpty);
    expect(await (db.select(db.investmentHoldings)).get(), isEmpty);
    expect(await (db.select(db.investmentGroups)).get(), isEmpty);
    expect(await (db.select(db.investmentGroupHoldings)).get(), isEmpty);
  });
}
