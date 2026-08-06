import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart';
import '../../providers.dart';
import '../../styles/tokens.dart';
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
  InvestmentHolding? _toHolding;
  bool _submitting = false;
  bool _loadingHoldings = false;
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
    _loadHoldings();
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
    super.dispose();
  }

  Future<void> _loadHoldings() async {
    if (_loadingHoldings) return;
    _loadingHoldings = true;
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
    } finally {
      _loadingHoldings = false;
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

      await service.validateConvert(
        widget.fromHolding.id,
        fromShares,
        fromNav: fromNav,
        toShares: toShares,
        toNav: toNav,
        fee: fee,
      );

      await service.convert(
        fromHoldingId: widget.fromHolding.id,
        toHoldingId: _toHolding!.id,
        fromShares: fromShares,
        fromNav: fromNav,
        toShares: toShares,
        toNav: toNav,
        fee: fee,
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
                decoration: const InputDecoration(labelText: '转出份额', suffixText: '份'),
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
                decoration: const InputDecoration(labelText: '转出净值', suffixText: '元/份'),
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
              if (_holdings.isNotEmpty)
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
                decoration: const InputDecoration(labelText: '转入份额', suffixText: '份'),
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
                decoration: const InputDecoration(labelText: '转入净值', suffixText: '元/份'),
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
