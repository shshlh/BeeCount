import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/widgets/investment/buy_dialog.dart';

void main() {
  testWidgets('买入弹窗基金代码 6 位校验', (tester) async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, type, currency) "
        "VALUES (10, 1, '钱包', 'cash', 'CNY')");

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(LocalRepository(db)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const BuyDialog(ledgerId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '11017');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(find.text('基金代码必须为6位数字'), findsOneWidget);
  });

  testWidgets('买入弹窗显示确认净值日期（7.19.1）', (tester) async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, type, currency) "
        "VALUES (10, 1, '钱包', 'cash', 'CNY')");

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(LocalRepository(db)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const BuyDialog(ledgerId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('确认净值日期'), findsOneWidget);
    expect(find.text('QDII 基金'), findsOneWidget);
  });

  testWidgets('已有 QDII 持仓时买入弹窗回填开关（7.19.5）', (tester) async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");

    final holding = InvestmentHolding(
      id: 1,
      ledgerId: 1,
      fundCode: '000001',
      fundName: 'QDII 基金',
      accountId: 10,
      totalShares: 100,
      totalCost: 100,
      currentNav: 1.0,
      marketValue: 100,
      holdingType: 'fund',
      isQdii: true,
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(LocalRepository(db)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: BuyDialog(ledgerId: 1, holding: holding),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggle.value, isTrue);
  });
}
