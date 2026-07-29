import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/db.dart';
import '../../providers.dart';
import '../../services/data/investment_service.dart';
import '../../styles/tokens.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/amount_text.dart';
import '../../widgets/biz/section_card.dart';
import '../../widgets/investment/buy_dialog.dart';
import '../../widgets/investment/sell_dialog.dart';
import '../../widgets/investment/convert_dialog.dart';
/// 持仓明细页 — 展示单只基金的详细持仓信息。
///
/// 数据来源：
/// - [holdingProvider] — 持仓基本数据
/// - [holdingTransactionsProvider] — 交易流水（买入/卖出/转换）
/// - [holdingReturnProvider] — 盈亏计算
///
/// 操作入口：底部操作栏提供买入/卖出/转换按钮。
class HoldingDetailPage extends ConsumerWidget {
  final int holdingId;

  const HoldingDetailPage({super.key, required this.holdingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holdingAsync = ref.watch(holdingProvider(holdingId));
    final transactionsAsync = ref.watch(holdingTransactionsProvider(holdingId));
    final returnAsync = ref.watch(holdingReturnProvider(holdingId));

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: holdingAsync.when(
        data: (holding) {
          if (holding == null) {
            return _buildNotFound(context);
          }
          return Column(
            children: [
              PrimaryHeader(
                title: holding.fundName,
                subtitle: holding.fundCode,
                showBack: true,
                compact: true,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    BeeDimens.p12,
                    BeeDimens.p8,
                    BeeDimens.p12,
                    BeeDimens.p12,
                  ),
                  children: [
                    _buildStatsCard(context, ref, holding, returnAsync),
                    const SizedBox(height: BeeDimens.p8),
                    _buildTransactionsSection(context, ref, transactionsAsync),
                  ],
                ),
              ),
              _buildBottomBar(context, ref, holding),
            ],
          );
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) => Scaffold(
          body: Center(
            child: Text('加载失败：$err'),
          ),
        ),
      ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          const PrimaryHeader(title: '持仓详情', showBack: true, compact: true),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48,
                      color: BeeTokens.textTertiary(context)),
                  const SizedBox(height: 12),
                  Text('持仓不存在或已被删除',
                      style: TextStyle(color: BeeTokens.textSecondary(context))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 持仓统计卡片
  Widget _buildStatsCard(
    BuildContext context,
    WidgetRef ref,
    InvestmentHolding holding,
    AsyncValue<HoldingReturn> returnAsync,
  ) {
    final pnl = holding.marketValue - holding.totalCost;
    final isProfit = pnl >= 0;
    final pnlColor = isProfit
        ? BeeTokens.incomeColor(context, ref)
        : BeeTokens.expenseColor(context, ref);
    final rateStr = holding.totalCost > 0
        ? '${isProfit ? '+' : ''}${(pnl / holding.totalCost * 100).toStringAsFixed(2)}%'
        : '--';

    return SectionCard(
      padding: const EdgeInsets.all(BeeDimens.p16),
      child: Column(
        children: [
          // 市值
          _statRow(
            context,
            label: '市值',
            child: AmountText(
              value: holding.marketValue,
              signed: false,
              useCompactFormat: true,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: BeeTokens.textPrimary(context),
              ),
            ),
          ),
          const SizedBox(height: BeeDimens.p12),
          // 份额 + 净值
          Row(
            children: [
              Expanded(
                child: _statCell('份额', holding.totalShares.toStringAsFixed(2)),
              ),
              Container(
                width: 1,
                height: 32,
                color: BeeTokens.divider(context),
              ),
              Expanded(
                child: _statCell('成本', holding.totalCost.toStringAsFixed(2)),
              ),
              Container(
                width: 1,
                height: 32,
                color: BeeTokens.divider(context),
              ),
              Expanded(
                child: _statCell('净值', holding.currentNav.toStringAsFixed(4)),
              ),
            ],
          ),
          const SizedBox(height: BeeDimens.p12),
          // 盈亏 + 收益率
          Row(
            children: [
              Text('持仓盈亏',
                  style: TextStyle(
                      fontSize: 13, color: BeeTokens.textSecondary(context))),
              const Spacer(),
              AmountText(
                value: pnl,
                signed: true,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: pnlColor),
              ),
              const SizedBox(width: BeeDimens.p8),
              Text(rateStr,
                  style: TextStyle(fontSize: 12, color: pnlColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCell(String label, String value) {
    return Builder(builder: (context) {
      return Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: BeeTokens.textTertiary(context))),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: BeeTokens.textPrimary(context))),
        ],
      );
    });
  }

  Widget _statRow(BuildContext context,
      {required String label, required Widget child}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13, color: BeeTokens.textSecondary(context))),
        child,
      ],
    );
  }

  /// 交易流水
  Widget _buildTransactionsSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Transaction>> transactionsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('交易记录',
              style: BeeTextTokens.strongTitle(context)),
        ),
        transactionsAsync.when(
          skipLoadingOnReload: true,
          data: (transactions) {
            if (transactions.isEmpty) {
              return SectionCard(
                child: Padding(
                  padding: const EdgeInsets.all(BeeDimens.p16),
                  child: Center(
                    child: Text('暂无交易记录',
                        style: TextStyle(
                            color: BeeTokens.textTertiary(context))),
                  ),
                ),
              );
            }
            return Column(
              children: transactions.map((tx) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: BeeDimens.p8),
                  child: _TransactionTile(transaction: tx),
                );
              }).toList(),
            );
          },
          loading: () => const SectionCard(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  /// 底部操作栏
  Widget _buildBottomBar(
    BuildContext context,
    WidgetRef ref,
    InvestmentHolding holding,
  ) {
    final surfaceColor = BeeTokens.surface(context);
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
            top: BorderSide(color: BeeTokens.divider(context), width: 0.5)),
      ),
      padding: EdgeInsets.only(
        left: BeeDimens.p16,
        right: BeeDimens.p16,
        top: BeeDimens.p12,
        bottom: BeeDimens.p12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showBuyDialog(context, ref, holding),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('买入'),
            ),
          ),
          const SizedBox(width: BeeDimens.p12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showSellDialog(context, ref, holding),
              icon: const Icon(Icons.remove, size: 18),
              label: const Text('卖出'),
            ),
          ),
          const SizedBox(width: BeeDimens.p12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showConvertDialog(context, ref, holding),
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: const Text('转换'),
            ),
          ),
        ],
      ),
    );
  }

  void _showBuyDialog(
      BuildContext context, WidgetRef ref, InvestmentHolding holding) {
    showBuyDialog(
      context,
      ledgerId: holding.ledgerId,
      accountId: holding.accountId,
      holding: holding,
    ).then((success) {
      if (success == true) {
        ref.invalidate(currentHoldingsProvider);
      }
    });
  }

  void _showSellDialog(
      BuildContext context, WidgetRef ref, InvestmentHolding holding) {
    showSellDialog(
      context,
      holding: holding,
    ).then((success) {
      if (success == true) {
        ref.invalidate(currentHoldingsProvider);
      }
    });
  }

  void _showConvertDialog(
      BuildContext context, WidgetRef ref, InvestmentHolding holding) {
    showConvertDialog(
      context,
      ledgerId: holding.ledgerId,
      fromHolding: holding,
    ).then((success) {
      if (success == true) {
        ref.invalidate(currentHoldingsProvider);
      }
    });
  }
}

/// 投资交易行
class _TransactionTile extends ConsumerWidget {
  final Transaction transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final investType = transaction.investType ?? '';
    final isBuy = investType == 'buy';

    final typeLabel = switch (investType) {
      'buy' => '买入',
      'sell' => '卖出',
      'redeem' => '赎回',
      'convert' => '转换',
      _ => investType,
    };

    final typeColor = isBuy
        ? BeeTokens.incomeColor(context, ref)
        : BeeTokens.expenseColor(context, ref);

    final dateStr =
        DateFormat('MM-dd HH:mm').format(transaction.happenedAt);
    final shares = transaction.investShares ?? 0;
    final nav = transaction.investNav ?? 0;
    final fee = transaction.investFee ?? 0;
    final amount = transaction.amount;

    return SectionCard(
      padding: const EdgeInsets.all(BeeDimens.p12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行：日期 + 类型 + 份额
          Row(
            children: [
              Text(dateStr,
                  style: TextStyle(
                      fontSize: 12,
                      color: BeeTokens.textTertiary(context))),
              const SizedBox(width: BeeDimens.p8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(typeLabel,
                    style:
                        TextStyle(fontSize: 11, color: typeColor)),
              ),
              const Spacer(),
              Text(
                '${isBuy ? '+' : '-'}${shares.abs().toStringAsFixed(2)} 份',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: BeeTokens.textPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: BeeDimens.p8),
          // 第二行：金额 + 净值 + 手续费
          Row(
            children: [
              AmountText(
                value: amount.abs(),
                signed: false,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: BeeTokens.textPrimary(context),
                ),
              ),
              const SizedBox(width: BeeDimens.p8),
              if (nav > 0)
                Text('净值 $nav',
                    style: TextStyle(
                        fontSize: 11,
                        color: BeeTokens.textTertiary(context))),
              const Spacer(),
              if (fee > 0)
                Text('手续费 ${fee.toStringAsFixed(2)}',
                    style: TextStyle(
                        fontSize: 11,
                        color: BeeTokens.textTertiary(context))),
            ],
          ),
          if (transaction.note != null && transaction.note!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(transaction.note!,
                style: TextStyle(
                    fontSize: 11,
                    color: BeeTokens.textTertiary(context)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}


