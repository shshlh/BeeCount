import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_investment_repository.dart';
import 'package:beecount/data/repositories/local/local_transaction_repository.dart';

void main() {
  late BeeDatabase db;
  late LocalInvestmentRepository investmentRepo;
  late LocalTransactionRepository transactionRepo;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    investmentRepo = LocalInvestmentRepository(db);
    transactionRepo = LocalTransactionRepository(db);

    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, type, currency) "
        "VALUES (10, 1, '投资账户', 'investment', 'CNY')");
  });

  tearDown(() async => db.close());

  Future<double> accountValue() async {
    final row = await (db.select(db.accounts)..where((a) => a.id.equals(10)))
        .getSingle();
    return row.initialBalance;
  }

  test('删除买入交易后重算持仓与账户市值', () async {
    final buyTx = await investmentRepo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000001',
      fundName: '基金A',
      amount: 2000,
      shares: 1000,
      nav: 2.0,
    );
    expect((await investmentRepo.getHolding(1))!.totalShares, 1000);
    expect(await accountValue(), closeTo(2000, 0.01));

    await transactionRepo.deleteTransaction(buyTx);

    final after = await investmentRepo.getHolding(1);
    expect(after!.totalShares, 0);
    expect(after.totalCost, 0);
    expect(after.marketValue, 0);
    expect(await accountValue(), 0);
  });

  test('删除卖出交易后恢复买入状态', () async {
    await investmentRepo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000001',
      fundName: '基金A',
      amount: 2000,
      shares: 1000,
      nav: 2.0,
    );
    final sellTx = await investmentRepo.sell(
      holdingId: 1,
      shares: 500,
      nav: 2.5,
    );

    final before = await investmentRepo.getHolding(1);
    expect(before!.totalShares, 500);
    expect(before.totalCost, closeTo(1000, 0.01));
    expect(before.marketValue, closeTo(1250, 0.01));
    expect(await accountValue(), closeTo(1250, 0.01));

    await transactionRepo.deleteTransaction(sellTx);

    final after = await investmentRepo.getHolding(1);
    expect(after!.totalShares, 1000);
    expect(after.totalCost, closeTo(2000, 0.01));
    // 删除路径保留删除前 currentNav（2.5），不再回退到剩余流水的净值
    expect(after.currentNav, 2.5);
    expect(after.marketValue, closeTo(2500, 0.01));
    expect(await accountValue(), closeTo(2500, 0.01));
  });

  test('删除旧流水保留手动 updateNav 的净值', () async {
    await investmentRepo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000001',
      fundName: '基金A',
      amount: 2000,
      shares: 1000,
      nav: 2.0,
    );
    final secondBuyTx = await investmentRepo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000001',
      fundName: '基金A',
      amount: 750,
      shares: 500,
      nav: 1.5,
    );
    final manualNavDate = DateTime(2026, 8, 7);
    await investmentRepo.updateNav(1, 3.0, navDate: manualNavDate);

    await transactionRepo.deleteTransaction(secondBuyTx);

    final after = await investmentRepo.getHolding(1);
    expect(after!.totalShares, 1000);
    expect(after.totalCost, closeTo(2000, 0.01));
    expect(after.currentNav, 3.0); // 保留手动净值，不被剩余流水净值覆盖
    expect(after.navDate, manualNavDate);
    expect(after.marketValue, closeTo(3000, 0.01));
    expect(await accountValue(), closeTo(3000, 0.01));
  });

  test('批量删除投资流水后重算全部受影响持仓', () async {
    final tx1 = await investmentRepo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000001',
      fundName: '基金A',
      amount: 1000,
      shares: 1000,
      nav: 1.0,
    );
    final tx2 = await investmentRepo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000002',
      fundName: '基金B',
      amount: 2000,
      shares: 2000,
      nav: 1.0,
    );

    final rows = await (db.select(db.transactions)
          ..where((t) => t.id.isIn([tx1, tx2])))
        .get();
    final syncIds = rows.map((t) => t.syncId!).toList();

    final deleted =
        await transactionRepo.deleteTransactionsBatchBySyncIds(syncIds);
    expect(deleted, 2);

    final h1 = await investmentRepo.getHolding(1);
    final h2 = await investmentRepo.getHolding(2);
    expect(h1!.totalShares, 0);
    expect(h2!.totalShares, 0);
    expect(await accountValue(), 0);
  });
}
