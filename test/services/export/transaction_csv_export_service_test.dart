// 7.9.1 普通流水 CSV 与投资 CSV 一一对应：投资相关流水只出现在投资 CSV，
// 普通 CSV 增加「流水ID」列（syncId）供 7.9.4 导入幂等去重。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_investment_repository.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/export/investment_csv_export_service.dart';
import 'package:beecount/services/export/transaction_csv_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalInvestmentRepository investmentRepo;
  late LocalRepository repo;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    investmentRepo = LocalInvestmentRepository(db);
    repo = LocalRepository(db);

    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, type, currency, initial_balance) "
        "VALUES (10, 1, '投资账户', 'investment', 'CNY', 0)");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, type, currency, initial_balance) "
        "VALUES (20, 1, '钱包', 'cash', 'CNY', 5000)");

    await repo.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 100,
      accountId: 20,
      happenedAt: DateTime(2026, 8, 1, 9, 30),
      note: '买菜',
      syncId: 'exp-1',
    );

    await investmentRepo.buy(
      ledgerId: 1,
      accountId: 10,
      sourceAccountId: 20,
      fundCode: '000001',
      fundName: '基金A',
      amount: 1000,
      shares: 1000,
      nav: 1.0,
      happenedAt: DateTime(2026, 8, 2),
      note: '买入备注',
    );
    await investmentRepo.sell(
      holdingId: 1,
      shares: 500,
      nav: 1.2,
      targetAccountId: 20,
      happenedAt: DateTime(2026, 8, 3),
      note: '卖出备注',
    );
    await investmentRepo.buy(
      ledgerId: 1,
      accountId: 10,
      sourceAccountId: 20,
      fundCode: '000002',
      fundName: '基金B',
      amount: 500,
      shares: 500,
      nav: 1.0,
      happenedAt: DateTime(2026, 8, 4),
    );
    await investmentRepo.convert(
      fromHoldingId: 1,
      toHoldingId: 2,
      fromShares: 500,
      fromNav: 1.2,
      toShares: 480,
      toNav: 1.25,
      toCost: 600,
      fee: 5,
      refundAmount: 100,
      refundAccountId: 20,
      happenedAt: DateTime(2026, 8, 5),
    );
  });

  tearDown(() async => db.close());

  test('普通 CSV 排除投资流水且含流水ID，投资 CSV 保留完整投资流水', () async {
    final normalCsv = await TransactionCsvExportService(repo: repo).buildCsv(
      ledgerId: 1,
      headers: const [
        '类型',
        '分类',
        '二级分类',
        '金额',
        '币种',
        '账户',
        '转出账户',
        '转入账户',
        '备注',
        '时间',
        '标签',
        '附件',
        '流水ID',
      ],
      typeDisplayName: (t) => t,
      categoryDisplayName: (n) => n ?? '',
    );

    // 普通 CSV 只剩一笔普通支出；投资买入/卖出/转换/退回全部不出现。
    expect(normalCsv, contains('100.00'));
    expect(normalCsv, isNot(contains('000001')));
    expect(normalCsv, isNot(contains('000002')));
    expect(normalCsv, isNot(contains('基金A')));
    expect(normalCsv, isNot(contains('买入备注')));
    expect(normalCsv, isNot(contains('卖出备注')));
    expect(normalCsv, isNot(contains('基金转换退回')));
    expect(normalCsv, contains('流水ID'));
    expect(normalCsv, contains('exp-1'));

    final normalRows =
        normalCsv.split('\n').where((l) => l.trim().isNotEmpty).toList();
    expect(normalRows, hasLength(2), reason: '表头 + 1 笔普通流水');
    expect(normalRows.first.split(',').last, '流水ID');
    expect(normalRows.last.split(',').last, 'exp-1');

    // 投资 CSV 是投资流水的唯一出处，持仓/内部转换/退回仍完整。
    final investmentCsv = await InvestmentCsvExportService(
      investmentRepo: investmentRepo,
      repo: repo,
    ).buildCsv(ledgerId: 1);
    expect(investmentCsv, contains('000001'));
    expect(investmentCsv, contains('000002'));
    expect(investmentCsv, contains('转换卖出'));
    expect(investmentCsv, contains('转换买入'));
    expect(investmentCsv, contains('退回'));
  });
}
