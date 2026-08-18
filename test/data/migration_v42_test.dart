// v42 迁移（7.19.4.1）：投资持仓新增 is_qdii 标签。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_investment_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late LocalInvestmentRepository repo;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalInvestmentRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, type, currency) "
        "VALUES (10, 1, '投资账户', 'investment', 'CNY')");
  });

  tearDown(() async => db.close());

  test('schemaVersion = 42', () {
    expect(db.schemaVersion, 42);
  });

  test('investment_holdings 含 is_qdii 列且默认 false', () async {
    final cols = await db
        .customSelect('PRAGMA table_info(investment_holdings)')
        .get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(names, contains('is_qdii'));

    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 100,
        shares: 100,
        nav: 1.0);
    final holding = await repo.getHolding(1);
    expect(holding!.isQdii, isFalse);
  });

  test('buy 可写入 QDII 标签', () async {
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: 'QDII 基金',
        amount: 100,
        shares: 100,
        nav: 1.0,
        isQdii: true);
    final holding = await repo.getHolding(1);
    expect(holding!.isQdii, isTrue);
  });
}
