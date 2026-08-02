/// v5.3 资产金额精度：AmountText 关闭紧凑格式后不显示万单位
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/widgets/biz/amount_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('useCompactFormat=false 显示完整金额,不含万/k/M', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: const MaterialApp(
          home: Scaffold(
            body: AmountText(
              value: 123456789,
              signed: false,
              showCurrency: true,
              useCompactFormat: false,
              currencyCode: 'CNY',
            ),
          ),
        ),
      ),
    );

    expect(find.text('¥123,456,789'), findsOneWidget);
    expect(find.textContaining('万'), findsNothing);
    expect(find.textContaining('k'), findsNothing);
    expect(find.textContaining('M'), findsNothing);
  });
}
