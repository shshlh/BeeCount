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
        isQdii: false,
        createdAt: DateTime(2026),
        navDate: navDate,
      );

  Widget host(InvestmentHolding holding) => ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: HoldingCard(holding: holding)),
        ),
      );

  testWidgets('v3 卡片头部展示代码/市值，不再展示净值', (tester) async {
    await tester.pumpWidget(
      host(buildHolding(navDate: DateTime(2026, 8, 7))),
    );
    await tester.pumpAndSettle();

    expect(find.text('000001'), findsOneWidget);
    expect(find.text('市值'), findsOneWidget);
    expect(find.text('净值'), findsNothing);
    expect(find.textContaining('净值（'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('无净值日期时列表卡片同样不显示净值', (tester) async {
    await tester.pumpWidget(host(buildHolding()));
    await tester.pumpAndSettle();

    expect(find.text('市值'), findsOneWidget);
    expect(find.text('净值'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });
}
