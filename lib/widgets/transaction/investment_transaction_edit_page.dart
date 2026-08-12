import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/db.dart';
import '../../pages/tag/widgets/tag_selector.dart';
import '../../providers.dart';
import '../../styles/tokens.dart';
import '../ui/wheel_date_picker.dart';

/// 7.6.2: 投资流水受限编辑页。
///
/// 只允许改日期/时间、备注、标签；金额/净值/份额/账户/分类/类型在持仓
/// 详情页维护，避免通用编辑器改动后与持仓统计脱钩。
class InvestmentTransactionEditPage extends ConsumerStatefulWidget {
  final Transaction transaction;

  const InvestmentTransactionEditPage({
    super.key,
    required this.transaction,
  });

  @override
  ConsumerState<InvestmentTransactionEditPage> createState() =>
      _InvestmentTransactionEditPageState();
}

class _InvestmentTransactionEditPageState
    extends ConsumerState<InvestmentTransactionEditPage> {
  late DateTime _happenedAt;
  late final TextEditingController _noteCtrl;
  List<int> _tagIds = [];
  Map<int, String> _tagNames = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    _happenedAt = DateTime(tx.happenedAt.year, tx.happenedAt.month,
        tx.happenedAt.day, tx.happenedAt.hour, tx.happenedAt.minute);
    _noteCtrl = TextEditingController(text: tx.note ?? '');
    _loadTags();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    final repo = ref.read(repositoryProvider);
    final tags = await repo.getTagsForTransaction(widget.transaction.id);
    final all = await repo.getAllTags();
    if (!mounted) return;
    setState(() {
      _tagIds = [for (final t in tags) t.id];
      _tagNames = {for (final t in all) t.id: t.name};
    });
  }

  Future<void> _pickDate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showWheelDateTimePicker(
      context,
      initial: _happenedAt,
      maxDate: DateTime.now(),
    );
    if (picked != null && mounted) setState(() => _happenedAt = picked);
  }

  Future<void> _pickTags() async {
    final result = await TagSelector.show(context, selectedTagIds: _tagIds);
    if (result != null && mounted) setState(() => _tagIds = result);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(repositoryProvider);
      final tx = widget.transaction;
      await repo.updateTransaction(
        id: tx.id,
        type: tx.type,
        amount: tx.amount,
        categoryId: tx.categoryId,
        note: _noteCtrl.text.trim(),
        happenedAt: _happenedAt,
        accountId: tx.accountId,
        categorySyncIdOverride: tx.categorySyncIdOverride,
        accountSyncIdOverride: tx.accountSyncIdOverride,
        toAccountSyncIdOverride: tx.toAccountSyncIdOverride,
        excludeFromStats: tx.excludeFromStats,
        excludeFromBudget: tx.excludeFromBudget,
        currencyCode: tx.currencyCode,
        nativeAmount: tx.nativeAmount,
      );

      final normalTagIds = _tagIds.where((id) => id >= 0).toList();
      if (normalTagIds.isNotEmpty) {
        await repo.updateTransactionTags(
          transactionId: tx.id,
          tagIds: normalTagIds,
        );
      } else {
        await repo.removeAllTagsFromTransaction(tx.id);
      }

      if (mounted) Navigator.of(context).pop(true);
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
    final selectedNames = [
      for (final id in _tagIds)
        if (_tagNames[id] != null) _tagNames[id]!,
    ];
    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      appBar: AppBar(
        title: const Text('编辑投资流水'),
        backgroundColor: BeeTokens.surface(context),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: BeeTokens.surface(context),
            border: Border(
              top: BorderSide(color: BeeTokens.divider(context)),
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存'),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: '日期',
                isDense: true,
              ),
              child: Text(DateFormat('yyyy-MM-dd HH:mm').format(_happenedAt)),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: '备注', isDense: true),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickTags,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: '标签',
                isDense: true,
              ),
              child: Text(
                selectedNames.isEmpty ? '未选择' : selectedNames.join('、'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
