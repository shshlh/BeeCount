import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../styles/tokens.dart';
import '../../utils/category_utils.dart';
import '../category_icon.dart';

/// 搜索页三层筛选结果：第一层类型（收入/支出/转账），第二层一级分类，
/// 第三层二级分类。转账无二级分类。
class SearchCategoryFilterResult {
  final String? type;
  final Category? category;

  const SearchCategoryFilterResult({this.type, this.category});
}

/// 搜索页专用三层分类/类型选择器（7.13.2）。
///
/// 不修改通用 [showCategorySelector] 的行为；搜索页筛选用它替代原来的
/// 两级「all 分类」选择。
Future<SearchCategoryFilterResult?> showSearchCategoryFilter(
  BuildContext context, {
  String? currentType,
  int? currentCategoryId,
}) {
  return showDialog<SearchCategoryFilterResult>(
    context: context,
    builder: (context) => _SearchCategoryFilterDialog(
      currentType: currentType,
      currentCategoryId: currentCategoryId,
    ),
  );
}

class _SearchCategoryFilterDialog extends ConsumerStatefulWidget {
  final String? currentType;
  final int? currentCategoryId;

  const _SearchCategoryFilterDialog({
    this.currentType,
    this.currentCategoryId,
  });

  @override
  ConsumerState<_SearchCategoryFilterDialog> createState() =>
      _SearchCategoryFilterDialogState();
}

class _SearchCategoryFilterDialogState
    extends ConsumerState<_SearchCategoryFilterDialog> {
  late String? _type;
  Category? _category;
  late Future<List<Category>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _type = widget.currentType;
    _category = null;
    _categoriesFuture = _loadCategories(_type);
  }

  Future<List<Category>> _loadCategories(String? type) async {
    if (type == null || type == 'transfer') return const [];
    final repo = ref.read(repositoryProvider);
    final tops = await repo.getTopLevelCategories(type);
    final all = <Category>[...tops];
    for (final top in tops) {
      all.addAll(await repo.getSubCategories(top.id));
    }
    return all;
  }

  void _selectType(String? type) {
    setState(() {
      _type = type;
      _category = null;
      _categoriesFuture = _loadCategories(type);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: BeeTokens.scaffoldBackground(context),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: BeeTokens.scaffoldBackground(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.searchFilterTitle,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _typeChip(context, l10n.categoryIncome, 'income'),
                  const SizedBox(width: 8),
                  _typeChip(context, l10n.categoryExpense, 'expense'),
                  const SizedBox(width: 8),
                  _typeChip(context, l10n.transferTitle, 'transfer'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: FutureBuilder<List<Category>>(
                future: _categoriesFuture,
                builder: (context, snapshot) {
                  if (_type == null) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        l10n.searchSelectTypeHint,
                        style: TextStyle(
                            color: BeeTokens.textSecondary(context)),
                      ),
                    );
                  }
                  if (_type == 'transfer') {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        l10n.searchTransferNoCategory,
                        style: TextStyle(
                            color: BeeTokens.textSecondary(context)),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    );
                  }
                  final all = snapshot.data!;
                  final parents =
                      all.where((c) => c.parentId == null).toList();
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: parents.length,
                    itemBuilder: (context, index) {
                      final parent = parents[index];
                      final children =
                          all.where((c) => c.parentId == parent.id).toList();
                      return _CategoryFilterTile(
                        category: parent,
                        children: children,
                        selectedId: _category?.id,
                        onSelect: (c) {
                          setState(() => _category = c);
                        },
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.commonCancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(context, SearchCategoryFilterResult(
                        type: _type,
                        category: _category,
                      ));
                    },
                    child: Text(l10n.commonConfirm),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(BuildContext context, String label, String value) {
    final selected = _type == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _selectType(selected ? null : value),
    );
  }
}

class _CategoryFilterTile extends StatefulWidget {
  final Category category;
  final List<Category> children;
  final int? selectedId;
  final ValueChanged<Category> onSelect;

  const _CategoryFilterTile({
    required this.category,
    required this.children,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  State<_CategoryFilterTile> createState() => _CategoryFilterTileState();
}

class _CategoryFilterTileState extends State<_CategoryFilterTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isSelected = widget.selectedId == widget.category.id;
    final hasChildren = widget.children.isNotEmpty;

    return Column(
      children: [
        InkWell(
          onTap: () {
            if (hasChildren) {
              setState(() => _expanded = !_expanded);
            } else {
              widget.onSelect(widget.category);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CategoryIconWidget(category: widget.category, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    CategoryUtils.getDisplayName(widget.category.name, context),
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? primary
                          : BeeTokens.textPrimary(context),
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: primary, size: 20),
                if (hasChildren)
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: BeeTokens.iconSecondary(context),
                  ),
              ],
            ),
          ),
        ),
        if (hasChildren && _expanded)
          ...widget.children.map((child) {
            final childSelected = widget.selectedId == child.id;
            return InkWell(
              onTap: () => widget.onSelect(child),
              child: Padding(
                padding: const EdgeInsets.only(left: 48, right: 16, top: 8, bottom: 8),
                child: Row(
                  children: [
                    CategoryIconWidget(category: child, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        CategoryUtils.getDisplayName(child.name, context),
                        style: TextStyle(
                          color: childSelected
                              ? primary
                              : BeeTokens.textPrimary(context),
                          fontWeight:
                              childSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (childSelected)
                      Icon(Icons.check_circle, color: primary, size: 18),
                  ],
                ),
              ),
            );
          }),
        const Divider(height: 1),
      ],
    );
  }
}
