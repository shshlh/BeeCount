import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/main/transaction_list_page.dart';
import 'package:beecount/pages/transaction/transaction_editor_page.dart';
import 'package:beecount/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late _StaticTxRepo repo;
  late Ledger ledger;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = _StaticTxRepo(db);
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

  testWidgets('明细页有 + 入口并进入记账页', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          currentLedgerProvider
              .overrideWith((ref) => Stream<Ledger?>.value(ledger)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const TransactionListPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('记一笔'), findsOneWidget);
    expect(find.byTooltip('搜索'), findsOneWidget);

    await tester.tap(find.byTooltip('记一笔'));
    await tester.pumpAndSettle();

    expect(find.byType(TransactionEditorPage), findsOneWidget);
  });
}

class _StaticTxRepo extends LocalRepository {
  _StaticTxRepo(super.db);

  @override
  Stream<
      List<
          ({
            Transaction t,
            Category? category,
            Account? account,
            Account? toAccount
          })>> transactionsWithCategoryAll({int? ledgerId}) {
    return Stream.value(const []);
  }
}
