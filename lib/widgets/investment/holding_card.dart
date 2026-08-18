import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decimal/decimal.dart';
import '../../data/db.dart';
import '../../services/data/daily_return_calculator.dart';
import '../../styles/tokens.dart';
import '../biz/section_card.dart';
import '../biz/amount_text.dart';

/// 持仓卡片，展示单只基金/股票的持仓摘要（v3 基金模块 UI）。
///
/// 布局：
///   区域 1 — 基金名称/代码 | 市值
///   区域 2 — 持有收益 + 收益率
///   区域 3 — 今日/昨日收益（两列，含涨跌幅）
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

  String _dateStr(DateTime date) => '${date.month}.${date.day}';

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
            _buildHeader(context),
            const SizedBox(height: BeeDimens.p8),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: BeeDimens.p8),
            _buildHoldingReturn(context, ref, pnlColor),
            const SizedBox(height: BeeDimens.p8),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: BeeDimens.p8),
            _buildDailyRow(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                holding.fundName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: BeeTokens.textPrimary(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                holding.fundCode,
                style: TextStyle(
                  fontSize: 11,
                  color: BeeTokens.textTertiary(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: BeeDimens.p8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AmountText(
              value: holding.marketValue,
              signed: false,
              showCurrency: true,
              useCompactFormat: false,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: BeeTokens.textPrimary(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '市值',
              style: TextStyle(
                fontSize: 10,
                color: BeeTokens.textTertiary(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHoldingReturn(
    BuildContext context,
    WidgetRef ref,
    Color pnlColor,
  ) {
    return Row(
      children: [
        Text(
          '持有收益',
          style: TextStyle(
            fontSize: 12,
            color: BeeTokens.textSecondary(context),
          ),
        ),
        const Spacer(),
        AmountText(
          value: _pnl,
          signed: true,
          showCurrency: true,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: pnlColor,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          _pnlRateStr,
          style: TextStyle(
            fontSize: 12,
            color: pnlColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDailyRow(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final daily = dailyReturn;
    final hasData = daily != null && !daily.isNotApplicable;
    final dailyData = hasData ? daily : null;

    return Row(
      children: [
        Expanded(
          child: _dailyColumn(
            context,
            ref,
            label: '今日收益',
            date: now,
            profit: dailyData?.todayProfit,
            pct: dailyData?.todayChangePct,
          ),
        ),
        const SizedBox(width: BeeDimens.p8),
        Container(
          width: 1,
          height: 52,
          color: const Color(0xFFF0F0F0),
        ),
        const SizedBox(width: BeeDimens.p8),
        Expanded(
          child: _dailyColumn(
            context,
            ref,
            label: '昨日收益',
            date: yesterday,
            profit: dailyData?.yesterdayProfit,
            pct: dailyData?.yesterdayChangePct,
          ),
        ),
      ],
    );
  }

  Widget _dailyColumn(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required DateTime date,
    required Decimal? profit,
    required Decimal? pct,
  }) {
    final hasValue = profit != null || pct != null;
    final positive = (profit ?? pct ?? Decimal.zero) >= Decimal.zero;
    final valueColor = hasValue
        ? (positive
            ? BeeTokens.incomeColor(context, ref)
            : BeeTokens.expenseColor(context, ref))
        : const Color(0xFFCCCCCC);
    final pctColor = hasValue
        ? (positive
            ? BeeTokens.incomeColor(context, ref)
            : BeeTokens.expenseColor(context, ref))
        : const Color(0xFFBBBBBB);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
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
              _dateStr(date),
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFFBBBBBB),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (profit != null)
              AmountText(
                value: profit.toDouble(),
                signed: true,
                showCurrency: true,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
              )
            else
              Text(
                '--',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
              ),
            const SizedBox(width: 4),
            Text(
              pct == null ? '(--%)' : '(${_pctStr(pct)})',
              style: TextStyle(
                fontSize: 11,
                color: pctColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _pctStr(Decimal pct) {
    final value = (pct * Decimal.fromInt(100)).toStringAsFixed(2);
    return '${pct >= Decimal.zero ? '+' : ''}$value%';
  }
}
