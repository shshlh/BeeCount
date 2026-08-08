import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/widgets/investment/initial_holding_dialog.dart';

void main() {
  testWidgets('导入初始持仓基金代码 6 位校验', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allAccountsStreamProvider.overrideWith(
            (ref) => Stream.value(const <Account>[]),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showInitialHoldingDialog(
                    context,
                    ledgerId: 1,
                  ),
                  child: const Text('打开导入'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('打开导入'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '11017');
    await tester.tap(find.text('导入'));
    await tester.pumpAndSettle();

    expect(find.text('基金代码必须为6位数字'), findsOneWidget);
  });
}
