import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/ai/core/financial_analyst_context.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_investment_repository.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/ai/ai_chat_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalRepository repo;
  late LocalInvestmentRepository investRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    investRepo = LocalInvestmentRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('意图路由', () {
    test('投资问题优先识别为分析，不误判为记账', () {
      expect(AIChatService.isAnalystIntent('我的基金浮盈多少'), isTrue);
      expect(AIChatService.isTransactionIntent('我的基金浮盈多少'), isFalse);
    });

    test('普通记账仍走记账意图', () {
      expect(AIChatService.isAnalystIntent('买了杯奶茶28块'), isFalse);
      expect(AIChatService.isTransactionIntent('买了杯奶茶28块'), isTrue);
    });

    test('资产/负债/趋势/预算等关键词命中分析', () {
      expect(AIChatService.isAnalystIntent('这个月预算超了吗'), isTrue);
      expect(AIChatService.isAnalystIntent('净资产趋势如何'), isTrue);
      expect(AIChatService.isAnalystIntent('我的组合盈亏'), isTrue);
    });
  });

  group('分析师提示词', () {
    test('prompt 含投资摘要且移除旧「暂不支持」文案', () async {
      final ledgerId = await repo.createLedger(name: '测试账本', currency: 'CNY');
      final investAccountId = await repo.createAccount(
        ledgerId: ledgerId,
        name: '投资账户',
        type: 'investment',
        currency: 'CNY',
      );
      await investRepo.buy(
        ledgerId: ledgerId,
        accountId: investAccountId,
        fundCode: '000001',
        fundName: '华夏成长混合',
        amount: 1500,
        shares: 1000,
        nav: 1.5,
        happenedAt: DateTime.now().subtract(const Duration(days: 2)),
      );

      final snapshot = await FinancialAnalystContext.forLedger(
        repository: repo,
        investmentRepository: investRepo,
        ledgerId: ledgerId,
      );
      final prompt = AIChatService.buildAnalystSystemPrompt(snapshot: snapshot);

      expect(prompt, contains('财务分析师'));
      expect(prompt, contains('华夏成长混合'));
      expect(prompt, isNot(contains('暂不支持')));
    });

    test('空数据兜底', () {
      final prompt = AIChatService.buildAnalystSystemPrompt(
        snapshot: FinancialAnalystSnapshot.empty,
      );

      expect(prompt, contains('财务分析师'));
      expect(prompt, contains('无持仓'));
    });

    test('英文 prompt 使用分析师人设', () {
      final prompt = AIChatService.buildAnalystSystemPrompt(
        snapshot: FinancialAnalystSnapshot.empty,
        languageCode: 'en',
      );

      expect(prompt.toLowerCase(), contains('financial analyst'));
    });
  });
}
