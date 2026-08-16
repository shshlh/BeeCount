// 7.13.7 搜索页转账流水显示对齐流水页：转出 → 转入、金额无正负号。
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/transaction/search_page.dart';
import 'package:beecount/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late _FakeTxRepo repo;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = _FakeTxRepo(db);
  });

  tearDown(() async => db.close());

  testWidgets('转账搜索结果展示转出→转入且金额无正负号', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          // 避免 TransactionListItem 里 currentLedgerProvider 的 Drift 流
          // 在测试销毁时留下零时长 Timer。
          currentLedgerProvider
              .overrideWith((ref) => Stream<Ledger?>.value(null)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const SearchPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '转账备注');
    await tester.pumpAndSettle();

    expect(find.textContaining('钱包 → 投资账户'), findsOneWidget);
    expect(find.textContaining('+100'), findsNothing);
    expect(find.textContaining('100'), findsWidgets);
  });
}

class _FakeTxRepo extends LocalRepository {
  _FakeTxRepo(super.db);

  @override
  Stream<
      List<
          ({
            Transaction t,
            Category? category,
            Account? account,
            Account? toAccount
          })>> transactionsWithCategoryAll({int? ledgerId}) {
    return Stream.value([
      (
        t: Transaction(
          id: 1,
          ledgerId: 1,
          type: 'transfer',
          amount: 100,
          happenedAt: DateTime(2026, 8, 1),
          note: '转账备注',
          accountId: 1,
          toAccountId: 2,
          excludeFromStats: false,
          excludeFromBudget: false,
        ),
        category: null,
        account: Account(
          id: 1,
          ledgerId: 1,
          name: '钱包',
          type: 'cash',
          currency: 'CNY',
          initialBalance: 0,
          sortOrder: 0,
          hidden: false,
          excludeFromAssets: false,
          isOffBalance: false,
        ),
        toAccount: Account(
          id: 2,
          ledgerId: 1,
          name: '投资账户',
          type: 'investment',
          currency: 'CNY',
          initialBalance: 0,
          sortOrder: 0,
          hidden: false,
          excludeFromAssets: false,
          isOffBalance: false,
        ),
      ),
    ]);
  }
}
