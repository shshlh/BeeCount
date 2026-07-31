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
                  child: _TransactionTile(
                    transaction: tx,
                    onEdit: () => _showEditDialog(context, ref, tx),
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
  void _showEditDialog(BuildContext context, WidgetRef ref, Transaction tx) {
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

  const _TransactionTile({required this.transaction, this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final investType = transaction.investType ?? '';
    final isBuy = investType == 'buy';
    final isInitial = investType == 'initial';

    final typeLabel = switch (investType) {
      'buy' => '买入',
      'sell' => '卖出',
      'redeem' => '赎回',
      'convert' => '转换',
      'initial' => '初始登记',
      _ => investType,
    };

    final typeColor = isInitial
        ? BeeTokens.textTertiary(context)
        : isBuy
            ? BeeTokens.incomeColor(context, ref)
            : BeeTokens.expenseColor(context, ref);

    final dateStr =
        DateFormat('MM-dd HH:mm').format(transaction.happenedAt);
    final shares = transaction.investShares ?? 0;
    final nav = transaction.investNav ?? 0;
    final fee = transaction.investFee ?? 0;
    final amount = transaction.amount;
    final isExcludedFromStats = transaction.excludeFromStats;

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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(typeLabel,
                            style:
                                TextStyle(fontSize: 11, color: typeColor)),
                        // v4.7: 编辑图标暗示可编辑
                        if (onEdit != null) ...[
                          const SizedBox(width: 2),
                          Icon(Icons.edit_outlined,
                              size: 11, color: typeColor),
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
    _sharesCtrl = TextEditingController(
        text: (tx.investShares?.abs() ?? 0).toString());
    _navCtrl = TextEditingController(
        text: tx.investNav != null && tx.investNav! > 0
            ? tx.investNav.toString()
            : '');
    _feeCtrl = TextEditingController(
        text: tx.investFee != null ? tx.investFee.toString() : '0');
    _amountCtrl = TextEditingController(
        text: tx.amount.abs().toStringAsFixed(2));
    _happenedAt = tx.happenedAt;
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
      final rawShares = double.tryParse(_sharesCtrl.text) ?? 0;
      final isNegative = investType == 'sell' || investType == 'redeem';
      final shares = isNegative ? -rawShares.abs() : rawShares.abs();

      await service.updateTransaction(
        tx.id,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        happenedAt: _happenedAt != tx.happenedAt ? _happenedAt : null,
        investShares: shares != (tx.investShares ?? 0) ? shares : null,
        investNav: double.tryParse(_navCtrl.text),
        investFee: double.tryParse(_feeCtrl.text),
        amount: double.tryParse(_amountCtrl.text),
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
                        picked.year, picked.month, picked.day,
                        _happenedAt.hour, _happenedAt.minute));
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
              TextFormField(
                controller: _amountCtrl,
                decoration: const InputDecoration(labelText: '金额', isDense: true),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请输入金额';
                  if (double.tryParse(v) == null) return '无效金额';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sharesCtrl,
                decoration: const InputDecoration(labelText: '份额', isDense: true),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _navCtrl,
                decoration: const InputDecoration(labelText: '净值', isDense: true),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _feeCtrl,
                decoration: const InputDecoration(labelText: '手续费', isDense: true),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(labelText: '备注', isDense: true),
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

