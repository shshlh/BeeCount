// `TransactionRepository.getRecentTransactions` 契约测试。
//
// 供桌面小组件「最近交易」类型取数用(.docs/home-widget/plan.md §一.3):
// 按 happenedAt 降序取前 limit 笔、按 ledgerId 隔离、过滤 excludeFromStats
// (不计收支的登记类流水不进入用户可见列表)。

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/data/repositories/local/local_transaction_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late LocalRepository repo;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
  });

  tearDown(() async => db.close());

  test('按 happenedAt 降序返回,且遵守 limit', () async {
    await repo.addTransaction(
        ledgerId: 1, type: 'expense', amount: 10, happenedAt: DateTime(2026, 7, 1));
    await repo.addTransaction(
        ledgerId: 1, type: 'expense', amount: 20, happenedAt: DateTime(2026, 7, 3));
    await repo.addTransaction(
        ledgerId: 1, type: 'expense', amount: 30, happenedAt: DateTime(2026, 7, 2));

    final result = await repo.getRecentTransactions(1, limit: 2);

    expect(result.length, 2);
    expect(result[0].amount, 20); // 7-3 最新
    expect(result[1].amount, 30); // 7-2 次新;7-1 那笔被 limit 截掉
  });

  test('按 ledgerId 隔离,不泄漏其它账本的交易', () async {
    await repo.addTransaction(
        ledgerId: 1, type: 'expense', amount: 10, happenedAt: DateTime(2026, 7, 1));
    await repo.addTransaction(
        ledgerId: 2, type: 'expense', amount: 999, happenedAt: DateTime(2026, 7, 5));

    final result = await repo.getRecentTransactions(1, limit: 10);

    expect(result.length, 1);
    expect(result.single.amount, 10);
  });

  test('过滤 excludeFromStats,但保留 excludeFromBudget 与转账', () async {
    final accA = await repo.createAccount(ledgerId: 1, name: 'A');
    final accB = await repo.createAccount(ledgerId: 1, name: 'B');
    await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 10,
        happenedAt: DateTime(2026, 7, 1),
        excludeFromStats: true);
    await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 20,
        happenedAt: DateTime(2026, 7, 2),
        excludeFromBudget: true);
    await repo.addTransaction(
        ledgerId: 1,
        type: 'transfer',
        amount: 30,
        accountId: accA,
        toAccountId: accB,
        happenedAt: DateTime(2026, 7, 3));

    final result = await repo.getRecentTransactions(1, limit: 10);

    expect(result.length, 2);
    expect(result.map((t) => t.type).toSet(), {'expense', 'transfer'});
    expect(result.any((t) => t.excludeFromStats), isFalse);
  });

  test('空账本返回空列表', () async {
    final result = await repo.getRecentTransactions(999, limit: 10);
    expect(result, isEmpty);
  });

  test('主流水 feed 过滤 excludeFromStats 的登记类交易', () async {
    final txRepo = LocalTransactionRepository(db);
    final accA = await repo.createAccount(ledgerId: 1, name: 'A');
    await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 10,
        happenedAt: DateTime(2026, 7, 1),
        excludeFromStats: true);
    await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 20,
        happenedAt: DateTime(2026, 7, 2));
    await repo.addTransaction(
        ledgerId: 1,
        type: 'transfer',
        amount: 30,
        accountId: accA,
        toAccountId: accA,
        happenedAt: DateTime(2026, 7, 3));

    final allFeed = await txRepo
        .transactionsWithCategoryAll(ledgerId: 1)
        .first;
    expect(allFeed.map((e) => e.t.amount), [30, 20]);
    expect(allFeed.any((e) => e.t.excludeFromStats), isFalse);

    final recentFeed = await txRepo.getRecentTransactionsWithCategory(
        ledgerId: 1, limit: 10);
    expect(recentFeed.map((e) => e.t.amount), [30, 20]);
    expect(recentFeed.any((e) => e.t.excludeFromStats), isFalse);

    final byLedger = await txRepo.getTransactionsByLedger(1);
    expect(byLedger.map((t) => t.amount), [30, 20]);
    expect(byLedger.any((t) => t.excludeFromStats), isFalse);
  });
}
