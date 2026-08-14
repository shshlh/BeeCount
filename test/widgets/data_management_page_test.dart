// 7.13.3 数据管理页三分组重构：小标题 + 复用入口。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/settings/data_management_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  testWidgets('数据管理页按三组展示所有入口', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const DataManagementPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('分类与标签'), findsOneWidget);
    expect(find.text('导入与导出'), findsOneWidget);
    expect(find.text('空间与清理'), findsOneWidget);
    // 7.13.4 返工：分类与标签 → 导入与导出 → 空间与清理。
    final categoryY = tester.getTopLeft(find.text('分类与标签')).dy;
    final importExportY = tester.getTopLeft(find.text('导入与导出')).dy;
    final spaceY = tester.getTopLeft(find.text('空间与清理')).dy;
    expect(categoryY, lessThan(importExportY));
    expect(importExportY, lessThan(spaceY));

    // 分类与标签
    expect(find.text('分类管理'), findsOneWidget);
    expect(find.text('分类迁移'), findsOneWidget);
    expect(find.text('标签管理'), findsOneWidget);
    // 导入与导出
    expect(find.text('导入数据'), findsOneWidget);
    expect(find.text('导出数据'), findsOneWidget);
    expect(find.text('导出附件'), findsOneWidget);
    expect(find.text('导入附件'), findsOneWidget);
    expect(find.text('配置导入导出'), findsOneWidget);
    // 空间与清理
    expect(find.text('存储空间管理'), findsOneWidget);
    expect(find.text('数据清理'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
  });
}
