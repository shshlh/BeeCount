// 7.5.1 同名不同币种账户提示优化：账户编辑页重复名提示带建议名(name+币种)，
// 且切换币种后建议名随币种刷新。
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/account/account_edit_page.dart';
import 'package:beecount/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalRepository repo;
  late int ledgerId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    ledgerId = await repo.createLedger(name: 'L', currency: 'CNY');
    await repo.createAccount(
      ledgerId: ledgerId,
      name: '支付宝',
      currency: 'CNY',
    );
  });

  tearDown(() async => db.close());

  Widget host() {
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: AccountEditPage(ledgerId: ledgerId),
      ),
    );
  }

  testWidgets('重复名提示带建议名(名称+币种)，切换币种后刷新', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // 默认币种 CNY：建议名 = 支付宝CNY
    await tester.enterText(find.byType(TextFormField).first, '支付宝');
    await tester.pumpAndSettle();
    expect(
      find.text('该账户名已存在，请更换账户名，如支付宝CNY'),
      findsOneWidget,
    );

    // 切换币种到 USD：建议名随币种刷新为 支付宝USD
    await tester.tap(find.text('人民币 (CNY)'));
    await tester.pumpAndSettle();

    final searchField = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == '搜索：中文或代码',
    );
    await tester.enterText(searchField, 'USD');
    await tester.pumpAndSettle();

    await tester.tap(find.text('美元 (USD)'));
    await tester.pumpAndSettle();

    expect(
      find.text('该账户名已存在，请更换账户名，如支付宝USD'),
      findsOneWidget,
    );
  });
}
