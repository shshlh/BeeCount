import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart';
import '../../providers.dart';
import '../../styles/tokens.dart';
import '../../utils/account_type_utils.dart';
import '../biz/section_card.dart';

/// 转换弹窗 — 将 A 基金份额转换为 B 基金。
class ConvertDialog extends ConsumerStatefulWidget {
  final int ledgerId;
  final InvestmentHolding fromHolding;

  const ConvertDialog({
    super.key,
    required this.ledgerId,
    required this.fromHolding,
  });

  @override
  ConsumerState<ConvertDialog> createState() => _ConvertDialogState();
}

class _ConvertDialogState extends ConsumerState<ConvertDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fromSharesCtrl;
  late final TextEditingController _fromNavCtrl;
  late final TextEditingController _toCodeCtrl;
  late final TextEditingController _toNameCtrl;
  late final TextEditingController _toSharesCtrl;
  late final TextEditingController _toNavCtrl;
  late final TextEditingController _feeCtrl;
  late final TextEditingController _refundCtrl;
  InvestmentHolding? _toHolding;
  bool _submitting = false;
  bool _loadingHoldings = false;
  bool _loadFailed = false;
  bool _refundManual = false;
  bool _updatingRefund = false;
  int? _refundAccountId;
  List<Account> _refundAccounts = [];
  List<InvestmentHolding> _holdings = [];

  @override
  void initState() {
    super.initState();
    final h = widget.fromHolding;
    _fromSharesCtrl = TextEditingController();
    _fromNavCtrl = TextEditingController(
        text: h.currentNav > 0 ? h.currentNav.toString() : '');
    _toCodeCtrl = TextEditingController();
    _toNameCtrl = TextEditingController();
    _toSharesCtrl = TextEditingController();
    _toNavCtrl = TextEditingController();
    _feeCtrl = TextEditingController(text: '0');
    _refundCtrl = TextEditingController(text: '0');
    _fromSharesCtrl.addListener(_updateAutoRefund);
    _fromNavCtrl.addListener(_updateAutoRefund);
    _toSharesCtrl.addListener(_updateAutoRefund);
    _toNavCtrl.addListener(_updateAutoRefund);
    _feeCtrl.addListener(_updateAutoRefund);
    _refundCtrl.addListener(() {
      if (_updatingRefund) return;
      _refundManual = true;
      if (mounted) setState(() {});
    });
    _loadHoldings();
    _loadRefundAccounts();
  }

  @override
  void dispose() {
    _fromSharesCtrl.dispose();
    _fromNavCtrl.dispose();
    _toCodeCtrl.dispose();
    _toNameCtrl.dispose();
    _toSharesCtrl.dispose();
    _toNavCtrl.dispose();
    _feeCtrl.dispose();
    _refundCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHoldings() async {
    if (_loadingHoldings) return;
    _loadingHoldings = true;
    if (mounted) setState(() => _loadFailed = false);
    try {
      final service = ref.read(investmentServiceProvider);
      final ledgerId = ref.read(currentLedgerIdProvider);
      final stream = service.watchHoldings(ledgerId: ledgerId);
      final holdings = await stream.first;
      if (mounted) {
        setState(() => _holdings = holdings
            .where((h) => h.id != widget.fromHolding.id)
            .toList());
      }
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    } finally {
      _loadingHoldings = false;
    }
  }

  Future<void> _loadRefundAccounts() async {
    final accounts = await ref
        .read(repositoryProvider)
        .getAvailableAccountsForLedger(widget.ledgerId);
    if (mounted) {
      setState(() {
        _refundAccounts = accounts
            .where((a) => isTradableType(a.type) && !a.hidden)
            .toList();
      });
    }
  }

  /// 退回金额默认 = 转出市值 - 转入市值 - 手续费，>=0 截断
  double _calcRefund() {
    final fromShares = double.tryParse(_fromSharesCtrl.text) ?? 0;
    final fromNav = double.tryParse(_fromNavCtrl.text) ?? 0;
    final toShares = double.tryParse(_toSharesCtrl.text) ?? 0;
    final toNav = double.tryParse(_toNavCtrl.text) ?? 0;
    final fee = double.tryParse(_feeCtrl.text) ?? 0;
    final refund = Decimal.parse(fromShares.toString()) *
            Decimal.parse(fromNav.toString()) -
        Decimal.parse(toShares.toString()) * Decimal.parse(toNav.toString()) -
        Decimal.parse(fee.toString());
    return refund < Decimal.zero ? 0 : refund.toDouble();
  }

  void _updateAutoRefund() {
    if (_refundManual) return;
    final refund = _calcRefund();
    final text = refund > 0 ? refund.toStringAsFixed(2) : '0';
    if (_refundCtrl.text != text) {
      _updatingRefund = true;
      _refundCtrl.text = text;
      _updatingRefund = false;
      if (mounted) setState(() {});
    }
  }

  void _selectToHolding(InvestmentHolding h) {
    setState(() {
      _toHolding = h;
      _toCodeCtrl.text = h.fundCode;
      _toNameCtrl.text = h.fundName;
      _toNavCtrl.text = h.currentNav > 0 ? h.currentNav.toString() : '';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_toHolding == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择目标基金')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final service = ref.read(investmentServiceProvider);
      final fromShares = double.parse(_fromSharesCtrl.text);
      final fromNav = double.parse(_fromNavCtrl.text);
      final toShares = double.parse(_toSharesCtrl.text);
      final toNav = double.parse(_toNavCtrl.text);
      final fee = _feeCtrl.text.trim().isEmpty
          ? 0.0
          : double.parse(_feeCtrl.text);
      final refundAmount = double.parse(_refundCtrl.text);
      final refundAccountId = refundAmount > 0 ? _refundAccountId : null;
      if (refundAmount > 0 && refundAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请选择退回账户')),
        );
        return;
      }

      await service.validateConvert(
        widget.fromHolding.id,
        fromShares,
        fromNav: fromNav,
        toShares: toShares,
        toNav: toNav,
        fee: fee,
        refundAmount: refundAmount,
        refundAccountId: refundAccountId,
      );

      await service.convert(
        fromHoldingId: widget.fromHolding.id,
        toHoldingId: _toHolding!.id,
        fromShares: fromShares,
        fromNav: fromNav,
        toShares: toShares,
        toNav: toNav,
        fee: fee,
        refundAmount: refundAmount,
        refundAccountId: refundAccountId,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('转换失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.fromHolding;

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      appBar: AppBar(
        title: Text('转换 - ${h.fundName}'),
        backgroundColor: BeeTokens.surface(context),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('确认'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(BeeDimens.p16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 来源持仓摘要
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('从 ${h.fundName} (${h.fundCode}) 转出',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: BeeTokens.textPrimary(context))),
                    const SizedBox(height: 4),
                    Text('可转份额 ${h.totalShares.toStringAsFixed(2)} 份',
                        style: TextStyle(fontSize: 12, color: BeeTokens.textTertiary(context))),
                  ],
                ),
              ),
              const SizedBox(height: BeeDimens.p16),
              TextFormField(
                controller: _fromSharesCtrl,
                decoration: const InputDecoration(labelText: '确认转出份额', suffixText: '份'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请输入转出份额';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return '份额必须大于 0';
                  if (n > h.totalShares) return '超出可转出份额';
                  return null;
                },
              ),
              const SizedBox(height: BeeDimens.p16),
              TextFormField(
                controller: _fromNavCtrl,
                decoration: const InputDecoration(labelText: '确认转出净值', suffixText: '元/份'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请输入转出净值';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return '净值必须大于 0';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Text('目标基金',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: BeeTokens.textPrimary(context))),
              const SizedBox(height: BeeDimens.p8),
              if (_loadFailed)
                Row(
                  children: [
                    Text('加载失败，请重试',
                        style: TextStyle(
                            fontSize: 12,
                            color: BeeTokens.error(context))),
                    TextButton(
                      onPressed: _loadHoldings,
                      child: const Text('重试'),
                    ),
                  ],
                )
              else if (_holdings.isNotEmpty)
                ..._holdings.map((holding) => ListTile(
                      dense: true,
                      leading: Radio<InvestmentHolding>(
                        value: holding,
                        groupValue: _toHolding,
                        onChanged: (v) {
                          if (v != null) _selectToHolding(v);
                        },
                      ),
                      title: Text(holding.fundName,
                          style: TextStyle(fontSize: 14, color: BeeTokens.textPrimary(context))),
                      subtitle: Text(holding.fundCode,
                          style: TextStyle(fontSize: 11, color: BeeTokens.textTertiary(context))),
                    )),
              TextFormField(
                controller: _toCodeCtrl,
                decoration: const InputDecoration(labelText: '目标基金代码（如选已有持仓可不填）'),
              ),
              const SizedBox(height: BeeDimens.p16),
              TextFormField(
                controller: _toNameCtrl,
                decoration: const InputDecoration(labelText: '目标基金名称'),
              ),
              const SizedBox(height: BeeDimens.p16),
              TextFormField(
                controller: _toSharesCtrl,
                decoration: const InputDecoration(labelText: '确认转入份额', suffixText: '份'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请输入转入份额';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return '份额必须大于 0';
                  return null;
                },
              ),
              const SizedBox(height: BeeDimens.p16),
              TextFormField(
                controller: _toNavCtrl,
                decoration: const InputDecoration(labelText: '确认转入净值', suffixText: '元/份'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请输入转入净值';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return '净值必须大于 0';
                  return null;
                },
              ),
              const SizedBox(height: BeeDimens.p16),
              TextFormField(
                controller: _feeCtrl,
                decoration: const InputDecoration(labelText: '手续费', suffixText: '元'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = double.tryParse(v);
                  if (n == null || n < 0) return '手续费不能为负数';
                  return null;
                },
              ),
              const SizedBox(height: BeeDimens.p16),
              TextFormField(
                controller: _refundCtrl,
                decoration: const InputDecoration(
                    labelText: '退回金额', suffixText: '元'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请输入退回金额';
                  final n = double.tryParse(v);
                  if (n == null || n < 0) return '退回金额不能为负数';
                  return null;
                },
              ),
              if (_refundAccounts.isNotEmpty &&
                  (double.tryParse(_refundCtrl.text) ?? 0) > 0) ...[
                const SizedBox(height: BeeDimens.p16),
                DropdownButtonFormField<int>(
                  key: ValueKey(_refundAccounts.length),
                  initialValue: _refundAccountId,
                  decoration: const InputDecoration(labelText: '退回账户'),
                  items: _refundAccounts.map((a) => DropdownMenuItem(
                    value: a.id,
                    child: Text(a.name),
                  )).toList(),
                  onChanged: (v) => setState(() => _refundAccountId = v),
                  validator: (_) =>
                      _refundAccountId == null ? '请选择退回账户' : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool?> showConvertDialog(
  BuildContext context, {
  required int ledgerId,
  required InvestmentHolding fromHolding,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => ConvertDialog(
        ledgerId: ledgerId,
        fromHolding: fromHolding,
      ),
    ),
  );
}
