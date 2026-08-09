import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/models/ai_quick_command.dart';

void main() {
  group('AIQuickCommands 7.2.3', () {
    test('包含投资概览 / 持仓分析 / 本月复盘', () {
      final commands = AIQuickCommands.getAllCommands();
      expect(
        commands.map((c) => c.id),
        containsAll([
          'investment_overview',
          'holding_analysis',
          'month_review',
        ]),
      );
    });

    test('投资类指令使用财务分析师上下文数据源', () {
      expect(
        AIQuickCommands.investmentOverview.requiredData,
        contains(QuickCommandDataType.analystSnapshot),
      );
      expect(
        AIQuickCommands.holdingAnalysis.requiredData,
        contains(QuickCommandDataType.analystSnapshot),
      );
      expect(
        AIQuickCommands.monthReview.requiredData,
        contains(QuickCommandDataType.analystSnapshot),
      );
    });
  });
}
