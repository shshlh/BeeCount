import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../../styles/tokens.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/amount_text.dart';
import '../../widgets/biz/section_card.dart';
import '../../widgets/investment/holding_card.dart';
import '../../services/data/investment_service.dart';
import 'holding_detail_page.dart';
import '../../widgets/investment/buy_dialog.dart';
import '../../widgets/investment/initial_holding_dialog.dart';

/// 持仓列表页 — 展示当前账本下所有投资持仓。
///
/// v4.7: 导入初始持仓按钮常驻顶部（不仅限于空态）。
///
/// 功能：
/// - 顶部组合摘要卡片（总市值/总成本/盈亏/收益率/持仓数）
/// - v4.7: 导入初始持仓按钮（常驻，摘要卡片下方）
/// - 持仓卡片列表（基金名称、代码、份额、市值、盈亏）
/// - 下拉刷新（刷新净值数据）
/// - 空状态提示（无持仓时）
class HoldingsListPage extends ConsumerWidget {
  /// 是否作为 Tab 嵌入底部导航（asTab=true 时不显示返回按钮）。
  final bool asTab;
  const HoldingsListPage({super.key, this.asTab = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holdingsAsync = ref.watch(currentHoldingsProvider);
    final summaryAsync = ref.watch(portfolioSummaryProvider);

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: '投资持仓',
            showBack: !asTab,
            compact: true,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(currentHoldingsProvider);
                ref.invalidate(portfolioSummaryProvider);
                await Future.delayed(const Duration(milliseconds: 300));
              },
              child: holdingsAsync.when(
                skipLoadingOnReload: true,
                data: (holdings) {
                  if (holdings.isEmpty) {
                    return _buildEmptyState(context, ref);
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      BeeDimens.p12,
                      BeeDimens.p8,
                      BeeDimens.p12,
                      BeeDimens.p12,
                    ),
                    itemCount: holdings.length + 2, // +1 摘要卡片 +1 导入按钮（v4.7）
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: BeeDimens.p8),
                          child: _buildSummaryCard(context, ref, summaryAsync),
                        );
                      }
                      if (index == 1) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: BeeDimens.p8),
                          child: _buildImportButton(context, ref),
                        );
                      }
                      final holding = holdings[index - 2];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: BeeDimens.p8),
                        child: HoldingCard(
                          holding: holding,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HoldingDetailPage(holdingId: holding.id),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                  child: Text(
                    '加载失败：$err',
                    style: TextStyle(color: BeeTokens.textSecondary(context)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// v4.7: 导入初始持仓按钮（常驻，在摘要卡片下方）
  Widget _buildImportButton(BuildContext context, WidgetRef ref) {
    final primaryColor = ref.watch(primaryColorProvider);
    return SectionCard(
      padding: const EdgeInsets.all(BeeDimens.p12),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          final result = await showInitialHoldingDialog(
            context,
            ledgerId: ref.read(currentLedgerIdProvider),
          );
          if (result == true) {
            ref.invalidate(currentHoldingsProvider);
            ref.invalidate(portfolioSummaryProvider);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.file_upload_outlined,
                  size: 18, color: primaryColor),
              const SizedBox(width: 8),
              Text(
                '导入初始持仓',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 空态：暂无持仓
  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    final primaryColor = ref.watch(primaryColorProvider);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart_rounded,
            size: 64,
            color: primaryColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无持仓',
            style: TextStyle(
              fontSize: 16,
              color: BeeTokens.textSecondary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '买入基金或股票后，持仓将显示在这里',
            style: TextStyle(
              fontSize: 13,
              color: BeeTokens.textTertiary(context),
            ),
          ),
          const SizedBox(height: 24),
         FilledButton.icon(
           onPressed: () async {
             final result = await showBuyDialog(
               context,
               ledgerId: ref.read(currentLedgerIdProvider),
             );
             if (result == true) {
               ref.invalidate(currentHoldingsProvider);
               ref.invalidate(portfolioSummaryProvider);
             }
           },
           icon: const Icon(Icons.add_rounded, size: 20),
           label: const Text('买入基金'),
         ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final result = await showInitialHoldingDialog(
                context,
                ledgerId: ref.read(currentLedgerIdProvider),
              );
              if (result == true) {
                ref.invalidate(currentHoldingsProvider);
                ref.invalidate(portfolioSummaryProvider);
              }
            },
            icon: const Icon(Icons.file_upload_outlined, size: 20),
            label: const Text('导入初始持仓'),
          ),
        ],
      ),
    );
  }

  /// 组合摘要卡片
  Widget _buildSummaryCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<PortfolioSummary> summaryAsync,
  ) {
    return summaryAsync.when(
      skipLoadingOnReload: true,
      data: (summary) => SectionCard(
        padding: const EdgeInsets.fromLTRB(
          BeeDimens.p16,
          BeeDimens.p12,
          BeeDimens.p16,
          BeeDimens.p12,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  '投资组合',
                  style: BeeTextTokens.strongTitle(context),
                ),
                const SizedBox(width: BeeDimens.p8),
                Text(
                  '共 ${summary.holdingCount} 只',
                  style: TextStyle(
                    fontSize: 12,
                    color: BeeTokens.textTertiary(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: BeeDimens.p12),
            _summaryRow(
              context,
              label: '总市值',
              value: summary.totalMarketValue,
              isMain: true,
            ),
            const SizedBox(height: BeeDimens.p8),
            _summaryRow(
              context,
              label: '总成本',
              value: summary.totalCost,
            ),
            const SizedBox(height: BeeDimens.p8),
            _summaryPnlRow(context, ref, summary),
          ],
        ),
      ),
      loading: () => const SectionCard(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _summaryRow(
    BuildContext context, {
    required String label,
    required double value,
    bool isMain = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isMain ? 15 : 13,
            color: isMain
                ? BeeTokens.textPrimary(context)
                : BeeTokens.textSecondary(context),
            fontWeight: isMain ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        AmountText(
          value: value,
          signed: false,
          useCompactFormat: true,
          style: TextStyle(
            fontSize: isMain ? 20 : 14,
            fontWeight: isMain ? FontWeight.bold : FontWeight.w500,
            color: BeeTokens.textPrimary(context),
          ),
        ),
      ],
    );
  }

  Widget _summaryPnlRow(
    BuildContext context,
    WidgetRef ref,
    PortfolioSummary summary,
  ) {
    final isProfit = summary.unrealizedPnL >= 0;
    final pnlColor = isProfit
        ? BeeTokens.incomeColor(context, ref)
        : BeeTokens.expenseColor(context, ref);

    final rateStr = (summary.returnRate * 100).toStringAsFixed(2);
    final sign = isProfit ? '+' : '';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '持仓盈亏',
          style: TextStyle(
            fontSize: 13,
            color: BeeTokens.textSecondary(context),
          ),
        ),
        Row(
          children: [
            AmountText(
              value: summary.unrealizedPnL,
              signed: true,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: pnlColor,
              ),
            ),
            const SizedBox(width: BeeDimens.p8),
            Text(
              '$sign$rateStr%',
              style: TextStyle(
                fontSize: 12,
                color: pnlColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

