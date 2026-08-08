import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart' show WebViewWidget;

import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/settings/about_page.dart';
import 'package:beecount/pages/settings/changelog_page.dart';
import 'package:beecount/pages/settings/privacy_policy_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'BeeCount',
      packageName: 'com.tntlikely.beecount',
      version: '7.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: page,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('关于页显示自用声明并移除原开发者社交/捐赠入口', (tester) async {
    await pumpPage(tester, const AboutPage());

    expect(find.text('关于本应用'), findsOneWidget);
    expect(find.text('自用说明'), findsOneWidget);
    expect(find.textContaining('TNT-Likely'), findsOneWidget);
    expect(find.text('开发者的话'), findsNothing);
    expect(find.text('官方网站'), findsNothing);
    expect(find.text('GitHub'), findsNothing);
    expect(find.text('Telegram 群'), findsNothing);
    expect(find.text('小红书'), findsNothing);
    expect(find.text('抖音'), findsNothing);
    expect(find.text('支持开发'), findsNothing);
    expect(find.text('浙ICP备2025214907号-2A'), findsNothing);
  });

  testWidgets('关于页更新日志与隐私政策均打开本地静态页', (tester) async {
    await pumpPage(tester, const AboutPage());

    await tester.ensureVisible(find.text('更新日志'));
    await tester.tap(find.text('更新日志'));
    await tester.pumpAndSettle();

    expect(find.byType(ChangelogPage), findsOneWidget);
    expect(find.text('7.0 自用化'), findsOneWidget);
    expect(find.textContaining('移除原开发者品牌'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('隐私政策'));
    await tester.tap(find.text('隐私政策'));
    await tester.pumpAndSettle();

    expect(find.byType(PrivacyPolicyPage), findsOneWidget);
    expect(find.text('数据存储'), findsOneWidget);
    expect(find.textContaining('仅保存在本机'), findsOneWidget);
    expect(find.text('第三方 AI'), findsOneWidget);
    expect(find.text('无收集、无盈利'), findsOneWidget);
  });

  testWidgets('更新日志页是纯本地静态内容', (tester) async {
    await pumpPage(tester, const ChangelogPage());

    expect(find.byType(ChangelogPage), findsOneWidget);
    expect(find.text('7.0 自用化'), findsOneWidget);
    expect(find.text('6.13 持仓信息修正'), findsOneWidget);
    expect(find.text('6.0 记账与导航'), findsOneWidget);
    expect(find.byType(WebViewWidget), findsNothing);
  });

  testWidgets('隐私政策页是纯本地静态内容', (tester) async {
    await pumpPage(tester, const PrivacyPolicyPage());

    expect(find.byType(PrivacyPolicyPage), findsOneWidget);
    expect(find.text('数据存储'), findsOneWidget);
    expect(find.text('第三方 AI'), findsOneWidget);
    expect(find.text('无收集、无盈利'), findsOneWidget);
    expect(find.byType(WebViewWidget), findsNothing);
  });
}
