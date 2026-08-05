/// v6.0 首页仪表盘：迁移头部 + 4 入口 + 资产概览主视觉 + 收支统计 + 月度分类占比
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/main/home_page.dart';
import 'package:beecount/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  testWidgets('首页显示迁移头部、4 入口与资产概览主视觉', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homePeriodStatsProvider.overrideWith((ref) async => {
                'today': (
                  income: 1.0,
                  expense: 2.0,
                  start: DateTime(2026, 8, 6),
                  end: DateTime(2026, 8, 7),
                ),
                'week': (
                  income: 3.0,
                  expense: 4.0,
                  start: DateTime(2026, 8, 3),
                  end: DateTime(2026, 8, 10),
                ),
                'month': (
                  income: 5.0,
                  expense: 6.0,
                  start: DateTime(2026, 8, 1),
                  end: DateTime(2026, 9, 1),
                ),
                'year': (
                  income: 7.0,
                  expense: 8.0,
                  start: DateTime(2026, 1, 1),
                  end: DateTime(2027, 1, 1),
                ),
              }),
          netWorthBreakdownProvider.overrideWith(
            (ref) async => (
              totalAssets: 1000.0,
              totalLiabilities: 200.0,
              netWorth: 800.0,
            ),
          ),
          currentLedgerProvider.overrideWith((ref) => Stream<Ledger?>.value(null)),
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

    expect(find.text('蜜蜂记账'), findsOneWidget);
    expect(find.text('新建账本'), findsOneWidget);
    expect(find.byTooltip('AI助手'), findsOneWidget);
    expect(find.byTooltip('日历'), findsOneWidget);
    expect(find.byTooltip('搜索'), findsOneWidget);
    expect(find.text('账户总览'), findsOneWidget);
    expect(find.text('智能记账'), findsOneWidget);
    expect(find.text('数据管理'), findsOneWidget);
    expect(find.text('自动化'), findsOneWidget);
    expect(find.text('明细'), findsNothing);
    expect(find.text('资产概览'), findsOneWidget);
    expect(find.text('净资产'), findsOneWidget);
    expect(find.text('总资产'), findsOneWidget);
    expect(find.text('总负债'), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('本周'), findsOneWidget);
    expect(find.text('本月'), findsOneWidget);
    expect(find.text('今年'), findsOneWidget);
    expect(find.text('2026.8.6'), findsOneWidget);
    expect(find.text('8.3-8.9'), findsOneWidget);
    expect(find.text('8.1-8.31'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('收入'), findsNWidgets(4));
    expect(find.text('支出'), findsNWidgets(4));

    final assetTap = tester.widget<InkWell>(
      find.byKey(const ValueKey('home_asset_overview_tap')),
    );
    expect(assetTap.onTap, isNotNull);
  });
}
