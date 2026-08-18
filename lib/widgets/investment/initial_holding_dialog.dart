/// 初始持仓导入弹窗。
///
/// 用于批量导入已有投资记录（从其它平台迁移数据）。
/// 与 buy 不同，此弹窗直接指定初始份额和成本，
/// 不产生扣款交易。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db.dart' as db;
import '../../providers.dart';
import '../../utils/account_type_utils.dart';

/// 打开初始持仓导入弹窗。
/// 返回 true 表示导入成功，false/null 表示取消。
Future<bool?> showInitialHoldingDialog(
  BuildContext context, {
  required int? ledgerId,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _InitialHoldingDialog(ledgerId: ledgerId),
  );
}

class _InitialHoldingDialog extends ConsumerStatefulWidget {
  final int? ledgerId;
  const _InitialHoldingDialog({required this.ledgerId});

  @override
  ConsumerState<_InitialHoldingDialog> createState() =>
      _InitialHoldingDialogState();
}

class _InitialHoldingDialogState extends ConsumerState<_InitialHoldingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fundCodeCtrl = TextEditingController();
  final _fundNameCtrl = TextEditingController();
  final _sharesCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _navCtrl = TextEditingController();
 final _noteCtrl = TextEditingController();
 final DateTime _happenedAt = DateTime.now();
 bool _isQdii = false;
 int? _selectedAccountId;
  List<db.Account> _investmentAccounts = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  void _loadAccounts() {
    final int ledgerId =
        widget.ledgerId ?? ref.read(currentLedgerIdProvider);
    final accountsAsync = ref.read(accountsStreamProvider(ledgerId));
    final accounts = accountsAsync.asData?.value ?? [];
    // 只显示投资类账户
    _investmentAccounts = accounts
        .where((a) => normalizeAccountType(a.type) == accountTypeInvestment)
        .toList();
    if (_investmentAccounts.isNotEmpty) {
      _selectedAccountId = _investmentAccounts.first.id;
    }
  }

  @override
  void dispose() {
    _fundCodeCtrl.dispose();
    _fundNameCtrl.dispose();
    _sharesCtrl.dispose();
    _costCtrl.dispose();
    _navCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择投资账户')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final service = ref.read(investmentServiceProvider);
      await service.createInitialHolding(
        ledgerId: widget.ledgerId!,
        accountId: _selectedAccountId!,
        fundCode: _fundCodeCtrl.text.trim(),
        fundName: _fundNameCtrl.text.trim(),
        shares: double.parse(_sharesCtrl.text),
        cost: double.parse(_costCtrl.text),
        nav: double.parse(_navCtrl.text),
        happenedAt: _happenedAt,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        isQdii: _isQdii,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('导入初始持仓'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 投资账户
              if (_investmentAccounts.isNotEmpty) ...[
                 DropdownButtonFormField<int>(
                  initialValue: _selectedAccountId,
                  decoration: const InputDecoration(
                    labelText: '投资账户',
                    isDense: true,
                  ),
                  items: _investmentAccounts.map((a) {
                    return DropdownMenuItem(
                      value: a.id,
                      child: Text(a.name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedAccountId = v),
                ),
                const SizedBox(height: 12),
              ],
              // 基金代码
              TextFormField(
                controller: _fundCodeCtrl,
                decoration: const InputDecoration(
                  labelText: '基金代码',
                  hintText: '如 000001',
                  isDense: true,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请输入基金代码';
                  if (!RegExp(r'^\d{6}$').hasMatch(v.trim())) {
                    return '基金代码必须为6位数字';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // 基金名称
              TextFormField(
                controller: _fundNameCtrl,
                decoration: const InputDecoration(
                  labelText: '基金名称',
                  hintText: '如 华夏成长混合',
                  isDense: true,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '请输入基金名称' : null,
              ),
              const SizedBox(height: 12),
              // 份额 + 成本并排
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _sharesCtrl,
                      decoration: const InputDecoration(
                        labelText: '份额',
                        isDense: true,
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return '请输入份额';
                        final n = double.tryParse(v);
                        if (n == null || n <= 0) return '份额必须大于0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _costCtrl,
                      decoration: const InputDecoration(
                        labelText: '持仓成本',
                        isDense: true,
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return '请输入成本';
                        final n = double.tryParse(v);
                        if (n == null || n <= 0) return '成本必须大于0';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 净值
              TextFormField(
                controller: _navCtrl,
                decoration: const InputDecoration(
                  labelText: '当前净值',
                  isDense: true,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请输入净值';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return '净值必须大于0';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('QDII 基金'),
                subtitle: const Text('净值日通常滞后 1~2 个交易日'),
                value: _isQdii,
                onChanged: (v) => setState(() => _isQdii = v),
              ),
              const SizedBox(height: 4),
              // 备注
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('导入'),
        ),
      ],
    );
  }
}
