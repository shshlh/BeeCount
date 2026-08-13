// 7.11.2 账户列表按账本过滤：accounts_page 只显示当前账本账户。
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/account/accounts_page.dart';
import 'package:beecount/providers.dart';

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
        currentLedgerIdProvider.overrideWith((ref) => ledgerId),
        currentLedgerProvider
            .overrideWith((ref) => Stream<Ledger?>.value(ledger)),
        // 避开 Drift QueryStream 在 dispose 时的零时长 Timer。
        accountsStreamProvider.overrideWith((ref, targetLedgerId) async* {
          final all = await repo.getAllAccounts();
          yield all
              .where((a) => a.ledgerId == targetLedgerId)
              .toList();
        }),
        assetCompositionForLedgerProvider.overrideWith(
            (ref, targetLedgerId) async {
          final all = await repo.getAllAccounts();
          final accounts = all
              .where((a) =>
                  a.ledgerId == targetLedgerId && !a.excludeFromAssets)
              .toList();
          final balances = await repo.getAllAccountBalances(targetLedgerId);
          final byType = <String, double>{};
          for (final a in accounts) {
            final balance = balances[a.id] ?? 0;
            byType.update(
                a.type, (v) => v + balance, ifAbsent: () => balance);
          }
          return byType.entries
              .map((e) => (type: e.key, totalBalance: e.value))
              .toList();
        }),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: const AccountsPage(),
      ),
    );
  }

  Future<void> pumpLedger(WidgetTester tester, int ledgerId) async {
    await tester.pumpWidget(wrap(ledgerId));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('账本1只显示账本1账户', (tester) async {
    await pumpLedger(tester, ledger1);
    expect(find.text('现金L1'), findsOneWidget);
    expect(find.text('现金L2'), findsNothing);
    // 冲掉汇率刷新 / logger 的 pending Timer。
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('账本2只显示账本2账户', (tester) async {
    await pumpLedger(tester, ledger2);
    expect(find.text('现金L2'), findsOneWidget);
    expect(find.text('现金L1'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });
}
