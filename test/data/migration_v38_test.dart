/// v38 迁移（表外/受托账户，7.3.1）：accounts 新增 is_off_balance，默认 0。
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:beecount/data/db.dart';

void main() {
  late BeeDatabase db;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  test('v38 schema: accounts 含 is_off_balance 列且默认 0', () async {
    final cols = await db.customSelect('PRAGMA table_info(accounts)').get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(names, contains('is_off_balance'));

    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name) VALUES (10, 1, '受托账户')");
    final row = await db
        .customSelect('SELECT is_off_balance FROM accounts WHERE id = 10')
        .getSingle();
    expect(row.read<int>('is_off_balance'), 0);
  });

  test('v38 schema: is_off_balance 可写入 1 并读回', () async {
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, is_off_balance) "
        "VALUES (10, 1, '受托账户', 1)");
    final row = await db
        .customSelect('SELECT is_off_balance FROM accounts WHERE id = 10')
        .getSingle();
    expect(row.read<int>('is_off_balance'), 1);
  });

  test('schemaVersion = 38', () {
    expect(db.schemaVersion, 38);
  });
}
