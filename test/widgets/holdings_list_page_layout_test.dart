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
}
