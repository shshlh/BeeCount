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

void main() {
  testWidgets('转换交易行金额按份额×净值展示', (tester) async {
    final holding = InvestmentHolding(
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
      createdAt: DateTime(2026),
    );
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          holdingProvider(1).overrideWith((ref) async => holding),
          holdingTransactionsProvider(1)
              .overrideWith((ref) => Stream.value([convertTx])),
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
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('转换'), findsOneWidget);
    expect(find.text('净值 1.2'), findsOneWidget);
    final amountTexts = tester.widgetList<AmountText>(find.byType(AmountText));
    expect(amountTexts.any((w) => w.value == 600), isTrue);
  });
}
