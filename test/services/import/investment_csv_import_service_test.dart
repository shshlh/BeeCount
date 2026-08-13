// 7.10.3 投资 CSV 专用导入：导出 → 清空 → 导入 roundtrip，持仓/流水/分组
// 恢复；重复导入按流水ID 幂等不重复。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_investment_repository.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/export/investment_csv_export_service.dart';
import 'package:beecount/services/import/investment_csv_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

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

    await investmentRepo.buy(
      ledgerId: 1,
      accountId: 10,
      sourceAccountId: 20,
      fundCode: '000001',
      fundName: '基金A',
      amount: 1000,
      shares: 1000,
      nav: 1.0,
      happenedAt: DateTime(2026, 8, 1, 10, 30),
      note: '买入备注',
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
      happenedAt: DateTime(2026, 8, 1, 11, 0),
    );
    final groupId =
        await investmentRepo.createGroup(ledgerId: 1, name: '核心');
    await investmentRepo.addHoldingsToGroup(groupId, [1]);

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
      happenedAt: DateTime(2026, 8, 2, 9, 0),
    );
  });

  tearDown(() async => db.close());

  test('投资 CSV 导出→清空→导入 roundtrip，持仓/流水/分组恢复且幂等', () async {
    final csv = await InvestmentCsvExportService(
      investmentRepo: investmentRepo,
      repo: repo,
    ).buildCsv(ledgerId: 1);
    final expectedHoldings =
        (await investmentRepo.getHoldingsForLedger(1)).length;
    final expectedFlows =
        (await investmentRepo.getInvestmentTransactionsForLedger(1)).length;

    await repo.resetLedger(1);
    expect(await (db.select(db.accounts)).get(), isEmpty);
    expect(await (db.select(db.investmentHoldings)).get(), isEmpty);

    final service = InvestmentCsvImportService(
      repo: repo,
      investmentRepo: investmentRepo,
    );
    final result = await service.importCsv(ledgerId: 1, csvText: csv);

    expect(result.holdingsImported, expectedHoldings);
    expect(result.flowsImported, expectedFlows);
    expect(result.flowsSkipped, 0);
    expect(result.groupsImported, 1);

    final holdings = await investmentRepo.getHoldingsForLedger(1);
    expect(holdings.map((h) => h.fundCode).toSet(), {'000001', '000002'});
    expect((await investmentRepo.getInvestmentTransactionsForLedger(1)).length,
        expectedFlows);

    final groups = await investmentRepo.watchGroups(ledgerId: 1).first;
    expect(groups.single.name, '核心');
    final members =
        await investmentRepo.watchGroupHoldingIds(groups.single.id).first;
    expect(members, isNotEmpty);

    // 批次关联恢复：转换卖出/买入/退回共享同一 batchId。
    final txs = await investmentRepo.getInvestmentTransactionsForLedger(1);
    final batchIds = txs.map((t) => t.batchId).whereType<String>().toSet();
    expect(batchIds, isNotEmpty);

    // 幂等：第二次导入全部按流水ID 跳过，流水数量不变。
    final second = await service.importCsv(ledgerId: 1, csvText: csv);
    expect(second.flowsSkipped, expectedFlows);
    expect(second.flowsImported, 0);
    expect((await investmentRepo.getInvestmentTransactionsForLedger(1)).length,
        expectedFlows);
  });
}
