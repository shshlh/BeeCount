/// 4.9.1 虚拟账户不显示开户行/卡号后四位 —— 账户编辑页条件渲染钉住:
/// - virtual_account 不显示卡信息区块
/// - bank_card 仍显示开户行/卡号后四位
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/account/account_edit_page.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/providers/theme_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late LocalRepository repo;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
  });

  tearDown(() async => db.close());

  Widget host() {
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        primaryColorProvider.overrideWith((ref) => const Color(0xFFF5A623)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: AccountEditPage(ledgerId: 1),
      ),
    );
  }

  testWidgets('虚拟账户不显示开户行/卡号后四位', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('开户行'), findsNothing);
    expect(find.text('卡号后四位'), findsNothing);

    await tester.tap(find.text('虚拟账户'));
    await tester.pumpAndSettle();

    expect(find.text('开户行'), findsNothing);
    expect(find.text('卡号后四位'), findsNothing);
  });

  testWidgets('银行卡仍显示开户行/卡号后四位', (tester) async {
    // 默认 600px 视口只构建首屏,银行卡信息区在下方;放大视口确保全部构建。
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('银行卡'));
    await tester.pumpAndSettle();

    expect(find.text('开户行'), findsOneWidget);
    expect(find.text('卡号后四位'), findsOneWidget);
  });
}
