import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/widgets/investment/holding_card.dart';

void main() {
  InvestmentHolding buildHolding({DateTime? navDate}) => InvestmentHolding(
        id: 1,
        ledgerId: 1,
        fundCode: '000001',
        fundName: '基金A',
        accountId: 10,
        totalShares: 100,
        totalCost: 100,
        currentNav: 1.2345,
        marketValue: 123.45,
        holdingType: 'fund',
        createdAt: DateTime(2026),
        navDate: navDate,
      );

  Widget host(InvestmentHolding holding) => ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: HoldingCard(holding: holding)),
        ),
      );

  testWidgets('净值标签带日期、数值独立展示', (tester) async {
    await tester.pumpWidget(
      host(buildHolding(navDate: DateTime(2026, 8, 7))),
    );
    await tester.pumpAndSettle();

    expect(find.text('净值（2026.8.7）'), findsOneWidget);
    expect(find.text('1.2345'), findsOneWidget);
  });

  testWidgets('无净值日期时不显示括号', (tester) async {
    await tester.pumpWidget(host(buildHolding()));
    await tester.pumpAndSettle();

    expect(find.text('净值'), findsOneWidget);
    expect(find.textContaining('（'), findsNothing);
  });
}
