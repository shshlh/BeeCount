import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart';
import '../../providers.dart';
import '../../styles/tokens.dart';

/// 买入弹窗 — 填写基金代码、名称、份额、净值、手续费、扣款账户。
///
/// 如果从持仓详情进入（传入 [holding]），则自动预填基金信息。
/// 若用户修改了基金代码，则创建新持仓而非追加到原持仓。
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
  int? _selectedAccountId;
  List<Account> _accounts = [];

  @override
  void initState() {
    super.initState();
    final h = widget.holding;
    _codeCtrl = TextEditingController(text: h?.fundCode ?? '');
    _nameCtrl = TextEditingController(text: h?.fundName ?? '');
    _sharesCtrl = TextEditingController();
    _navCtrl = TextEditingController(text: h != null && h.currentNav > 0 ? h.currentNav.toString() : '');
    _feeCtrl = TextEditingController(text: '0');
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accounts = await ref.read(repositoryProvider).getAvailableAccountsForLedger(widget.ledgerId);
    if (mounted) {
      setState(() {
        _accounts = accounts;
        _selectedAccountId = widget.accountId ?? (accounts.isNotEmpty ? accounts.first.id : null);
      });
    }
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
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择扣款账户')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final service = ref.read(investmentServiceProvider);
      final shares = double.parse(_sharesCtrl.text);
      final nav = double.parse(_navCtrl.text);
      service.validateBuy(shares: shares, nav: nav);

      // 当用户修改了基金代码（与预填不同），holdingId 置 null 创建新持仓
      final effectiveHoldingId = (_codeCtrl.text.trim() == widget.holding?.fundCode)
          ? widget.holding?.id
          : null;
      final parsedFee = double.tryParse(_feeCtrl.text) ?? 0;

      await service.buy(
        ledgerId: widget.ledgerId,
        accountId: _selectedAccountId!,
        fundCode: _codeCtrl.text.trim(),
        fundName: _nameCtrl.text.trim(),
        shares: shares,
        nav: nav,
        fee: parsedFee,
        holdingId: effectiveHoldingId,
      );

      // 买入后插入 expense 交易扣减扣款账户余额
      final totalCost = shares * nav + parsedFee;
      await ref.read(repositoryProvider).addTransaction(
        ledgerId: widget.ledgerId,
        type: 'expense',
        amount: totalCost,
        accountId: _selectedAccountId!,
        happenedAt: DateTime.now(),
        note: '买入 ${_codeCtrl.text.trim()}',
        excludeFromBudget: true,
      );

      // NOTE(tech-debt): service.buy() 和 addTransaction() 无共享事务边界。
      // 若 addTransaction 失败，买入已提交但余额未扣减。
      // 修复需将扣款逻辑整合进 Repository 层 buy 事务内部（非 UI 层职责）。
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
              const SizedBox(height: BeeDimens.p16),
              DropdownButtonFormField<int>(
                key: ValueKey(_accounts.length),
                initialValue: _selectedAccountId,
                decoration: const InputDecoration(labelText: '扣款账户'),
                items: _accounts.map((a) => DropdownMenuItem(
                  value: a.id,
                  child: Text(a.name),
                )).toList(),
                onChanged: (v) => setState(() => _selectedAccountId = v),
                validator: (_) => _selectedAccountId == null ? '请选择扣款账户' : null,
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
