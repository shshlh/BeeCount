// v37 迁移（投资持仓净值日期，6.12.1）：investment_holdings 新增 nullable nav_date。
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:beecount/data/db.dart';

void main() {
  late BeeDatabase db;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  test('v37 schema: investment_holdings 含 nav_date 且默认 NULL', () async {
    final cols =
        await db.customSelect('PRAGMA table_info(investment_holdings)').get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(names, contains('nav_date'));

    await db.customStatement("INSERT INTO ledgers (id, name) VALUES (1, 'L')");
    await db.customStatement("INSERT INTO investment_holdings "
        "(id, ledger_id, fund_code, fund_name, account_id) "
        "VALUES (1, 1, '000001', 'A', 10)");
    final row = await db
        .customSelect('SELECT nav_date FROM investment_holdings WHERE id = 1')
        .getSingle();
    expect(row.readNullable<int>('nav_date'), isNull);
  });

  test('v37 schema: nav_date 可写入并读回', () async {
    await db.customStatement("INSERT INTO ledgers (id, name) VALUES (1, 'L')");
    await db.customStatement("INSERT INTO investment_holdings "
        "(id, ledger_id, fund_code, fund_name, account_id, nav_date) "
        "VALUES (1, 1, '000001', 'A', 10, 1786032000)");
    final row = await db
        .customSelect('SELECT nav_date FROM investment_holdings WHERE id = 1')
        .getSingle();
    expect(row.readNullable<int>('nav_date'), 1786032000);
  });

  test('schemaVersion = 39', () {
    expect(db.schemaVersion, 39);
  });
}
