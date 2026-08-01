/// v34 迁移(账户初始资金日期,.codex/TEAM.md 4.9.3)回填语义:
/// - accounts 新增 initial_date(nullable DATETIME)
/// - 已有账户回填 created_at;created_at 缺失用当前 unix 秒
///
/// in-memory db 由 create_all 建出 v34 全 schema,这里用「插 NULL 行 +
/// 执行 onUpgrade 里同一段回填 SQL」验证语义(SQL 与 db.dart v34 迁移块
/// 保持一字不差,改一处必须同步另一处)。
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:beecount/data/db.dart';

/// 与 db.dart `if (from < 34)` 块内的回填 SQL 一致。
const backfillInitialDateSql = '''
    UPDATE accounts SET initial_date = COALESCE(created_at, CAST(strftime('%s','now') AS INTEGER))
    WHERE initial_date IS NULL;''';

void main() {
  late BeeDatabase db;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  test('v34 schema: accounts 含 initial_date 列', () async {
    final cols = await db
        .customSelect('PRAGMA table_info(accounts)')
        .get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(names, contains('initial_date'));
  });

  test('回填:initial_date = created_at;created_at 缺失用当前时间', () async {
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, created_at) "
        "VALUES (10, 1, '旧账户', 1750000000)");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name) VALUES (11, 1, '无时间账户')");

    await db.customStatement(backfillInitialDateSql);

    final rows = await db
        .customSelect('SELECT id, initial_date FROM accounts ORDER BY id')
        .get();
    expect(rows[0].readNullable<int>('initial_date'), 1750000000);
    expect(rows[1].readNullable<int>('initial_date'), isNotNull);
  });

  test('回填幂等:已有 initial_date 不被覆盖', () async {
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, created_at, initial_date) "
        "VALUES (12, 1, '已回填', 1750000000, 1700000000)");

    await db.customStatement(backfillInitialDateSql);

    final row = await db
        .customSelect('SELECT initial_date FROM accounts WHERE id = 12')
        .getSingle();
    expect(row.readNullable<int>('initial_date'), 1700000000);
  });
}
