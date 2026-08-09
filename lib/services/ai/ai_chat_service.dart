import '../../ai/core/bill_info.dart';
import '../../ai/core/financial_analyst_context.dart';
import '../../ai/providers/ai_provider_config.dart';
import '../../ai/providers/ai_provider_factory.dart';
import '../../ai/providers/ai_provider_manager.dart';
import '../../data/repositories/base_repository.dart';
import '../../data/repositories/investment_repository.dart';
import '../../l10n/app_localizations.dart';
import '../data/tag_seed_service.dart';
import '../system/logger_service.dart';
import 'ai_bookkeeper.dart';

/// AI 对话服务
///
/// 两种模式:
/// 1. **对话记账** —— 委托给 [AiBookkeeper.fromText],返回带卡片的 AIResponse
/// 2. **自由对话** —— 直接调 [AIProviderFactory.chat]
///
/// 这个 service 现在只剩**意图判定 + 调用编排**,真正的提取/落库逻辑全在
/// [AiBookkeeper] 里。
class AIChatService {
  final BaseRepository _repo;
  final InvestmentRepository _investmentRepository;
  final AiBookkeeper _bookkeeper;

  AIChatService({
    required BaseRepository repo,
    required InvestmentRepository investmentRepository,
    required AiBookkeeper bookkeeper,
  })  : _repo = repo,
        _investmentRepository = investmentRepository,
        _bookkeeper = bookkeeper;

  /// 验证 AI 配置是否存在(仅本地配置,不发网络请求)
  static Future<AIConfigValidationResult> validateApiKey() async {
    final config = await AIProviderManager.getProviderForCapability(
      AICapabilityType.text,
    );
    if (config == null) {
      return AIConfigValidationResult.invalid('未配置文本对话服务商');
    }
    if (!config.isValid) {
      return AIConfigValidationResult.invalid('未配置 API Key');
    }
    if (!config.supportsText) {
      return AIConfigValidationResult.invalid('未配置文本模型');
    }
    return AIConfigValidationResult.valid();
  }

  /// 处理用户消息
  Future<AIResponse> processMessage(
    String userInput, {
    required int ledgerId,
    String? languageCode,
    bool forceChat = false,
    AppLocalizations? l10n,
  }) async {
    logger.info('AIChat', '收到消息: $userInput (forceChat: $forceChat)');
    try {
      // 财务分析意图优先于记账意图：投资/持仓/收益等问题不误判为记账。
      if (!forceChat && isAnalystIntent(userInput)) {
        return await _handleFreeChat(
          userInput,
          ledgerId: ledgerId,
          languageCode: languageCode,
        );
      }
      if (!forceChat && isTransactionIntent(userInput)) {
        return await _handleTransaction(
          userInput,
          ledgerId: ledgerId,
          l10n: l10n,
        );
      }
      return await _handleFreeChat(
        userInput,
        ledgerId: ledgerId,
        languageCode: languageCode,
      );
    } catch (e, st) {
      logger.error('AIChat', '处理失败', e, st);
      return AIResponse.error('抱歉,处理失败,请重试');
    }
  }

  /// 撤销记账(给 UI 卡片上的「撤销」按钮用)
  Future<bool> undoTransaction(int transactionId) async {
    try {
      await _repo.deleteTransaction(transactionId);
      logger.info('AIChat', '撤销记账: id=$transactionId');
      return true;
    } catch (e, st) {
      logger.error('AIChat', '撤销失败', e, st);
      return false;
    }
  }

  // ============================================================
  // 内部
  // ============================================================

  /// 财务分析意图关键词。命中后优先走自由对话（分析师），不进入记账提取。
  static bool isAnalystIntent(String input) {
    const keywords = [
      '投资',
      '持仓',
      '收益',
      '盈亏',
      '基金',
      '股票',
      '分析',
      '复盘',
      '趋势',
      '预算',
      '净资产',
      '资产',
      '负债',
      '浮盈',
      '浮亏',
      '组合',
    ];
    return keywords.any(input.contains);
  }

  static bool isTransactionIntent(String input) {
    final hasAmount = RegExp(r'\d+(?:\.\d+)?').hasMatch(input);
    const keywords = ['买', '花', '消费', '支付', '记账', '付', '收入', '赚', '工资'];
    final hasKeyword = keywords.any((k) => input.contains(k));
    return hasAmount || hasKeyword;
  }

  Future<AIResponse> _handleTransaction(
    String input, {
    required int ledgerId,
    AppLocalizations? l10n,
  }) async {
    logger.debug('AIChat', '识别为记账意图');
    final result = await _bookkeeper.fromText(
      text: input,
      ledgerId: ledgerId,
      billingTypes: [TagSeedService.billingTypeAi],
      l10n: l10n,
    );

    if (!result.success) {
      logger.warning('AIChat', '账单提取失败或全部无有效金额');
      return AIResponse.text(
        '抱歉,未识别到完整的记账信息。\n\n'
        '请这样说:\n'
        '• 买了杯奶茶28块\n'
        '• 今天午餐花了50\n'
        '• 打车回家花了35',
      );
    }

    logger.info('AIChat', '账单提取成功: ${result.savedCount} 笔');
    return AIResponse.billCards(result.savedBills, result.transactionIds);
  }

  Future<AIResponse> _handleFreeChat(
    String input, {
    required int ledgerId,
    String? languageCode,
  }) async {
    logger.info('AIChat', '开始自由对话 (语言: ${languageCode ?? "默认"})');
    try {
      FinancialAnalystSnapshot snapshot;
      try {
        snapshot = await FinancialAnalystContext.forLedger(
          repository: _repo,
          investmentRepository: _investmentRepository,
          ledgerId: ledgerId,
        );
      } catch (e) {
        logger.warning('AIChat', '财务上下文构建失败，使用空兜底', e);
        snapshot = FinancialAnalystSnapshot.empty;
      }

      final systemPrompt = buildAnalystSystemPrompt(
        snapshot: snapshot,
        languageCode: languageCode,
      );

      final response = await AIProviderFactory.chat(
        input,
        systemPrompt: systemPrompt,
        logTag: 'AIChat',
      );
      logger.info('AIChat', '对话响应成功');
      return AIResponse.text(response);
    } on AIException catch (e) {
      logger.warning('AIChat', '对话响应失败: ${e.message}');
      if (e.message.contains('配置无效')) {
        return AIResponse.error(
          '需要配置 API Key 才能使用对话功能。\n\n前往 设置 > AI设置 进行配置。',
        );
      }
      return AIResponse.error('AI服务暂时不可用,请稍后重试');
    } catch (e, st) {
      logger.error('AIChat', '自由对话失败', e, st);
      return AIResponse.error('网络连接失败,请检查网络');
    }
  }

  /// 财务分析师系统提示词：只基于注入的账本/投资摘要回答，不臆造数据。
  static String buildAnalystSystemPrompt({
    required FinancialAnalystSnapshot snapshot,
    String? languageCode,
  }) {
    final isEn = languageCode == 'en';
    final persona = isEn
        ? 'You are the financial analyst of this bookkeeping app. '
            'Answer questions based only on the ledger and investment snapshot below. '
            'Do not invent data that is not provided; state clearly when data is insufficient. '
            'Please respond in English.'
        : '你是记账助手的财务分析师。请只基于下面提供的账本与投资摘要回答问题，'
            '未提供的数据不要臆造，数据不足时明确说明。请用中文回复。';
    return '$persona\n\n${snapshot.toPromptText()}';
  }
}

/// AI 配置验证结果
class AIConfigValidationResult {
  final bool isValid;
  final String? errorMessage;

  AIConfigValidationResult({
    required this.isValid,
    this.errorMessage,
  });

  factory AIConfigValidationResult.valid() {
    return AIConfigValidationResult(isValid: true);
  }

  factory AIConfigValidationResult.invalid(String message) {
    return AIConfigValidationResult(isValid: false, errorMessage: message);
  }
}

/// AI 对话响应模型
class AIResponse {
  final String type; // 'text' | 'bill_card' | 'error'
  final String text;

  /// 所有识别到的账单(单笔/多笔都用 list)
  final List<BillInfo> bills;

  /// 与 [bills] 一一对应的交易 ID
  final List<int> transactionIds;

  AIResponse({
    required this.type,
    required this.text,
    this.bills = const [],
    this.transactionIds = const [],
  });

  /// 首个 BillInfo(兼容写入 messages.transactionId 列)
  BillInfo? get billInfo => bills.isNotEmpty ? bills.first : null;

  /// 首个交易 ID
  int? get transactionId =>
      transactionIds.isNotEmpty ? transactionIds.first : null;

  factory AIResponse.text(String text) => AIResponse(type: 'text', text: text);

  /// 多笔/单笔统一入口。bills 与 txIds 必须等长且非空。
  factory AIResponse.billCards(List<BillInfo> bills, List<int> txIds) {
    assert(bills.length == txIds.length && bills.isNotEmpty,
        'bills/txIds 必须等长且非空');
    final n = bills.length;
    return AIResponse(
      type: 'bill_card',
      text: n == 1 ? '✅ 记账成功' : '✅ 已记账 $n 笔',
      bills: List.unmodifiable(bills),
      transactionIds: List.unmodifiable(txIds),
    );
  }

  factory AIResponse.error(String message) =>
      AIResponse(type: 'error', text: message);
}
