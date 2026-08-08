/// v35 迁移（账户不计入资产，5.6.3）：accounts 新增 exclude_from_assets，
/// 默认 false。
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:beecount/data/db.dart';

void main() {
  late BeeDatabase db;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  test('v35 schema: accounts 含 exclude_from_assets 列且默认 false', () async {
    final cols = await db.customSelect('PRAGMA table_info(accounts)').get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(names, contains('exclude_from_assets'));

    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name) VALUES (10, 1, '账户A')");
    final row = await db
        .customSelect('SELECT exclude_from_assets FROM accounts WHERE id = 10')
        .getSingle();
    expect(row.read<int>('exclude_from_assets'), 0);
  });

  test('schemaVersion = 37（当前最新版本）', () {
    expect(db.schemaVersion, 37);
  });
}
