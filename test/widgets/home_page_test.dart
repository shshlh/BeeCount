/// v5.8 首页仪表盘：4 个功能入口 + 资产概览 + 收支统计 + 月度分类占比
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/main/home_page.dart';
import 'package:beecount/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('首页显示 4 入口与各概览模块', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homePeriodStatsProvider.overrideWith((ref) async => {
                'today': (1.0, 2.0),
                'week': (3.0, 4.0),
                'month': (5.0, 6.0),
                'year': (7.0, 8.0),
              }),
          homeCategoryExpensesProvider.overrideWith(
            (ref) async => const [
              (id: 1, name: '餐饮', icon: 'restaurant', total: 100.0),
              (id: 2, name: '交通', icon: 'transport', total: 50.0),
            ],
          ),
          netWorthBreakdownProvider.overrideWith(
            (ref) async => (
              totalAssets: 1000.0,
              totalLiabilities: 200.0,
              netWorth: 800.0,
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('账户总览'), findsOneWidget);
    expect(find.text('智能记账'), findsOneWidget);
    expect(find.text('数据管理'), findsOneWidget);
    expect(find.text('自动化'), findsOneWidget);
    expect(find.text('资产概览'), findsOneWidget);
    expect(find.text('总资产'), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('本周'), findsOneWidget);
    expect(find.text('本月'), findsOneWidget);
    expect(find.text('今年'), findsOneWidget);
    expect(find.text('月度分类占比'), findsOneWidget);
  });
}
