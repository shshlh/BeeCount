// v36 迁移（基金分组，6.2.2）：新增 investment_groups 与
// investment_group_holdings，后者复合主键 + 外键级联删除。
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:beecount/data/db.dart';

void main() {
  late BeeDatabase db;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  test('v36 schema: investment_groups 含全部列', () async {
    final cols =
        await db.customSelect('PRAGMA table_info(investment_groups)').get();
    final names = cols.map((r) => r.read<String>('name')).toSet();

    expect(
        names,
        containsAll([
          'id',
          'ledger_id',
          'name',
          'sort_order',
          'created_at',
        ]));
  });

  test('v36 schema: investment_group_holdings 复合主键生效', () async {
    final cols = await db
        .customSelect('PRAGMA table_info(investment_group_holdings)')
        .get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(names, containsAll(['group_id', 'holding_id']));

    await db.customStatement("INSERT INTO ledgers (id, name) VALUES (1, 'L')");
    await db.customStatement("INSERT INTO investment_holdings "
        "(id, ledger_id, fund_code, fund_name, account_id) "
        "VALUES (10, 1, '000001', '基金A', 20)");
    await db
        .customStatement("INSERT INTO investment_groups (id, ledger_id, name) "
            "VALUES (30, 1, '组合A')");
    await db.customStatement(
        'INSERT INTO investment_group_holdings (group_id, holding_id) '
        'VALUES (30, 10)');

    await expectLater(
      db.customStatement(
          'INSERT INTO investment_group_holdings (group_id, holding_id) '
          'VALUES (30, 10)'),
      throwsA(anything),
      reason: '同一 (group_id, holding_id) 重复插入应被复合主键拒绝',
    );
  });

  test('删持仓时 investment_group_holdings 级联清理', () async {
    await db.customStatement("INSERT INTO ledgers (id, name) VALUES (1, 'L')");
    await db.customStatement("INSERT INTO investment_holdings "
        "(id, ledger_id, fund_code, fund_name, account_id) "
        "VALUES (10, 1, '000001', '基金A', 20)");
    await db
        .customStatement("INSERT INTO investment_groups (id, ledger_id, name) "
            "VALUES (30, 1, '组合A')");
    await db.customStatement(
        'INSERT INTO investment_group_holdings (group_id, holding_id) '
        'VALUES (30, 10)');

    await db.customStatement('DELETE FROM investment_holdings WHERE id = 10');

    final rows =
        await db.customSelect('SELECT * FROM investment_group_holdings').get();
    expect(rows, isEmpty);
  });

  test('删分组时 investment_group_holdings 级联清理', () async {
    await db.customStatement("INSERT INTO ledgers (id, name) VALUES (1, 'L')");
    await db.customStatement("INSERT INTO investment_holdings "
        "(id, ledger_id, fund_code, fund_name, account_id) "
        "VALUES (10, 1, '000001', '基金A', 20)");
    await db
        .customStatement("INSERT INTO investment_groups (id, ledger_id, name) "
            "VALUES (30, 1, '组合A')");
    await db.customStatement(
        'INSERT INTO investment_group_holdings (group_id, holding_id) '
        'VALUES (30, 10)');

    await db.customStatement('DELETE FROM investment_groups WHERE id = 30');

    final rows =
        await db.customSelect('SELECT * FROM investment_group_holdings').get();
    expect(rows, isEmpty);
  });

  test('schemaVersion = 41（当前最新版本）', () {
    expect(db.schemaVersion, 41);
  });
}
