import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/models/ai_quick_command.dart';
import 'package:beecount/widgets/ai/ai_quick_commands_bar.dart';

void main() {
  testWidgets('快捷指令横条展示投资概览 / 持仓分析 / 本月复盘', (tester) async {
    tester.view.physicalSize = const Size(2400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const Scaffold(
            body: AIQuickCommandsBar(
              onCommandTap: _noop,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('投资概览'), findsOneWidget);
    expect(find.text('持仓分析'), findsOneWidget);
    expect(find.text('本月复盘'), findsOneWidget);
  });
}

void _noop(AIQuickCommand command) {}
