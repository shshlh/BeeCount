import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_investment_repository.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/models/ai_quick_command.dart';
import 'package:beecount/services/ai/ai_quick_command_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalRepository repo;
  late LocalInvestmentRepository investRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    investRepo = LocalInvestmentRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('新增投资指令且原有指令保留', () {
    final ids = AIQuickCommands.getAllCommands().map((c) => c.id).toList();

    expect(ids, contains('investment_overview'));
    expect(ids, contains('holding_analysis'));
    expect(ids, contains('month_review'));
    expect(ids, contains('financial_health'));
    expect(ids, contains('monthly_expense_summary'));
    expect(ids, contains('category_analysis'));
    expect(ids, contains('budget_planning'));
    expect(ids, contains('abnormal_expense'));
    expect(ids, contains('saving_tips'));
  });

  testWidgets('投资概览 prompt 使用财务上下文数据源', (tester) async {
    late int ledgerId;
    late AIQuickCommandService service;
    await tester.runAsync(() async {
      ledgerId = await repo.createLedger(name: '测试账本', currency: 'CNY');
      final investAccountId = await repo.createAccount(
        ledgerId: ledgerId,
        name: '投资账户',
        type: 'investment',
        currency: 'CNY',
      );
      await investRepo.buy(
        ledgerId: ledgerId,
        accountId: investAccountId,
        fundCode: '000001',
        fundName: '华夏成长混合',
        amount: 1500,
        shares: 1000,
        nav: 1.5,
        happenedAt: DateTime.now().subtract(const Duration(days: 2)),
      );
      service = AIQuickCommandService(
        db: db,
        ledgerId: ledgerId,
        repository: repo,
        investmentRepository: investRepo,
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Builder(builder: (context) => const SizedBox()),
      ),
    );
    final context = tester.element(find.byType(SizedBox));

    final prompt = await tester.runAsync(
      () => service.generatePrompt(
        AIQuickCommands.investmentOverview,
        context,
      ),
    );

    expect(prompt, contains('投资概览'));
    expect(prompt, contains('财务上下文'));
    expect(prompt, contains('华夏成长混合'));
  });
}
