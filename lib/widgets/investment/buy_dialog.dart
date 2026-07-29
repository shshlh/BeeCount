import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart';
import '../../providers.dart';
import '../../styles/tokens.dart';

/// 买入弹窗 — 填写基金代码、名称、份额、净值、手续费。
///
/// 如果从持仓详情进入（传入 [holding]），则自动预填基金信息，
/// 买入后追加到该持仓。
class BuyDialog extends ConsumerStatefulWidget {
  final int ledgerId;
  final int? accountId;
  final InvestmentHolding? holding;

  const BuyDialog({
    super.key,
    required this.ledgerId,
    this.accountId,
    this.holding,
  });

  @override
  ConsumerState<BuyDialog> createState() => _BuyDialogState();
}

class _BuyDialogState extends ConsumerState<BuyDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _sharesCtrl;
  late final TextEditingController _navCtrl;
  late final TextEditingController _feeCtrl;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final h = widget.holding;
    _codeCtrl = TextEditingController(text: h?.fundCode ?? '');
    _nameCtrl = TextEditingController(text: h?.fundName ?? '');
    _sharesCtrl = TextEditingController();
    _navCtrl = TextEditingController(text: h != null && h.currentNav > 0 ? h.currentNav.toString() : '');
    _feeCtrl = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _sharesCtrl.dispose();
    _navCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final service = ref.read(investmentServiceProvider);
      final shares = double.parse(_sharesCtrl.text);
      final nav = double.parse(_navCtrl.text);
      service.validateBuy(shares: shares, nav: nav);

      await service.buy(
        ledgerId: widget.ledgerId,
        accountId: widget.accountId ?? 0,
        fundCode: _codeCtrl.text.trim(),
        fundName: _nameCtrl.text.trim(),
        shares: shares,
        nav: nav,
        fee: double.tryParse(_feeCtrl.text) ?? 0,
        holdingId: widget.holding?.id,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('买入失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      appBar: AppBar(
        title: const Text('买入'),
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
              TextFormField(
                controller: _codeCtrl,
                decoration: const InputDecoration(labelText: '基金代码'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '请输入基金代码' : null,
              ),
              const SizedBox(height: BeeDimens.p16),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: '基金名称'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '请输入基金名称' : null,
              ),
              const SizedBox(height: BeeDimens.p16),
              TextFormField(
                controller: _sharesCtrl,
                decoration: const InputDecoration(labelText: '份额', suffixText: '份'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请输入份额';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return '份额必须大于 0';
                  return null;
                },
              ),
              const SizedBox(height: BeeDimens.p16),
              TextFormField(
                controller: _navCtrl,
                decoration: const InputDecoration(labelText: '净值', suffixText: '元/份'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请输入净值';
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 便捷方法：弹出买入弹窗。
Future<bool?> showBuyDialog(
  BuildContext context, {
  required int ledgerId,
  int? accountId,
  InvestmentHolding? holding,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => BuyDialog(
        ledgerId: ledgerId,
        accountId: accountId,
        holding: holding,
      ),
    ),
  );
}
