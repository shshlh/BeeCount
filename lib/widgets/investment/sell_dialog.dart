import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart';
import '../../providers.dart';
import '../../styles/tokens.dart';
import '../biz/section_card.dart';

/// 卖出弹窗 — 从已有持仓卖出部分或全部份额。
class SellDialog extends ConsumerStatefulWidget {
  final InvestmentHolding holding;

  const SellDialog({super.key, required this.holding});

  @override
  ConsumerState<SellDialog> createState() => _SellDialogState();
}

class _SellDialogState extends ConsumerState<SellDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _sharesCtrl;
  late final TextEditingController _navCtrl;
  late final TextEditingController _feeCtrl;
  bool _submitting = false;
  bool _sellAll = false;

  @override
  void initState() {
    super.initState();
    _sharesCtrl = TextEditingController();
    _navCtrl = TextEditingController(
        text: widget.holding.currentNav > 0
            ? widget.holding.currentNav.toString()
            : '');
    _feeCtrl = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _sharesCtrl.dispose();
    _navCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  void _toggleSellAll(bool v) {
    setState(() {
      _sellAll = v;
      _sharesCtrl.text = v ? widget.holding.totalShares.toString() : '';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final service = ref.read(investmentServiceProvider);
      final shares = double.parse(_sharesCtrl.text);
      await service.validateSell(widget.holding.id, shares);

      final nav = double.parse(_navCtrl.text.isEmpty ? '0' : _navCtrl.text);
      await service.sell(
        holdingId: widget.holding.id,
        shares: shares,
        nav: nav,
        fee: double.tryParse(_feeCtrl.text) ?? 0,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('卖出失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.holding;
    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      appBar: AppBar(
        title: Text('卖出 - ${h.fundName}'),
        backgroundColor: BeeTokens.surface(context),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
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
              // 持仓摘要
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.fundCode,
                        style: TextStyle(fontSize: 12, color: BeeTokens.textTertiary(context))),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('可卖份额 ',
                            style: TextStyle(fontSize: 13, color: BeeTokens.textSecondary(context))),
                        Text(h.totalShares.toStringAsFixed(2),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: BeeTokens.textPrimary(context))),
                        const Text(' 份'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: BeeDimens.p16),
              SwitchListTile(
                title: const Text('全部卖出'),
                value: _sellAll,
                onChanged: _toggleSellAll,
                contentPadding: EdgeInsets.zero,
              ),
              TextFormField(
                controller: _sharesCtrl,
                decoration: const InputDecoration(labelText: '卖出份额', suffixText: '份'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请输入卖出份额';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return '份额必须大于 0';
                  if (n > h.totalShares) return '超出可卖份额';
                  return null;
                },
              ),
              const SizedBox(height: BeeDimens.p16),
              TextFormField(
                controller: _navCtrl,
                decoration: const InputDecoration(labelText: '卖出净值', suffixText: '元/份'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: BeeDimens.p16),
              TextFormField(
                controller: _feeCtrl,
                decoration: const InputDecoration(labelText: '手续费', suffixText: '元'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool?> showSellDialog(
  BuildContext context, {
  required InvestmentHolding holding,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => SellDialog(holding: holding),
    ),
  );
}
