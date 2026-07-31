import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart';
import '../../providers.dart';
import '../../styles/tokens.dart';
import '../../utils/account_type_utils.dart';

/// 买入弹窗 — 填写基金代码、名称、份额、净值、手续费、扣款账户。
///
/// v4.7: 买入视为"扣款账户 → 投资账户"的转账，不再创建单独的 expense 交易。
/// 扣款账户下拉仅显示可交易账户（排除投资/债权/负债）。
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
  int? _selectedAccountId; // 扣款账户
  int? _selectedInvestmentAccountId; // 持仓归属的投资账户
  List<Account> _tradableAccounts = [];
  List<Account> _investmentAccounts = [];

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
        // v4.7: 只显示可交易账户（排除投资/债权/负债），避免转账到自身
        _tradableAccounts = accounts.where((a) => isTradableType(a.type)).toList();
        _investmentAccounts = accounts
            .where((a) => normalizeAccountType(a.type) == accountTypeInvestment)
            .toList();
        _selectedAccountId = widget.holding != null
            ? (_tradableAccounts.isNotEmpty ? _tradableAccounts.first.id : null)
            : (widget.accountId != null && _tradableAccounts.any((a) => a.id == widget.accountId)
                ? widget.accountId
                : (_tradableAccounts.isNotEmpty ? _tradableAccounts.first.id : null));
        _selectedInvestmentAccountId =
            _investmentAccounts.isNotEmpty ? _investmentAccounts.first.id : null;
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

      // v4.7 返工：持仓归属必须是投资账户。已有持仓沿用其账户；
      // 新买入由用户选择，未选时仓库自动创建，绝不把扣款账户当持仓归属。
      final investmentAccountId =
          widget.holding?.accountId ?? _selectedInvestmentAccountId;
      await service.buy(
        ledgerId: widget.ledgerId,
        accountId: investmentAccountId,
        fundCode: _codeCtrl.text.trim(),
        fundName: _nameCtrl.text.trim(),
        shares: shares,
        nav: nav,
        fee: parsedFee,
        holdingId: effectiveHoldingId,
        sourceAccountId: _selectedAccountId!,
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
              const SizedBox(height: BeeDimens.p16),
              // v4.7 返工：新买入先确定投资账户；无投资账户时保存会自动创建。
              if (widget.holding == null) ...[
                if (_investmentAccounts.isNotEmpty)
                  DropdownButtonFormField<int>(
                    key: ValueKey('investment-${_investmentAccounts.length}'),
                    initialValue: _selectedInvestmentAccountId,
                    decoration: const InputDecoration(labelText: '投资账户'),
                    items: _investmentAccounts.map((a) => DropdownMenuItem(
                      value: a.id,
                      child: Text(a.name),
                    )).toList(),
                    onChanged: (v) =>
                        setState(() => _selectedInvestmentAccountId = v),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '尚未创建投资账户，保存时将自动创建「投资账户」',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                const SizedBox(height: BeeDimens.p16),
              ],
              DropdownButtonFormField<int>(
                key: ValueKey(_tradableAccounts.length),
                initialValue: _selectedAccountId,
                decoration: const InputDecoration(labelText: '扣款账户'),
                items: _tradableAccounts.map((a) => DropdownMenuItem(
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

