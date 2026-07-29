import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db.dart';
import '../../styles/tokens.dart';
import '../biz/section_card.dart';
import '../biz/amount_text.dart';

/// 持仓卡片，展示单只基金/股票的持仓摘要。
///
/// 布局：
///   第一行 — 基金名称（左）| 市值（右）
///   第二行 — 代码 + 份额 (左) | 盈亏 + 收益率（右，按收入/支出配色）
///
/// 遵循 BeeCount UI 风格：用 [SectionCard] 做容器、[AmountText] 格式化金额、
/// [BeeTokens] 驱动主题色。
class HoldingCard extends ConsumerWidget {
  final InvestmentHolding holding;
  final VoidCallback? onTap;

  const HoldingCard({
    super.key,
    required this.holding,
    this.onTap,
  });

  double get _pnl => holding.marketValue - holding.totalCost;
  bool get _isProfit => _pnl >= 0;
  String get _pnlRateStr {
    if (holding.totalCost <= 0) return '--';
    final rate = _pnl / holding.totalCost * 100;
    return '${_isProfit ? '+' : ''}${rate.toStringAsFixed(2)}%';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pnlColor = _isProfit
        ? BeeTokens.incomeColor(context, ref)
        : BeeTokens.expenseColor(context, ref);

    return GestureDetector(
      onTap: onTap,
      child: SectionCard(
        padding: const EdgeInsets.all(BeeDimens.p12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 第一行：名称 | 市值
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左侧：基金名称 + 代码
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        holding.fundName,
                        style: BeeTextTokens.title(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        holding.fundCode,
                        style: BeeTextTokens.label(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: BeeDimens.p8),
                // 右侧：市值
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '市值',
                      style: TextStyle(
                        fontSize: 11,
                        color: BeeTokens.textTertiary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    AmountText(
                      value: holding.marketValue,
                      signed: false,
                      useCompactFormat: true,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: BeeTokens.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: BeeDimens.p8),
            // 第二行：份额/净值 | 盈亏/收益率
            Row(
              children: [
                // 左侧：份额 | 成本
                _infoChip('份额', holding.totalShares.toStringAsFixed(2)),
                const SizedBox(width: BeeDimens.p8),
                _infoChip('成本', holding.totalCost.toStringAsFixed(2)),
                const Spacer(),
                // 右侧：盈亏 + 收益率
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AmountText(
                      value: _pnl,
                      signed: true,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: pnlColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _pnlRateStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: pnlColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Builder(builder: (context) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: BeeTokens.textTertiary(context),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: BeeTokens.textSecondary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    });
  }
}
