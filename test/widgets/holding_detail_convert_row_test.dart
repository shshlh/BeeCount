/// v6.7 返工：转换交易行金额按「确认份额 × 确认净值」展示（amount=0 不回写 DB）
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/investment/holding_detail_page.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/services/data/investment_service.dart';
import 'package:beecount/widgets/biz/amount_text.dart';
import 'package:beecount/widgets/biz/section_card.dart';

void main() {
  InvestmentHolding buildHolding() => InvestmentHolding(
        id: 1,
        ledgerId: 1,
        fundCode: '000001',
        fundName: '基金A',
        accountId: 10,
        totalShares: 500,
        totalCost: 500,
        currentNav: 1.2,
        marketValue: 600,
        holdingType: 'fund',
      isQdii: false,
        createdAt: DateTime(2026),
        navDate: DateTime(2026, 8, 7),
      );

  Widget host(Transaction tx) {
    return ProviderScope(
      overrides: [
        holdingProvider(1).overrideWith((ref) async => buildHolding()),
        holdingTransactionsProvider(1)
            .overrideWith((ref) => Stream.value([tx])),
        holdingReturnProvider(1).overrideWith(
          (ref) async =>
              const HoldingReturn(unrealizedPnL: 100, returnRate: 0.2),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: const HoldingDetailPage(holdingId: 1),
      ),
    );
  }

  testWidgets('转换交易行金额按份额×净值展示', (tester) async {
    final convertTx = Transaction(
      id: 1,
      ledgerId: 1,
      type: 'transfer',
      amount: 0,
      happenedAt: DateTime(2026, 8, 7),
      excludeFromStats: false,
      excludeFromBudget: true,
      investType: 'buy',
      investShares: 500,
      investNav: 1.2,
      investFee: 0,
      holdingId: 1,
      batchId: 'batch-1',
    );

    await tester.pumpWidget(host(convertTx));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(SectionCard), matching: find.text('转换')),
      findsOneWidget,
    );
    expect(find.text('净值（2026.8.7）'), findsOneWidget);
    expect(find.text('净值 1.2'), findsOneWidget);
    final amountTexts = tester.widgetList<AmountText>(find.byType(AmountText));
    expect(amountTexts.any((w) => w.value == 600), isTrue);
  });

  testWidgets('转出侧转换行也显示「转换」并按份额×净值展示', (tester) async {
    final sellTx = Transaction(
      id: 2,
      ledgerId: 1,
      type: 'transfer',
      amount: 0,
      happenedAt: DateTime(2026, 8, 7),
      excludeFromStats: false,
      excludeFromBudget: true,
      investType: 'sell',
      investShares: -500,
      investNav: 1.2,
      investFee: 5,
      holdingId: 1,
      batchId: 'batch-1',
    );

    await tester.pumpWidget(host(sellTx));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(SectionCard), matching: find.text('转换')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(SectionCard), matching: find.text('卖出')),
      findsNothing,
    );
    final amountTexts = tester.widgetList<AmountText>(find.byType(AmountText));
    expect(amountTexts.any((w) => w.value == 600), isTrue);
  });

  testWidgets('买入侧 amount 为转入成本时按实际成本展示', (tester) async {
    final buyTx = Transaction(
      id: 3,
      ledgerId: 1,
      type: 'transfer',
      amount: 590,
      happenedAt: DateTime(2026, 8, 7),
      excludeFromStats: false,
      excludeFromBudget: true,
      investType: 'buy',
      investShares: 480,
      investNav: 1.25,
      investFee: 0,
      holdingId: 1,
      batchId: 'batch-1',
    );

    await tester.pumpWidget(host(buyTx));
    await tester.pumpAndSettle();

    final amountTexts = tester.widgetList<AmountText>(find.byType(AmountText));
    expect(amountTexts.any((w) => w.value == 590), isTrue);
  });
}
