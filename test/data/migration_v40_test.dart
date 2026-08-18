// v40 迁移（7.11.1）：账户 ledger_id 回填 / 孤儿清理。
// in-memory db 由 create_all 建出 v40 全 schema，用「插旧数据 + 执行
// migrateAccountLedgerIds」验证语义（与 db.dart v40 迁移块一致）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  Future<Map<int, int>> accountLedgerIds() async {
    final rows =
        await db.customSelect('SELECT id, ledger_id FROM accounts').get();
    return {
      for (final r in rows)
        r.read<int>('id'): r.read<int>('ledger_id'),
    };
  }

  test('schemaVersion = 42', () {
    expect(db.schemaVersion, 42);
  });

  test('ledger_id=0 账户按流水反推回填到正确账本', () async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L1', 'CNY')");
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (2, 'L2', 'CNY')");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, type, currency) "
        "VALUES (10, 0, '现金', 'cash', 'CNY')");
    // L1 有 2 条关联、L2 有 1 条 → 应回填到 L1
    await db.customStatement(
        "INSERT INTO transactions (id, ledger_id, type, amount, account_id) "
        "VALUES (100, 1, 'expense', 10, 10)");
    await db.customStatement(
        "INSERT INTO transactions (id, ledger_id, type, amount, to_account_id) "
        "VALUES (101, 1, 'transfer', 20, 10)");
    await db.customStatement(
        "INSERT INTO transactions (id, ledger_id, type, amount, account_id) "
        "VALUES (102, 2, 'expense', 30, 10)");

    await db.migrateAccountLedgerIds();

    final ids = await accountLedgerIds();
    expect(ids[10], 1);
  });

  test('无关联流水的孤儿账户：仅一个账本时回填，多个账本时删除', () async {
    // 单一账本 → 回填
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, type, currency) "
        "VALUES (11, 0, '现金', 'cash', 'CNY')");
    await db.migrateAccountLedgerIds();
    expect((await accountLedgerIds())[11], 1);

    // 两个账本且无流水 → 删除
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (2, 'L2', 'CNY')");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, type, currency) "
        "VALUES (12, 0, '孤儿账户', 'cash', 'CNY')");
    await db.migrateAccountLedgerIds();
    expect(await accountLedgerIds(), isNot(contains(12)));
  });

  test('指向已删账本的孤儿账户：无流水且仅一个可用账本时回填', () async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    // ledger_id=99 指向已删账本，无关联流水
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, type, currency) "
        "VALUES (13, 99, '残留账户', 'cash', 'CNY')");

    await db.migrateAccountLedgerIds();

    expect((await accountLedgerIds())[13], 1);
  });

  test('迁移幂等：重复执行不改变结果', () async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, type, currency) "
        "VALUES (14, 0, '现金', 'cash', 'CNY')");
    await db.customStatement(
        "INSERT INTO transactions (id, ledger_id, type, amount, account_id) "
        "VALUES (200, 1, 'expense', 10, 14)");

    await db.migrateAccountLedgerIds();
    final first = await accountLedgerIds();
    await db.migrateAccountLedgerIds();
    final second = await accountLedgerIds();

    expect(second, first);
    expect(second[14], 1);
  });

  test('有持仓无流水的账户按持仓 ledger_id 回填', () async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, type, currency) "
        "VALUES (15, 0, '投资账户', 'investment', 'CNY')");
    await db.customStatement(
        "INSERT INTO investment_holdings "
        "(id, ledger_id, fund_code, fund_name, account_id) "
        "VALUES (100, 1, '000001', '基金A', 15)");

    await db.migrateAccountLedgerIds();

    expect((await accountLedgerIds())[15], 1);
  });

  test('有周期交易无流水的账户按周期交易 ledger_id 回填', () async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, type, currency) "
        "VALUES (16, 0, '现金', 'cash', 'CNY')");
    await db.customStatement(
        "INSERT INTO recurring_transactions "
        "(id, ledger_id, type, amount, account_id, frequency, start_date) "
        "VALUES (200, 1, 'expense', 10, 16, 'monthly', 1700000000)");

    await db.migrateAccountLedgerIds();

    expect((await accountLedgerIds())[16], 1);
  });
}
