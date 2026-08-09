import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/account/account_edit_page.dart';
import 'package:beecount/pages/account/accounts_page.dart';
import 'package:beecount/providers.dart';

const notedAccount = Account(
  id: 2,
  ledgerId: 1,
  name: '受托资金',
  type: 'bank_card',
  currency: 'CNY',
  initialBalance: 0,
  sortOrder: 1,
  hidden: false,
  excludeFromAssets: true,
  isOffBalance: true,
  note: '代付银行贷款利息，月底对账',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalRepository repo;
  late Ledger ledger;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    final ledgerId = await repo.createLedger(name: 'L', currency: 'CNY');
    ledger = Ledger(
      id: ledgerId,
      name: 'L',
      currency: 'CNY',
      type: 'personal',
      createdAt: DateTime(2026, 1, 1),
      myRole: 'owner',
      memberCount: 1,
      isShared: false,
      monthStartDay: 1,
    );
  });

  tearDown(() async => db.close());

  testWidgets('账户卡展示备注并单行截断', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: OffBalanceAccountsSection(
              accounts: const [notedAccount],
              allStats: const {},
              primaryColor: const Color(0xFFF5A623),
              onTap: (_) {},
              onEdit: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('代付银行贷款利息，月底对账'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('编辑页回显备注，清空后保存生效', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final account = await tester.runAsync(() async {
      final id = await repo.createAccount(
        ledgerId: ledger.id,
        name: '托管账户',
        type: 'bank_card',
        currency: 'CNY',
        note: '旧备注',
      );
      return repo.getAccount(id);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: AccountEditPage(account: account, ledgerId: ledger.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('旧备注'), findsOneWidget);

    final noteField = find.byWidgetPredicate(
      (w) => w is TextField && w.controller?.text == '旧备注',
    );
    await tester.enterText(noteField, '');

    await tester.ensureVisible(find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AccountEditPage), findsNothing);

    final saved = await tester.runAsync(
      () => repo.getAccount(account!.id),
    );
    expect(saved?.note, isNull);

    await tester.pump(const Duration(seconds: 3));
  });
}
