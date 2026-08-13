// 7.8.1 CSV 导出投资内容：持仓 / 投资流水（含转换内部卖出买入与退回）/
// 分组归属全部归档；普通流水 CSV 口径不受影响。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_investment_repository.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/export/investment_csv_export_service.dart';

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
        "INSERT INTO accounts (id, ledger_id, name, type, currency) "
        "VALUES (10, 1, '投资账户', 'investment', 'CNY')");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, type, currency, initial_balance) "
        "VALUES (20, 1, '钱包', 'virtual_account', 'CNY', 5000)");

    await investmentRepo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000001',
      fundName: '基金A',
      amount: 1000,
      shares: 1000,
      nav: 1.0,
      happenedAt: DateTime(2026, 8, 1),
    );
    await investmentRepo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000002',
      fundName: '基金B',
      amount: 500,
      shares: 500,
      nav: 1.0,
      happenedAt: DateTime(2026, 8, 1),
    );

    final groupId = await investmentRepo.createGroup(ledgerId: 1, name: '核心');
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
      happenedAt: DateTime(2026, 8, 2),
    );
  });

  tearDown(() async => db.close());

  test('导出 CSV 包含持仓/投资流水/分组归属与转换内部两笔', () async {
    final service = InvestmentCsvExportService(
      investmentRepo: investmentRepo,
      repo: repo,
    );
    final csv = await service.buildCsv(ledgerId: 1);

    expect(csv, contains('【持仓】'));
    expect(csv, contains('基金代码'));
    expect(csv, contains('000001'));
    expect(csv, contains('000002'));

    expect(csv, contains('【投资流水】'));
    expect(csv, contains('流水ID'));
    expect(csv, contains('批次ID'));
    expect(csv, contains('金额'));
    expect(csv, contains('转出账户'));
    expect(csv, contains('转入账户'));
    expect(csv, contains('投资账户'));
    expect(csv, contains('钱包'));
    expect(csv, contains('转换卖出'));
    expect(csv, contains('转换买入'));
    expect(csv, contains('退回'));
    expect(csv, contains('100.00')); // 退回金额

    expect(csv, contains('【分组】'));
    expect(csv, contains('核心'));
    expect(csv, contains('【分组归属】'));

    // 7.9.1/7.9.4：投资流水带稳定流水ID（syncId），与明细一一对应。
    final txs = await investmentRepo.getInvestmentTransactionsForLedger(1);
    for (final t in txs) {
      expect(t.syncId, isNotNull);
      expect(csv, contains(t.syncId!));
    }
  });

  test('导出可落盘为文件且非空', () async {
    final dir = Directory.systemTemp.createTempSync('inv_csv_test');
    addTearDown(() => dir.deleteSync(recursive: true));

    final service = InvestmentCsvExportService(
      investmentRepo: investmentRepo,
      repo: repo,
    );
    final csv = await service.buildCsv(ledgerId: 1);
    final file = File('${dir.path}/beecount_investments_test.csv');
    await file.writeAsString('\uFEFF$csv');

    expect(await file.exists(), isTrue);
    final content = await file.readAsString();
    expect(content, contains('【持仓】'));
    expect(content, contains('【投资流水】'));
    expect(content, contains('【分组归属】'));
  });

  test('旧版退回流水（无 batchId）也能导出为「退回」', () async {
    // 模拟 7.5.4 之前的旧版转换退回：investType/batchId 均为 null，
    // 仅靠 note='基金转换退回' 识别。
    await db.customStatement("INSERT INTO transactions "
        "(id, ledger_id, type, amount, account_id, to_account_id, happened_at, note) "
        "VALUES (999, 1, 'transfer', 50.0, 10, 20, 1715040000, '基金转换退回')");

    final csv = await InvestmentCsvExportService(
      investmentRepo: investmentRepo,
      repo: repo,
    ).buildCsv(ledgerId: 1);

    expect(csv, contains('50.00'));
    expect(csv, contains('基金转换退回'));
    // 新批次退回 + 旧版退回都应出现「退回」类型
    expect('退回'.allMatches(csv).length, greaterThanOrEqualTo(2));
  });
}
