/// v5.4 资产界面布局：投资组合摘要固定占位、导入按钮在顶部栏右侧
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/investment/holdings_list_page.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/services/data/investment_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('组合摘要固定 + 顶部导入按钮 + 空态', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentHoldingsProvider.overrideWith(
            (ref) => Stream<List<InvestmentHolding>>.value(const []),
          ),
          groupsProvider.overrideWith(
            (ref) => Stream<List<InvestmentGroup>>.value(const []),
          ),
          portfolioSummaryProvider.overrideWith(
            (ref) async => const PortfolioSummary(
              totalMarketValue: 0,
              totalCost: 0,
              unrealizedPnL: 0,
              returnRate: 0,
              holdingCount: 0,
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const HoldingsListPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('投资持仓'), findsOneWidget);
    expect(find.byTooltip('导入初始持仓'), findsOneWidget);
    expect(find.text('投资组合'), findsOneWidget);
    expect(find.text('暂无持仓'), findsOneWidget);
  });

  testWidgets('持仓存在时固定显示排序行与分组 chips', (tester) async {
    final holding = InvestmentHolding(
      id: 1,
      ledgerId: 1,
      fundCode: '000001',
      fundName: '基金A',
      accountId: 10,
      totalShares: 100,
      totalCost: 100,
      currentNav: 2.0,
      marketValue: 200,
      holdingType: 'fund',
      createdAt: DateTime(2026),
    );
    final group = InvestmentGroup(
      id: 1,
      ledgerId: 1,
      name: '组合A',
      sortOrder: 0,
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentHoldingsProvider.overrideWith(
            (ref) => Stream<List<InvestmentHolding>>.value([holding]),
          ),
          filteredHoldingsProvider.overrideWith(
            (ref) async => [holding],
          ),
          groupsProvider.overrideWith(
            (ref) => Stream<List<InvestmentGroup>>.value([group]),
          ),
          portfolioSummaryProvider.overrideWith(
            (ref) async => const PortfolioSummary(
              totalMarketValue: 200,
              totalCost: 100,
              unrealizedPnL: 100,
              returnRate: 1,
              holdingCount: 1,
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const HoldingsListPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('排序'), findsOneWidget);
    expect(find.text('持有金额'), findsOneWidget);
    expect(find.text('持有收益'), findsOneWidget);
    expect(find.text('持有收益率'), findsOneWidget);
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('组合A'), findsOneWidget);
    expect(find.text('新建分组'), findsOneWidget);
    expect(find.text('基金A'), findsOneWidget);
  });

  testWidgets('选中分组无基金时显示分组空态', (tester) async {
    final holding = InvestmentHolding(
      id: 1,
      ledgerId: 1,
      fundCode: '000001',
      fundName: '基金A',
      accountId: 10,
      totalShares: 100,
      totalCost: 100,
      currentNav: 2.0,
      marketValue: 200,
      holdingType: 'fund',
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentHoldingsProvider.overrideWith(
            (ref) => Stream<List<InvestmentHolding>>.value([holding]),
          ),
          filteredHoldingsProvider.overrideWith(
            (ref) async => <InvestmentHolding>[],
          ),
          groupsProvider.overrideWith(
            (ref) => Stream<List<InvestmentGroup>>.value(const []),
          ),
          portfolioSummaryProvider.overrideWith(
            (ref) async => const PortfolioSummary(
              totalMarketValue: 200,
              totalCost: 100,
              unrealizedPnL: 100,
              returnRate: 1,
              holdingCount: 1,
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const HoldingsListPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('该分组暂无基金'), findsOneWidget);
    expect(find.text('长按分组可编辑成员'), findsOneWidget);
  });
}
