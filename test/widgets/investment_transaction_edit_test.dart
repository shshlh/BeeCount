// 7.6.2 投资流水明细编辑安全：投资流水走受限编辑，不再出现通用编辑器的
// 金额/账户/分类等字段。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_investment_repository.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/utils/transaction_edit_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalInvestmentRepository investmentRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    investmentRepo = LocalInvestmentRepository(db);

    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, type, currency) "
        "VALUES (10, 1, '投资账户', 'investment', 'CNY')");
    await investmentRepo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000001',
      fundName: '基金A',
      amount: 1000,
      shares: 1000,
      nav: 1.0,
      happenedAt: DateTime(2026, 8, 1, 10, 30),
    );
  });

  tearDown(() async => db.close());

  testWidgets('投资流水编辑打开受限页，无金额/账户/分类字段', (tester) async {
    await tester.runAsync(() async {
      final tx = (await investmentRepo.watchTransactions(1).first).single;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            investmentRepositoryProvider.overrideWithValue(investmentRepo),
            repositoryProvider.overrideWithValue(LocalRepository(db)),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => TransactionEditUtils.editTransaction(
                      context,
                      ref,
                      tx,
                      null,
                    ),
                    child: const Text('编辑'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      expect(find.text('编辑投资流水'), findsOneWidget);
      expect(find.text('日期'), findsOneWidget);
      expect(find.text('备注'), findsOneWidget);
      expect(find.text('标签'), findsOneWidget);
      expect(find.text('金额'), findsNothing);
      expect(find.text('账户'), findsNothing);
      expect(find.text('分类'), findsNothing);
      expect(find.text('份额'), findsNothing);
      expect(find.text('净值'), findsNothing);
      expect(find.text('手续费'), findsNothing);

      // 卸载 ProviderScope 并冲刷 Drift stream 取消产生的零时长 timer
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    });
  });
}
