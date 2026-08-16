// 7.13.6 诊断修复：普通 CSV 按 (ledgerId, name) 去重；投资 CSV 导入恢复
// 全部【账户】段账户，逐字段断言 ledgerId/type/hidden/isOffBalance/currency。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_investment_repository.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/data_import_service.dart';
import 'package:beecount/services/export/investment_csv_export_service.dart';
import 'package:beecount/services/import/investment_csv_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late LocalRepository repo;
  late LocalInvestmentRepository investmentRepo;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    investmentRepo = LocalInvestmentRepository(db);
  });

  tearDown(() async => db.close());

  test('普通 CSV 导入账户按 (ledgerId, name) 去重，不误用他账本同名账户', () async {
    final ledger1 = await repo.createLedger(name: 'L1', currency: 'CNY');
    await repo.createLedger(name: 'L2', currency: 'CNY');
    // 预置 L2 同名「微信」，L1 不应复用它的 id。
    await repo.createAccount(
        ledgerId: 2, name: '微信', type: 'cash', currency: 'CNY');

    final nameToId = await DataImportService().importAccounts(
      repo,
      [
        const ImportAccount(name: '微信', type: 'virtual'),
        const ImportAccount(name: '银行卡', type: 'bank_card'),
        const ImportAccount(name: '信用卡', type: 'credit_card'),
        const ImportAccount(name: '数字人民币', type: 'virtual'),
      ],
      ledgerId: ledger1,
    );

    final accounts = await repo.getAllAccounts();
    final wechatL1 = accounts.firstWhere(
        (a) => a.name == '微信' && a.ledgerId == ledger1);
    expect(wechatL1.type, 'virtual');
    final wechatL2 =
        accounts.firstWhere((a) => a.name == '微信' && a.ledgerId == 2);
    expect(wechatL1.id, isNot(wechatL2.id));
    expect(nameToId['微信'], wechatL1.id);

    final bank = accounts.firstWhere((a) => a.name == '银行卡');
    final credit = accounts.firstWhere((a) => a.name == '信用卡');
    final digital = accounts.firstWhere((a) => a.name == '数字人民币');
    expect(bank.type, 'bank_card');
    expect(bank.ledgerId, ledger1);
    expect(credit.type, 'credit_card');
    expect(credit.ledgerId, ledger1);
    expect(digital.type, 'virtual');
    expect(digital.ledgerId, ledger1);
  });

  test('投资 CSV 导出→清空→导入后逐字段恢复全部账户', () async {
    final ledgerId = await repo.createLedger(name: 'L', currency: 'CNY');
    final hiddenId = await repo.createAccount(
        ledgerId: ledgerId, name: '隐藏账户', type: 'cash', currency: 'CNY');
    await repo.setAccountHidden(hiddenId, true);
    await repo.createAccount(
        ledgerId: ledgerId,
        name: '表外账户',
        type: 'cash',
        currency: 'CNY',
        isOffBalance: true,
        initialDate: DateTime(2026, 1, 1));
    await repo.createAccount(
        ledgerId: ledgerId,
        name: '银行卡',
        type: 'bank_card',
        currency: 'CNY',
        bankName: '招商银行',
        cardLastFour: '1234');
    await repo.createAccount(
        ledgerId: ledgerId,
        name: '信用卡',
        type: 'credit_card',
        currency: 'CNY',
        creditLimit: 50000,
        billingDay: 10,
        paymentDueDay: 5);
    await repo.createAccount(
        ledgerId: ledgerId,
        name: '投资账户',
        type: 'investment',
        currency: 'CNY',
        note: '基金账户');
    await investmentRepo.buy(
      ledgerId: ledgerId,
      accountId: 5,
      sourceAccountId: 4,
      fundCode: '000001',
      fundName: '基金A',
      amount: 1000,
      shares: 1000,
      nav: 1.0,
      happenedAt: DateTime(2026, 8, 1),
    );

    final before = {
      for (final a in await repo.getAllAccounts()) a.name: a,
    };
    final csv = await InvestmentCsvExportService(
      investmentRepo: investmentRepo,
      repo: repo,
    ).buildCsv(ledgerId: ledgerId);

    await repo.resetLedger(ledgerId);
    expect(await repo.getAllAccounts(), isEmpty);

    final result = await InvestmentCsvImportService(
      repo: repo,
      investmentRepo: investmentRepo,
    ).importCsv(ledgerId: ledgerId, csvText: csv);
    expect(result.holdingsImported, greaterThan(0));

    final after = {
      for (final a in await repo.getAllAccounts()) a.name: a,
    };
    for (final name in before.keys) {
      final src = before[name]!;
      final dst = after[name];
      expect(dst, isNotNull, reason: '账户 $name 导入后应存在');
      expect(dst!.ledgerId, src.ledgerId, reason: '$name ledgerId');
      expect(dst.type, src.type, reason: '$name type');
      expect(dst.hidden, src.hidden, reason: '$name hidden');
      expect(dst.isOffBalance, src.isOffBalance, reason: '$name isOffBalance');
      expect(dst.currency, src.currency, reason: '$name currency');
      expect(dst.initialDate, src.initialDate, reason: '$name initialDate');
      expect(dst.note, src.note, reason: '$name note');
      expect(dst.bankName, src.bankName, reason: '$name bankName');
      expect(dst.cardLastFour, src.cardLastFour, reason: '$name cardLastFour');
      expect(dst.creditLimit, src.creditLimit, reason: '$name creditLimit');
      expect(dst.billingDay, src.billingDay, reason: '$name billingDay');
      expect(
          dst.paymentDueDay, src.paymentDueDay, reason: '$name paymentDueDay');
    }
  });
}
