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

const offBalanceAccount = Account(
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
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalRepository repo;
  late Ledger ledger;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'account_feature_enabled': true});
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

  testWidgets('账户编辑页表外开关与不计入资产联动', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final account = await tester.runAsync(() async {
      final accountId = await repo.createAccount(
        ledgerId: ledger.id,
        name: '托管账户',
        type: 'bank_card',
        currency: 'CNY',
      );
      return repo.getAccount(accountId);
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    List<Switch> switches() =>
        tester.widgetList<Switch>(find.byType(Switch)).toList();

    expect(find.text('表外/受托账户'), findsOneWidget);
    expect(switches().first.value, isFalse);
    expect(switches()[1].value, isFalse);

    // 开启表外 → 强制不计入资产
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(switches().first.value, isTrue);
    expect(switches()[1].value, isTrue);

    // 取消不计入资产 → 同步关闭表外
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    expect(switches().first.value, isFalse);
    expect(switches()[1].value, isFalse);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('资产页表外账户单独分区并显示标识', (tester) async {
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
              accounts: const [offBalanceAccount],
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

    expect(find.text('表外/受托账户（1）'), findsOneWidget);
    expect(find.text('受托资金'), findsOneWidget);
    expect(find.text('表外/受托'), findsWidgets);

    await tester.pump(const Duration(seconds: 3));
  });

  test('资产/负债分组过滤掉表外与隐藏账户', () {
    const normal = Account(
      id: 1,
      ledgerId: 1,
      name: '日常银行卡',
      type: 'bank_card',
      currency: 'CNY',
      initialBalance: 0,
      sortOrder: 0,
      hidden: false,
      excludeFromAssets: false,
      isOffBalance: false,
    );
    const hidden = Account(
      id: 3,
      ledgerId: 1,
      name: '已隐藏',
      type: 'cash',
      currency: 'CNY',
      initialBalance: 0,
      sortOrder: 2,
      hidden: true,
      excludeFromAssets: false,
      isOffBalance: false,
    );

    final visible = inUseAccountsExcludingOffBalance(
        const [normal, offBalanceAccount, hidden]);

    expect(visible, [normal]);
  });
}
