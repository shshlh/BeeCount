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
/// v4.7: 交易记录支持点击编辑（编辑弹窗 + updateTransaction）。
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
                actions: [
                  IconButton(
                    onPressed: () =>
                        _showEditHoldingInfoDialog(context, ref, holding),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: '编辑基金信息',
                  ),
                  IconButton(
                    onPressed: () =>
                        _confirmDeleteHolding(context, ref, holding),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: '删除持仓',
                  ),
                ],
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
                  Icon(Icons.error_outline,
                      size: 48, color: BeeTokens.textTertiary(context)),
                  const SizedBox(height: 12),
                  Text('持仓不存在或已被删除',
                      style:
                          TextStyle(color: BeeTokens.textSecondary(context))),
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
              useCompactFormat: false,
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
                child: _statCell(
                  holding.navDate == null
                      ? '净值'
                      : '净值（${holding.navDate!.year}.'
                          '${holding.navDate!.month}.'
                          '${holding.navDate!.day}）',
                  holding.currentNav.toStringAsFixed(4),
                ),
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
                    fontSize: 14, fontWeight: FontWeight.w600, color: pnlColor),
              ),
              const SizedBox(width: BeeDimens.p8),
              Text(rateStr, style: TextStyle(fontSize: 12, color: pnlColor)),
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
          child: Text('交易记录', style: BeeTextTokens.strongTitle(context)),
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
                        style:
                            TextStyle(color: BeeTokens.textTertiary(context))),
                  ),
                ),
              );
            }
            return Column(
              children: transactions.map((tx) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: BeeDimens.p8),
                  child: _TransactionTile(
                    transaction: tx,
                    onEdit: () => _showEditDialog(context, ref, tx),
                    onDelete: () => _confirmDeleteTransaction(context, ref, tx),
                  ),
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

  /// 弹出交易编辑弹窗（v4.7: 支持编辑交易记录）
  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    Transaction tx,
  ) async {
    // v7.5.4: 转换记录从任意一侧进入整批编辑页
    if (tx.batchId != null) {
      await _openConversionEdit(context, ref, tx.batchId!);
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => _TransactionEditDialog(
        transaction: tx,
        onSave: () {
          ref.invalidate(currentHoldingsProvider);
          ref.invalidate(portfolioSummaryProvider);
        },
      ),
    );
  }

  /// 打开转换整批编辑页（7.5.4）。
  Future<void> _openConversionEdit(
    BuildContext context,
    WidgetRef ref,
    String batchId,
  ) async {
    try {
      final service = ref.read(investmentServiceProvider);
      final txs = await service.getTransactionsByBatchId(batchId);
      final sellTx = txs.firstWhere((t) => t.investType == 'sell');
      final buyTx = txs.firstWhere((t) => t.investType == 'buy');
      Transaction? refundTx;
      for (final t in txs) {
        if (t.investType == null && t.holdingId == null) {
          refundTx = t;
          break;
        }
      }
      final fromHolding = await service.getHolding(sellTx.holdingId!);
      final toHolding = await service.getHolding(buyTx.holdingId!);
      if (fromHolding == null || toHolding == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('转换关联持仓不存在')),
          );
        }
        return;
      }
      if (!context.mounted) return;

      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ConvertDialog(
            ledgerId: fromHolding.ledgerId,
            fromHolding: fromHolding,
            edit: ConversionEditData(
              batchId: batchId,
              fromHolding: fromHolding,
              toHolding: toHolding,
              sellTx: sellTx,
              buyTx: buyTx,
              refundTx: refundTx,
            ),
          ),
        ),
      );
      if (changed == true) {
        _invalidateAfterConversionChange(ref, [fromHolding.id, toHolding.id]);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开转换编辑失败：$e')),
        );
      }
    }
  }

  /// 转换整批编辑/删除后刷新双方持仓相关 Provider。
  void _invalidateAfterConversionChange(WidgetRef ref, List<int> holdingIds) {
    ref.invalidate(currentHoldingsProvider);
    ref.invalidate(portfolioSummaryProvider);
    ref.invalidate(filteredHoldingsProvider);
    for (final id in holdingIds) {
      ref.invalidate(holdingProvider(id));
      ref.invalidate(holdingReturnProvider(id));
      ref.invalidate(holdingTransactionsProvider(id));
    }
  }

  /// 弹出基金代码/名称编辑弹窗（v6.13.2）
  void _showEditHoldingInfoDialog(
    BuildContext context,
    WidgetRef ref,
    InvestmentHolding holding,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _HoldingInfoEditDialog(
        holding: holding,
        onSaved: () {
          ref.invalidate(holdingProvider(holding.id));
          ref.invalidate(currentHoldingsProvider);
          ref.invalidate(portfolioSummaryProvider);
          ref.invalidate(filteredHoldingsProvider);
        },
      ),
    );
  }

  /// 确认删除单笔投资流水
  Future<void> _confirmDeleteTransaction(
    BuildContext context,
    WidgetRef ref,
    Transaction tx,
  ) async {
    // v7.5.4: 转换记录从任意一侧删除整批
    if (tx.batchId != null) {
      await _confirmDeleteConversion(context, ref, tx.batchId!);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除流水'),
        content: Text('确定删除这笔交易记录？删除后将重算持仓，此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: BeeTokens.error(context),
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(repositoryProvider).deleteTransaction(tx.id);
      ref.invalidate(currentHoldingsProvider);
      ref.invalidate(portfolioSummaryProvider);
      ref.invalidate(filteredHoldingsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除流水失败：$e')),
        );
      }
    }
  }

  /// 确认删除一整笔转换（7.5.4）。
  Future<void> _confirmDeleteConversion(
    BuildContext context,
    WidgetRef ref,
    String batchId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除转换记录'),
        content: const Text('确定删除完整的转换记录？将同时删除转出、转入与退回记录并重算双方持仓，此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: BeeTokens.error(context),
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final txs = await ref
          .read(investmentServiceProvider)
          .getTransactionsByBatchId(batchId);
      final holdingIds = txs.map((t) => t.holdingId).whereType<int>().toSet();
      await ref.read(investmentServiceProvider).deleteConversion(batchId);
      _invalidateAfterConversionChange(ref, holdingIds.toList());
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除转换记录失败：$e')),
        );
      }
    }
  }

  /// 确认删除整个持仓（含全部流水与分组关联）
  Future<void> _confirmDeleteHolding(
    BuildContext context,
    WidgetRef ref,
    InvestmentHolding holding,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除持仓'),
        content: Text('删除持仓「${holding.fundName}」？将同时删除该持仓的全部交易记录，此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: BeeTokens.error(context),
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(investmentServiceProvider).deleteHolding(holding.id);
      ref.invalidate(currentHoldingsProvider);
      ref.invalidate(portfolioSummaryProvider);
      ref.invalidate(filteredHoldingsProvider);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除持仓失败：$e')),
        );
      }
    }
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

// ───── 交易记录行 ─────

/// 投资交易行（v4.7: 支持点击编辑，支持 initial investType）。
class _TransactionTile extends ConsumerWidget {
  final Transaction transaction;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _TransactionTile({
    required this.transaction,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final investType = transaction.investType ?? '';
    final isBuy = investType == 'buy';
    final isInitial = investType == 'initial';
    // v7.5.4: 转换批次在 A/B 两页统一显示「转换」标签
    final isConvert = transaction.batchId != null;

    final typeLabel = isConvert
        ? '转换'
        : switch (investType) {
            'buy' => '买入',
            'sell' => '卖出',
            'redeem' => '赎回',
            'convert' => '转换',
            'initial' => '初始登记',
            _ => investType,
          };

    final typeColor = isConvert
        ? BeeTokens.textSecondary(context)
        : isInitial
            ? BeeTokens.textTertiary(context)
            : isBuy
                ? BeeTokens.incomeColor(context, ref)
                : BeeTokens.expenseColor(context, ref);

    final dateStr = DateFormat('MM-dd HH:mm').format(transaction.happenedAt);
    final shares = transaction.investShares ?? 0;
    final nav = transaction.investNav ?? 0;
    final fee = transaction.investFee ?? 0;
    final amount = transaction.amount;
    final isExcludedFromStats = transaction.excludeFromStats;
    // v7.5.4: 转换买入侧展示转入成本(amount)；旧记录 amount=0 时与转出侧
    // 一样按「份额 × 净值」回退。
    final displayAmount = isConvert
        ? (isBuy
            ? (amount > 0 ? amount : shares.abs() * nav)
            : shares.abs() * nav)
        : amount;

    return SectionCard(
      padding: const EdgeInsets.all(BeeDimens.p12),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(4),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(typeLabel,
                            style: TextStyle(fontSize: 11, color: typeColor)),
                        // v4.7: 编辑图标暗示可编辑
                        if (onEdit != null) ...[
                          const SizedBox(width: 2),
                          Icon(Icons.edit_outlined, size: 11, color: typeColor),
                        ],
                      ],
                    ),
                  ),
                  // v4.7: 初始持仓标记
                  if (isExcludedFromStats && isInitial) ...[
                    const SizedBox(width: 4),
                    Text('不计流水',
                        style: TextStyle(
                            fontSize: 9,
                            color: BeeTokens.textTertiary(context),
                            fontStyle: FontStyle.italic)),
                  ],
                  const Spacer(),
                  Text(
                    '${isBuy || isInitial ? '+' : '-'}${shares.abs().toStringAsFixed(2)} 份',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: BeeTokens.textPrimary(context),
                    ),
                  ),
                  if (onDelete != null)
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      tooltip: '删除流水',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: BeeDimens.p8),
              // 第二行：金额 + 净值 + 手续费
              Row(
                children: [
                  AmountText(
                    value: displayAmount,
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
                        fontSize: 11, color: BeeTokens.textTertiary(context)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ───── 交易编辑弹窗（v4.7 新增）─────

/// 交易记录编辑弹窗。
/// 可编辑字段：备注 / 日期 / 份额 / 净值 / 手续费 / 金额。
class _TransactionEditDialog extends ConsumerStatefulWidget {
  final Transaction transaction;
  final VoidCallback? onSave;

  const _TransactionEditDialog({
    required this.transaction,
    this.onSave,
  });

  @override
  ConsumerState<_TransactionEditDialog> createState() =>
      _TransactionEditDialogState();
}

class _TransactionEditDialogState
    extends ConsumerState<_TransactionEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _noteCtrl;
  late final TextEditingController _sharesCtrl;
  late final TextEditingController _navCtrl;
  late final TextEditingController _feeCtrl;
  late final TextEditingController _amountCtrl;
  late DateTime _happenedAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    _noteCtrl = TextEditingController(text: tx.note ?? '');
    _sharesCtrl =
        TextEditingController(text: (tx.investShares?.abs() ?? 0).toString());
    _navCtrl = TextEditingController(
        text: tx.investNav != null && tx.investNav! > 0
            ? tx.investNav.toString()
            : '');
    _feeCtrl = TextEditingController(
        text: tx.investFee != null ? tx.investFee.toString() : '0');
    _amountCtrl =
        TextEditingController(text: tx.amount.abs().toStringAsFixed(2));
    // 7.5.5: 时间编辑精确到分，保存时秒归零。
    _happenedAt = DateTime(tx.happenedAt.year, tx.happenedAt.month,
        tx.happenedAt.day, tx.happenedAt.hour, tx.happenedAt.minute);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _sharesCtrl.dispose();
    _navCtrl.dispose();
    _feeCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final service = ref.read(investmentServiceProvider);
      final tx = widget.transaction;
      final investType = tx.investType ?? '';

      // 份额符号：buy/initial 为正，sell/redeem 为负
      final rawShares = double.parse(_sharesCtrl.text);
      final isNegative = investType == 'sell' || investType == 'redeem';
      final shares = isNegative ? -rawShares.abs() : rawShares.abs();
      final amount = double.parse(_amountCtrl.text);
      final nav = double.parse(_navCtrl.text);
      final fee = double.parse(_feeCtrl.text);

      // 备注：清空走 clearNote sentinel，未变化则不更新
      final newNote = _noteCtrl.text.trim();
      final originalNote = tx.note ?? '';
      final clearNote = newNote.isEmpty && originalNote.isNotEmpty;
      final noteArg = !clearNote && newNote != originalNote ? newNote : null;
      final happenedAt = DateTime(_happenedAt.year, _happenedAt.month,
          _happenedAt.day, _happenedAt.hour, _happenedAt.minute);

      await service.updateTransaction(
        tx.id,
        note: noteArg,
        clearNote: clearNote,
        happenedAt: happenedAt != tx.happenedAt ? happenedAt : null,
        investShares: shares != (tx.investShares ?? 0) ? shares : null,
        investNav: nav,
        investFee: fee,
        amount: amount,
      );

      widget.onSave?.call();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTime() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showWheelTimePicker(
      context,
      initial: TimeOfDay.fromDateTime(_happenedAt),
    );
    if (picked != null && mounted) {
      setState(() => _happenedAt = DateTime(_happenedAt.year, _happenedAt.month,
          _happenedAt.day, picked.hour, picked.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(_happenedAt);
    return AlertDialog(
      title: const Text('编辑交易'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 日期选择
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _happenedAt,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _happenedAt = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        _happenedAt.hour,
                        _happenedAt.minute));
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '日期',
                    isDense: true,
                  ),
                  child: Text(dateStr),
                ),
              ),
              const SizedBox(height: 12),
              // 7.5.5: 时间选择（时/分，不含秒）
              InkWell(
                onTap: _pickTime,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '时间',
                    isDense: true,
                  ),
                  child: Text(
                    DateFormat('HH:mm').format(_happenedAt),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountCtrl,
                decoration:
                    const InputDecoration(labelText: '金额', isDense: true),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请输入金额';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return '金额必须大于 0';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sharesCtrl,
                decoration:
                    const InputDecoration(labelText: '份额', isDense: true),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请输入份额';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return '份额必须大于 0';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _navCtrl,
                decoration:
                    const InputDecoration(labelText: '净值', isDense: true),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请输入净值';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return '净值必须大于 0';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _feeCtrl,
                decoration:
                    const InputDecoration(labelText: '手续费', isDense: true),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请输入手续费';
                  final n = double.tryParse(v);
                  if (n == null || n < 0) return '手续费不能为负数';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteCtrl,
                decoration:
                    const InputDecoration(labelText: '备注', isDense: true),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('保存'),
        ),
      ],
    );
  }
}

// ───── 基金信息编辑弹窗（v6.13.2 新增）─────

/// 编辑持仓的基金代码/名称，代码必须为 6 位数字。
class _HoldingInfoEditDialog extends ConsumerStatefulWidget {
  final InvestmentHolding holding;
  final VoidCallback? onSaved;

  const _HoldingInfoEditDialog({
    required this.holding,
    this.onSaved,
  });

  @override
  ConsumerState<_HoldingInfoEditDialog> createState() =>
      _HoldingInfoEditDialogState();
}

class _HoldingInfoEditDialogState
    extends ConsumerState<_HoldingInfoEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController(text: widget.holding.fundCode);
    _nameCtrl = TextEditingController(text: widget.holding.fundName);
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final code = _codeCtrl.text.trim();
      final name = _nameCtrl.text.trim();
      await ref.read(investmentServiceProvider).updateHoldingInfo(
            widget.holding.id,
            fundCode: code,
            fundName: name.isEmpty ? null : name,
          );
      widget.onSaved?.call();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑基金信息'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _codeCtrl,
              decoration:
                  const InputDecoration(labelText: '基金代码', isDense: true),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '请输入基金代码';
                if (!RegExp(r'^\d{6}$').hasMatch(v.trim())) {
                  return '基金代码必须为6位数字';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration:
                  const InputDecoration(labelText: '基金名称', isDense: true),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '请输入基金名称' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('保存'),
        ),
      ],
    );
  }
}
