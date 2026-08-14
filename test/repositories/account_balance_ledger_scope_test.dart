// 7.11.4-1 账本维度余额口径：getAllAccountBalances 只统计当前账本流水，
// 且包含账户初始资金与估值账户缓存市值。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late LocalRepository repo;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
  });

  tearDown(() async => db.close());

  test('getAllAccountBalances 只统计当前账本流水且含初始资金', () async {
    final ledger1 = await repo.createLedger(name: 'L1', currency: 'CNY');
    final ledger2 = await repo.createLedger(name: 'L2', currency: 'CNY');
    final accountId = await repo.createAccount(
      ledgerId: ledger1,
      name: '现金',
      type: 'cash',
      currency: 'CNY',
      initialBalance: 1000,
    );
    await repo.addTransaction(
      ledgerId: ledger1,
      type: 'expense',
      amount: 100,
      accountId: accountId,
      happenedAt: DateTime(2026, 8, 1),
      note: 'L1 支出',
    );
    // legacy 场景：账户被另一个账本的流水引用，不应计入 L1 余额。
    await repo.addTransaction(
      ledgerId: ledger2,
      type: 'expense',
      amount: 30,
      accountId: accountId,
      happenedAt: DateTime(2026, 8, 2),
      note: 'L2 支出',
    );

    final balances = await repo.getAllAccountBalances(ledger1);
    expect(balances[accountId], 900); // 1000 初始 - 100 L1 支出
    expect(await repo.getAccountBalance(accountId), 870); // 全局口径仍含 L2
  });

  test('估值/投资账户按缓存市值计入账本余额', () async {
    final ledgerId = await repo.createLedger(name: 'L', currency: 'CNY');
    final investmentId = await repo.createAccount(
      ledgerId: ledgerId,
      name: '投资账户',
      type: 'investment',
      currency: 'CNY',
      initialBalance: 5000,
    );

    final balances = await repo.getAllAccountBalances(ledgerId);
    expect(balances[investmentId], 5000);
  });

  test('净资产按账本隔离，删除账本后清零（7.12.1）', () async {
    final ledger1 = await repo.createLedger(name: 'L1', currency: 'CNY');
    final ledger2 = await repo.createLedger(name: 'L2', currency: 'CNY');
    final cash1 = await repo.createAccount(
      ledgerId: ledger1,
      name: '现金1',
      type: 'cash',
      currency: 'CNY',
      initialBalance: 1000,
    );
    final cash2 = await repo.createAccount(
      ledgerId: ledger2,
      name: '现金2',
      type: 'cash',
      currency: 'CNY',
      initialBalance: 500,
    );
    await repo.addTransaction(
      ledgerId: ledger1,
      type: 'expense',
      amount: 100,
      accountId: cash1,
      happenedAt: DateTime(2026, 8, 1),
    );

    final nw1 = await repo.getNetWorthBreakdownByLedger(ledger1);
    final nw2 = await repo.getNetWorthBreakdownByLedger(ledger2);
    expect(nw1.netWorth, 900);
    expect(nw2.netWorth, 500);

    await repo.deleteLedger(ledger1);

    final after = await repo.getNetWorthBreakdownByLedger(ledger1);
    expect(after.totalAssets, 0);
    expect(after.totalLiabilities, 0);
    expect(after.netWorth, 0);
    expect((await repo.getAllAccounts()).map((a) => a.id), contains(cash2));
  });
}
