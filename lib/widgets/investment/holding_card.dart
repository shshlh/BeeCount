import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db.dart';
import '../../services/data/daily_return_calculator.dart';
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
  final DailyReturnSnapshot? dailyReturn;

  const HoldingCard({
    super.key,
    required this.holding,
    this.onTap,
    this.dailyReturn,
  });

  double get _pnl => holding.marketValue - holding.totalCost;
  bool get _isProfit => _pnl >= 0;
  String get _pnlRateStr {
    if (holding.totalCost <= 0) return '--';
    final rate = _pnl / holding.totalCost * 100;
    return '${_isProfit ? '+' : ''}${rate.toStringAsFixed(2)}%';
  }

  String get _navLabel {
    final date = holding.navDate;
    return date == null
        ? '净值'
        : '净值（${date.year}.${date.month}.${date.day}）';
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
                      useCompactFormat: false,
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
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 左侧：份额 | 成本 | 净值（日期）
                Expanded(
                  child: Wrap(
                    spacing: BeeDimens.p8,
                    runSpacing: 4,
                    children: [
                      _infoChip(
                          '份额', holding.totalShares.toStringAsFixed(2)),
                      _infoChip('成本', holding.totalCost.toStringAsFixed(2)),
                      _infoChip(
                          _navLabel, holding.currentNav.toStringAsFixed(4)),
                    ],
                  ),
                ),
                const SizedBox(width: BeeDimens.p8),
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
            const SizedBox(height: BeeDimens.p8),
            _buildDailyRow(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyRow(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final daily = dailyReturn;
    final hasData = daily != null && !daily.isNotApplicable;
    final dailyData = hasData ? daily : null;

    return Wrap(
      spacing: BeeDimens.p8,
      runSpacing: 4,
      children: [
        _dailyChip(
          context,
          ref,
          label: '今日收益（${now.year}.${now.month}.${now.day}）',
          profit: dailyData?.todayProfit,
          pct: null,
        ),
        _dailyChip(
          context,
          ref,
          label: '昨日收益（${yesterday.year}.${yesterday.month}.${yesterday.day}）',
          profit: dailyData?.yesterdayProfit,
          pct: null,
        ),
        _dailyChip(
          context,
          ref,
          label: '今日涨跌',
          profit: null,
          pct: dailyData?.todayChangePct,
        ),
        _dailyChip(
          context,
          ref,
          label: '昨日涨跌',
          profit: null,
          pct: dailyData?.yesterdayChangePct,
        ),
      ],
    );
  }

  Widget _dailyChip(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required double? profit,
    required double? pct,
  }) {
    if (profit == null && pct == null) {
      return _dailyText(context, ref, label, '--', neutral: true);
    }
    final positive = (profit ?? pct ?? 0) >= 0;
    final color = positive
        ? BeeTokens.incomeColor(context, ref)
        : BeeTokens.expenseColor(context, ref);
    final sign = positive ? '+' : '';
    final value = profit != null
        ? '$sign${profit.toStringAsFixed(2)}'
        : '$sign${(pct! * 100).toStringAsFixed(2)}%';
    return _dailyText(context, ref, label, value, color: color);
  }

  Widget _dailyText(
    BuildContext context,
    WidgetRef ref,
    String label,
    String value, {
    Color? color,
    bool neutral = false,
  }) {
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
            color: neutral
                ? BeeTokens.textTertiary(context)
                : (color ?? BeeTokens.textSecondary(context)),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
