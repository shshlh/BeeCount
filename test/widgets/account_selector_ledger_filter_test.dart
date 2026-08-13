// 7.10.1 账户强绑定账本：切换账本后账户选择器只显示当前账本账户。
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/widgets/biz/account_selector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late LocalRepository repo;
  late int ledger1;
  late int ledger2;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    ledger1 = await repo.createLedger(name: 'L1', currency: 'CNY');
    ledger2 = await repo.createLedger(name: 'L2', currency: 'CNY');
    await repo.createAccount(
        ledgerId: ledger1, name: '现金L1', type: 'cash', currency: 'CNY');
    await repo.createAccount(
        ledgerId: ledger2, name: '现金L2', type: 'cash', currency: 'CNY');
  });

  tearDown(() async => db.close());

  Widget wrap(int ledgerId) {
    final ledger = Ledger(
      id: ledgerId,
      name: ledgerId == ledger1 ? 'L1' : 'L2',
      currency: 'CNY',
      type: 'personal',
      createdAt: DateTime(2026, 1, 1),
      myRole: 'owner',
      memberCount: 1,
      isShared: false,
      monthStartDay: 1,
    );
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        currentLedgerProvider
            .overrideWith((ref) => Stream<Ledger?>.value(ledger)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: AccountSelector(
            key: ValueKey('selector-$ledgerId'),
            selectedAccountId: null,
            onAccountSelected: (_) {},
            ledgerId: ledgerId,
          ),
        ),
      ),
    );
  }

  testWidgets('账本1只显示账本1账户，切到账本2只显示账本2账户', (tester) async {
    await tester.pumpWidget(wrap(ledger1));
    await tester.pumpAndSettle();
    expect(find.text('现金L1'), findsOneWidget);
    expect(find.text('现金L2'), findsNothing);

    await tester.pumpWidget(wrap(ledger2));
    await tester.pumpAndSettle();
    expect(find.text('现金L2'), findsOneWidget);
    expect(find.text('现金L1'), findsNothing);
    // 冲掉 AccountSelector logger 的 2 秒节流定时器。
    await tester.pump(const Duration(seconds: 3));
  });
}
