/// v39 迁移（7.5.5）：历史转换内部卖出/买入流水回填 exclude_from_stats=1，
/// 明细/统计不再展示；退回流水保持可见。
///
/// in-memory db 由 create_all 建出 v39 全 schema，这里用「插旧数据 + 执行
/// onUpgrade 里同一段回填 SQL」验证语义（SQL 与 db.dart v39 迁移块保持一致）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_transaction_repository.dart';

/// 与 db.dart `if (from < 39)` 块内的回填 SQL 一致。
const backfillInternalConvertSql = '''
UPDATE transactions SET exclude_from_stats = 1
WHERE batch_id IS NOT NULL
AND invest_type IN ('sell', 'buy');''';

void main() {
  late BeeDatabase db;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  Future<void> seed() async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, type, currency) "
        "VALUES (10, 1, '投资账户', 'investment', 'CNY')");
    // 旧转换内部卖出/买入 + 退回
    await db.customStatement(
        "INSERT INTO transactions (id, ledger_id, type, amount, account_id, "
        "invest_type, holding_id, batch_id) "
        "VALUES (100, 1, 'transfer', 0, 10, 'sell', 1, 'batch-1')");
    await db.customStatement(
        "INSERT INTO transactions (id, ledger_id, type, amount, to_account_id, "
        "invest_type, holding_id, batch_id) "
        "VALUES (101, 1, 'transfer', 600, 10, 'buy', 2, 'batch-1')");
    await db.customStatement(
        "INSERT INTO transactions (id, ledger_id, type, amount, account_id, "
        "to_account_id, batch_id, note) "
        "VALUES (102, 1, 'transfer', 100, 10, 20, 'batch-1', '基金转换退回')");
    // 普通买入（无 batch）不应被回填
    await db.customStatement(
        "INSERT INTO transactions (id, ledger_id, type, amount, account_id, "
        "invest_type, holding_id) "
        "VALUES (103, 1, 'transfer', 500, 10, 'buy', 2)");
  }

  Future<Map<int, int>> readFlags() async {
    final rows = await db
        .customSelect('SELECT id, exclude_from_stats FROM transactions')
        .get();
    return {
      for (final r in rows)
        r.read<int>('id'): r.read<int>('exclude_from_stats'),
    };
  }

  test('schemaVersion = 41', () {
    expect(db.schemaVersion, 41);
  });

  test('回填：旧转换卖出/买入 exclude_from_stats=1，退回与普通流水保持 0', () async {
    await seed();
    await db.customStatement(backfillInternalConvertSql);

    final flags = await readFlags();
    expect(flags[100], 1); // 卖出
    expect(flags[101], 1); // 买入
    expect(flags[102], 0); // 退回
    expect(flags[103], 0); // 普通买入
  });

  test('回填后旧转换内部流水不再出现在明细，退回仍在', () async {
    await seed();
    await db.customStatement(backfillInternalConvertSql);

    final detail = await LocalTransactionRepository(db)
        .watchTransactionsWithCategoryAll(ledgerId: 1)
        .first;
    final ids = detail.map((r) => r.t.id).toSet();
    expect(ids, isNot(contains(100)));
    expect(ids, isNot(contains(101)));
    expect(ids, contains(102)); // 退回
    expect(ids, contains(103)); // 普通买入
  });
}
