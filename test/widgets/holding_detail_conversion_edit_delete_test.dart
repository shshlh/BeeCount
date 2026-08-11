// 7.5.4 转换记录一体化：A/B 两页统一显示「转换」，且可从任意一侧编辑/删除
// 整批（A 卖出 + B 买入 + 退回），双方持仓与投资账户市值同步重算。
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
  late LocalRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
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
      happenedAt: DateTime(2026, 8, 1, 9, 0),
    );
    await investmentRepo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000002',
      fundName: '基金B',
      amount: 500,
      shares: 500,
      nav: 1.0,
      happenedAt: DateTime(2026, 8, 1, 9, 0),
    );
  });

  tearDown(() async => db.close());

  Future<void> seedConversion() async {
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
      happenedAt: DateTime(2026, 8, 2, 10, 0),
    );
  }

  Widget host(int holdingId) {
    return ProviderScope(
      overrides: [
        investmentRepositoryProvider.overrideWithValue(investmentRepo),
        repositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: HoldingDetailPage(holdingId: holdingId),
      ),
    );
  }

  testWidgets('A 页显示「转换」并整批编辑，保存后双方持仓重算', (tester) async {
    await tester.runAsync(() async {
      await seedConversion();
      await tester.pumpWidget(host(1));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
            of: find.byType(SectionCard), matching: find.text('转换')),
        findsOneWidget,
      );
      expect(
        find.descendant(
            of: find.byType(SectionCard), matching: find.text('卖出')),
        findsNothing,
      );

      await tester.tap(find.text('转换').first);
      await tester.pumpAndSettle();

      expect(find.text('编辑转换'), findsOneWidget);
      expect(find.text('转入成本'), findsOneWidget);
      expect(find.text('日期'), findsOneWidget);
      expect(find.text('时间'), findsOneWidget);
      expect(find.text('备注'), findsOneWidget);

      await tester.ensureVisible(find.text('时间'));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .ancestor(of: find.text('时间'), matching: find.byType(InkWell))
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('选择时间'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '确定'));
      await tester.pumpAndSettle();

      // 字段顺序：转出份额/转出净值/转入份额/转入净值/转入成本/手续费/退回金额/备注
      await tester.enterText(find.byType(TextFormField).at(0), '400');
      await tester.enterText(find.byType(TextFormField).at(2), '420');
      await tester.enterText(find.byType(TextFormField).at(3), '1.2');
      await tester.enterText(find.byType(TextFormField).at(4), '500');
      await tester.enterText(find.byType(TextFormField).at(5), '8');
      await tester.enterText(find.byType(TextFormField).at(6), '120');

      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      final from = await investmentRepo.getHolding(1);
      expect(from!.totalShares, closeTo(600, 0.01));
      expect(from.totalCost, closeTo(600, 0.01));
      final to = await investmentRepo.getHolding(2);
      expect(to!.totalShares, closeTo(920, 0.01));
      expect(to.totalCost, closeTo(1000, 0.01));

      final allTxs = await db.select(db.transactions).get();
      final sellTx = allTxs.singleWhere((t) => t.investType == 'sell');
      expect(sellTx.happenedAt.second, 0);

      // 卸载 ProviderScope 并冲刷 Drift stream 取消产生的零时长 timer
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    });
  });

  testWidgets('B 页显示「转换」并整批删除，双方持仓还原', (tester) async {
    await tester.runAsync(() async {
      await seedConversion();
      await tester.pumpWidget(host(2));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
            of: find.byType(SectionCard), matching: find.text('转换')),
        findsOneWidget,
      );
      expect(
        find.descendant(
            of: find.byType(SectionCard), matching: find.text('买入')),
        findsOneWidget, // 初始买入行仍是「买入」
      );

      final convertRow = find.ancestor(
        of: find.descendant(
            of: find.byType(SectionCard), matching: find.text('转换')),
        matching: find.byType(SectionCard),
      );
      await tester.tap(
        find.descendant(of: convertRow, matching: find.byTooltip('删除流水')),
      );
      await tester.pumpAndSettle();
      expect(find.text('删除转换记录'), findsOneWidget);
      expect(find.textContaining('删除完整的转换记录'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '删除'));
      await tester.pumpAndSettle();

      final remaining = await db.select(db.transactions).get();
      expect(remaining.where((t) => t.batchId != null), isEmpty);
      final from = await investmentRepo.getHolding(1);
      expect(from!.totalShares, closeTo(1000, 0.01));
      expect(from.totalCost, closeTo(1000, 0.01));
      final to = await investmentRepo.getHolding(2);
      expect(to!.totalShares, closeTo(500, 0.01));
      expect(to.totalCost, closeTo(500, 0.01));

      // 卸载 ProviderScope 并冲刷 Drift stream 取消产生的零时长 timer
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    });
  });
}
