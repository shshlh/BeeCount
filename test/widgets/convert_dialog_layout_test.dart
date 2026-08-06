/// v6.6 转换页 1x4 组件化布局：A/B/C/D 卡片、目标基金下拉、确认按钮下移
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_investment_repository.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/widgets/investment/convert_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalInvestmentRepository investmentRepo;
  late LocalRepository repo;
  late InvestmentHolding fromHolding;

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
        "INSERT INTO accounts (id, ledger_id, name, type, currency) "
        "VALUES (20, 1, '钱包', 'cash', 'CNY')");
    await db.customStatement(
        "INSERT INTO investment_holdings "
        "(id, ledger_id, fund_code, fund_name, account_id, "
        "total_shares, total_cost, current_nav, market_value) "
        "VALUES (1, 1, '000001', '基金A', 10, 1000, 1000, 1.0, 1000)");
    await db.customStatement(
        "INSERT INTO investment_holdings "
        "(id, ledger_id, fund_code, fund_name, account_id, "
        "total_shares, total_cost, current_nav, market_value) "
        "VALUES (2, 1, '000002', '基金B', 10, 500, 500, 1.0, 500)");

    fromHolding = InvestmentHolding(
      id: 1,
      ledgerId: 1,
      fundCode: '000001',
      fundName: '基金A',
      accountId: 10,
      totalShares: 1000,
      totalCost: 1000,
      currentNav: 1.0,
      marketValue: 1000,
      holdingType: 'fund',
      createdAt: DateTime(2026),
    );
  });

  tearDown(() async => db.close());

  Widget host() {
    return ProviderScope(
      overrides: [
        investmentRepositoryProvider.overrideWithValue(investmentRepo),
        repositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        home: ConvertDialog(ledgerId: 1, fromHolding: fromHolding),
      ),
    );
  }

  testWidgets('1x4 组件化布局：A/B/C/D 卡片与目标基金下拉', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
    });

    expect(find.text('从 基金A (000001) 转出'), findsOneWidget);
    expect(find.text('确认转出份额'), findsOneWidget);
    expect(find.text('确认转出净值'), findsOneWidget);
    expect(find.text('目标基金'), findsOneWidget);
    expect(find.text('确认转入份额'), findsOneWidget);
    expect(find.text('确认转入净值'), findsOneWidget);
    expect(find.text('手续费'), findsOneWidget);
    expect(find.text('退回金额'), findsOneWidget);
    expect(find.text('无'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '确认'), findsOneWidget);
  });

  testWidgets('选择已有持仓后自动填入并隐藏手动代码/名称', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
    });

    expect(find.text('目标基金代码'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    expect(find.text('基金B'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(DropdownMenuItem<int>, '基金B'),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(find.text('基金B'), findsOneWidget);
    expect(find.text('目标基金代码'), findsNothing);
    expect(find.text('目标基金名称'), findsNothing);
  });

  testWidgets('选「无」手填目标基金：空代码/名称被校验拦截', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
    });

    expect(find.text('目标基金代码'), findsOneWidget);
    expect(find.text('目标基金名称'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(FilledButton, '确认'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确认'));
    await tester.pumpAndSettle();

    expect(find.text('请输入目标基金代码'), findsOneWidget);
    expect(find.text('请输入目标基金名称'), findsOneWidget);
  });
}
