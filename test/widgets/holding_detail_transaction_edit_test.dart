// 7.5.5 单笔基金操作记录编辑：日期之外增加「时间」行（时/分），保存后秒归零。
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
import 'package:beecount/pages/investment/holding_detail_page.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/widgets/biz/section_card.dart';

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
      happenedAt: DateTime(2026, 8, 1, 10, 30, 45),
    );
  });

  tearDown(() async => db.close());

  testWidgets('单笔编辑存在时间行，保存写入时/分且秒归零', (tester) async {
    await tester.runAsync(() async {
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
            home: const HoldingDetailPage(holdingId: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
            of: find.byType(SectionCard), matching: find.text('买入')),
      );
      await tester.pumpAndSettle();

      expect(find.text('编辑交易'), findsOneWidget);
      expect(find.text('日期'), findsOneWidget);
      expect(find.text('时间'), findsOneWidget);

      await tester.tap(
        find
            .ancestor(of: find.text('时间'), matching: find.byType(InkWell))
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('选择时间'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '确定'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      final tx = await investmentRepo.watchTransactions(1).first;
      expect(tx.single.happenedAt.hour, 10);
      expect(tx.single.happenedAt.minute, 30);
      expect(tx.single.happenedAt.second, 0);

      // 卸载 ProviderScope 并冲刷 Drift stream 取消产生的零时长 timer
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    });
  });
}
