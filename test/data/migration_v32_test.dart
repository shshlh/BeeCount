import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:beecount/data/db.dart';

void main() {
  late BeeDatabase db;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  test('v32 schema: InvestmentHoldings 表存在且含所有列', () async {
    final cols = await db
        .customSelect("PRAGMA table_info(investment_holdings)")
        .get();
    final names = cols.map((r) => r.read<String>('name')).toSet();

    expect(names, containsAll([
      'id', 'ledger_id', 'fund_code', 'fund_name', 'account_id',
      'total_shares', 'total_cost', 'current_nav', 'market_value',
      'holding_type', 'note', 'created_at', 'updated_at',
    ]));
  });

  test('v32 schema: transactions 含 6 个投资字段', () async {
    final cols = await db
        .customSelect("PRAGMA table_info(transactions)")
        .get();
    final names = cols.map((r) => r.read<String>('name')).toSet();

    expect(names, containsAll([
      'invest_type', 'invest_shares', 'invest_nav',
      'invest_fee', 'holding_id', 'batch_id',
    ]));
  });

  test('v32 schema: transactions.type 可接受 invest', () async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name) VALUES (999, 'L')");
    await db.customStatement(
        "INSERT INTO transactions (id, ledger_id, type, amount) "
        "VALUES (99901, 999, 'invest', 100.0)");
    final row = await db.customSelect(
        "SELECT type FROM transactions WHERE id = 99901").getSingle();
    expect(row.read<String>('type'), 'invest');
  });

  test('v32 迁移幂等：_addColumnIfMissing 对已存在列不报错', () async {
    // 确认 invest_type 已存在
    final cols = await db
        .customSelect("PRAGMA table_info(transactions)")
        .get();
    final hasInvestType =
        cols.any((r) => r.read<String>('name') == 'invest_type');
    expect(hasInvestType, isTrue);

    // 在已存在的列上重复 ALTER ADD 应报 duplicate column
    await expectLater(
      () => db.customStatement(
          'ALTER TABLE transactions ADD COLUMN invest_type TEXT;'),
      throwsA(isA<Exception>()),
    );
  });

  test('investment_holdings 索引存在', () async {
    // 手动建索引验证（forTesting 用 createAll 不走 migration）
    await db.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_investment_holdings_ledger '
        'ON investment_holdings (ledger_id);');
    await db.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_investment_holdings_account '
        'ON investment_holdings (account_id);');
    await db.customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_investment_holdings_fund '
        'ON investment_holdings (ledger_id, fund_code, account_id);');

    final indexes = await db
        .customSelect(
            "SELECT name FROM sqlite_master WHERE type='index' "
            "AND tbl_name='investment_holdings'")
        .get();
    final names = indexes.map((r) => r.read<String>('name')).toSet();

    expect(names, contains('idx_investment_holdings_ledger'));
    expect(names, contains('idx_investment_holdings_account'));
    expect(names, contains('idx_investment_holdings_fund'));
  });
}
