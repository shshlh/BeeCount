// 7.14 账户详情页：全部/支出/收入 tab 切换 + 「全部」逐笔余额展示。
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/account/account_detail_page.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/widgets/charts/account_category_pie_chart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late LocalRepository repo;
  late Account account;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    final ledgerId = await repo.createLedger(name: 'L', currency: 'CNY');
    account = (await repo.getAccount(
        await repo.createAccount(
      ledgerId: ledgerId,
      name: '钱包',
      type: 'cash',
      currency: 'CNY',
      initialBalance: 1000,
    )))!;
    final otherId = await repo.createAccount(
      ledgerId: ledgerId,
      name: '投资账户',
      type: 'investment',
      currency: 'CNY',
    );
    await repo.createCategory(name: '餐饮', kind: 'expense');
    await repo.createCategory(name: '工资', kind: 'income');
    await repo.addTransaction(
      ledgerId: ledgerId,
      type: 'income',
      amount: 500,
      accountId: account.id,
      happenedAt: DateTime(2026, 8, 3),
    );
    await repo.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 100,
      accountId: account.id,
      happenedAt: DateTime(2026, 8, 2),
    );
    await repo.addTransaction(
      ledgerId: ledgerId,
      type: 'transfer',
      amount: 200,
      accountId: account.id,
      toAccountId: otherId,
      happenedAt: DateTime(2026, 8, 1),
    );
  });

  tearDown(() async => db.close());

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          // 避免 Drift StreamProvider 在测试 teardown 挂起。
          ledgersStreamProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: AccountDetailPage(account: account),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('默认全部：无分布图；切支出/收入显示分布图；全部显示逐笔余额',
      (tester) async {
    await pumpPage(tester);

    expect(find.text('全部'), findsOneWidget);
    expect(find.text('支出'), findsWidgets);
    expect(find.text('收入'), findsWidgets);
    expect(find.byType(AccountCategoryPieChart), findsNothing);
    // 全部模式逐笔余额：收入后 1200 / 支出后 700 / 转出后 800。
    expect(find.text('余额 1200.00'), findsOneWidget);
    expect(find.text('余额 700.00'), findsOneWidget);
    expect(find.text('余额 800.00'), findsOneWidget);

    await tester.tap(find.text('支出').at(1));
    await tester.pumpAndSettle();
    expect(find.byType(AccountCategoryPieChart), findsOneWidget);

    await tester.tap(find.text('收入').at(1));
    await tester.pumpAndSettle();
    expect(find.byType(AccountCategoryPieChart), findsOneWidget);

    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountCategoryPieChart), findsNothing);
    // 冲掉 logger 的 2 秒节流定时器。
    await tester.pump(const Duration(seconds: 3));
  });
}
