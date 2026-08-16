// 7.15.2 账户详情页流水：投资流水显示基金标识、普通流水不显示、账本标签移除。
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_investment_repository.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/account/account_detail_page.dart';
import 'package:beecount/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late LocalRepository repo;
  late LocalInvestmentRepository investmentRepo;
  late Account account;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    investmentRepo = LocalInvestmentRepository(db);
    final ledgerId = await repo.createLedger(name: 'L', currency: 'CNY');
    account = (await repo.getAccount(await repo.createAccount(
      ledgerId: ledgerId,
      name: '钱包',
      type: 'cash',
      currency: 'CNY',
      initialBalance: 1000,
    )))!;
    final investmentId = await repo.createAccount(
      ledgerId: ledgerId,
      name: '投资账户',
      type: 'investment',
      currency: 'CNY',
    );
    await investmentRepo.buy(
      ledgerId: ledgerId,
      accountId: investmentId,
      sourceAccountId: account.id,
      fundCode: '000001',
      fundName: '基金A',
      amount: 1000,
      shares: 1000,
      nav: 1.0,
      happenedAt: DateTime(2026, 8, 2),
    );
    await repo.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 30,
      accountId: account.id,
      happenedAt: DateTime(2026, 8, 1),
    );
  });

  tearDown(() async => db.close());

  testWidgets('投资流水显示基金标识，普通流水不显示，账本标签移除', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          investmentRepositoryProvider.overrideWithValue(investmentRepo),
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

    // 投资流水基金标识
    expect(find.text('000001 基金A'), findsOneWidget);
    // 普通流水不显示基金标识（全页仅投资流水一个基金标识）
    expect(find.textContaining('基金A'), findsOneWidget);
    // 账本标签已移除
    expect(find.text('L'), findsNothing);

    // 冲掉 logger 的 2 秒节流定时器。
    await tester.pump(const Duration(seconds: 3));
  });
}
