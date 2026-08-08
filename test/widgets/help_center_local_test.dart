import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart' show WebViewWidget;

import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/ai/ai_tutorial_page.dart';
import 'package:beecount/pages/settings/cloud_sync_guide_page.dart';
import 'package:beecount/pages/settings/help_center_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  testWidgets('帮助中心为本地静态页并覆盖主要模块', (tester) async {
    await pumpPage(tester, const HelpCenterPage());

    expect(find.byType(HelpCenterPage), findsOneWidget);
    expect(find.text('本地使用说明'), findsOneWidget);
    expect(find.text('基础记账'), findsOneWidget);
    expect(find.text('投资模块'), findsOneWidget);
    expect(find.text('导入导出'), findsOneWidget);
    expect(find.text('云同步'), findsOneWidget);
    expect(find.text('小组件'), findsOneWidget);
    expect(find.text('AI 记账'), findsOneWidget);
    expect(find.byType(WebViewWidget), findsNothing);
  });

  testWidgets('云同步设置说明为本地静态页', (tester) async {
    await pumpPage(tester, const CloudSyncGuidePage());

    expect(find.byType(CloudSyncGuidePage), findsOneWidget);
    expect(find.text('云同步设置说明'), findsOneWidget);
    expect(find.text('自定义 Supabase'), findsOneWidget);
    expect(find.text('自定义 WebDAV'), findsOneWidget);
    expect(find.text('BeeCount Cloud'), findsOneWidget);
    expect(find.text('S3 协议存储'), findsOneWidget);
    expect(find.byType(WebViewWidget), findsNothing);
  });

  testWidgets('AI 设置与使用说明为本地静态页', (tester) async {
    await pumpPage(tester, const AiTutorialPage());

    expect(find.byType(AiTutorialPage), findsOneWidget);
    expect(find.text('AI 设置与使用'), findsOneWidget);
    expect(find.text('服务商配置'), findsOneWidget);
    expect(find.text('能力绑定'), findsOneWidget);
    expect(find.text('图片 / 拍照记账'), findsOneWidget);
    expect(find.text('语音记账'), findsOneWidget);
    expect(find.text('截图自动识别'), findsOneWidget);
    expect(find.byType(WebViewWidget), findsNothing);
  });
}
