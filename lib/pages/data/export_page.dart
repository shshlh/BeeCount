import 'dart:io';
import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../../providers.dart';
import '../../data/repositories/base_repository.dart';
import '../../widgets/ui/ui.dart';
import '../../utils/category_utils.dart';
import '../../services/export/investment_csv_export_service.dart';
import '../../services/export/transaction_csv_export_service.dart';
import '../../services/export/export_file_names.dart';

class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});
  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  bool exporting = false;
  double progress = 0;
  final List<String> savedPaths = [];

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
              title: AppLocalizations.of(context).exportTitle, showBack: true),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context).exportDescription),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: exporting ? null : () => _export(repo, ledgerId),
                    icon: const Icon(Icons.save_alt_outlined),
                    label: Text(Platform.isIOS
                        ? AppLocalizations.of(context).exportButtonIOS
                        : AppLocalizations.of(context).exportButtonAndroid),
                  ),
                  const SizedBox(height: 16),
                  if (exporting)
                    Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: LinearProgressIndicator(
                              value: progress == 0 ? null : progress),
                        ),
                      ],
                    ),
                  if (savedPaths.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    for (final path in savedPaths) ...[
                      Text(AppLocalizations.of(context).exportSavedTo(path)),
                      const SizedBox(height: 4),
                    ],
                  ],
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _export(BaseRepository repo, int ledgerId) async {
    try {
      setState(() {
        exporting = true;
        progress = 0;
        savedPaths.clear();
      });
      String directory;
      bool shareAfter = false;
      if (Platform.isIOS) {
        // iOS: 写入应用文档目录，然后使用系统分享
        final docDir = await getApplicationDocumentsDirectory();
        directory = docDir.path;
        shareAfter = true;
      } else {
        // Android: 直接保存到公共 Download/BeeCount 目录
        const downloadPath = '/storage/emulated/0/Download/BeeCount';
        final dir = Directory(downloadPath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        directory = downloadPath;
      }

      final l10n = AppLocalizations.of(context);
      final csvStr = await TransactionCsvExportService(repo: repo).buildCsv(
        ledgerId: ledgerId,
        headers: [
        l10n.exportCsvHeaderType,
        l10n.exportCsvHeaderCategory,
        l10n.exportCsvHeaderSubCategory, // 二级分类名称
        l10n.exportCsvHeaderAmount,
        l10n.exportCsvHeaderCurrency, // v30 多币种:交易原币种(反馈10)
        l10n.exportCsvHeaderAccount,
        l10n.exportCsvHeaderAccountType,
        l10n.exportCsvHeaderFromAccount, // 转出账户
        l10n.exportCsvHeaderFromAccountType,
        l10n.exportCsvHeaderToAccount, // 转入账户
        l10n.exportCsvHeaderToAccountType,
        l10n.exportCsvHeaderNote,
        l10n.exportCsvHeaderTime,
        l10n.exportCsvHeaderTags,
        l10n.exportCsvHeaderAttachments, // 附件文件名（逗号分隔）
        l10n.exportCsvHeaderSyncId, // 7.9.4: 流水ID = syncId,导入幂等去重
        ],
        typeDisplayName: _getTypeDisplayName,
        categoryDisplayName: (name) => CategoryUtils.getDisplayName(name, context),
        onProgress: (done, total) {
          if (mounted) setState(() => progress = done / total);
        },
      );
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path = p.join(directory, normalCsvFileName(ts));

      // 添加UTF-8 BOM标记，确保Excel正确识别中文编码
      const utf8Bom = '\uFEFF';
      await File(path).writeAsString(utf8Bom + csvStr,
          encoding: Encoding.getByName('utf-8')!);

      // 7.8.1: 同时生成投资 CSV（持仓 / 投资流水 / 分组归属）。
      final investmentCsv = await InvestmentCsvExportService(
        investmentRepo: ref.read(investmentRepositoryProvider),
        repo: repo,
      ).buildCsv(ledgerId: ledgerId);
      final investmentPath = p.join(directory, investmentCsvFileName(ts));
      await File(investmentPath).writeAsString(utf8Bom + investmentCsv,
          encoding: Encoding.getByName('utf-8')!);

      setState(() {
        savedPaths
          ..add(path)
          ..add(investmentPath);
        exporting = false;
        progress = 1;
      });
      if (!mounted) return;
      final l10nDialog = AppLocalizations.of(context);
      if (shareAfter) {
        // 触发分享面板
        await Share.shareXFiles(
          [XFile(path), XFile(investmentPath)],
          text: l10nDialog.exportShareText,
        );
        await AppDialog.info(context,
            title: l10nDialog.exportSuccessTitle,
            message: l10nDialog.exportSuccessMessageIOS(savedPaths.join('\n')));
      } else {
        await AppDialog.info(context,
            title: l10nDialog.exportSuccessTitle,
            message:
                l10nDialog.exportSuccessMessageAndroid(savedPaths.join('\n')));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => exporting = false);
      final l10nError = AppLocalizations.of(context);
      await AppDialog.error(context,
          title: l10nError.exportFailedTitle, message: e.toString());
    }
  }

  /// 将英文类型转换为中文显示名称
  String _getTypeDisplayName(String type) {
    final l10nType = AppLocalizations.of(context);
    switch (type) {
      case 'income':
        return l10nType.exportTypeIncome;
      case 'expense':
        return l10nType.exportTypeExpense;
      case 'transfer':
        return l10nType.exportTypeTransfer;
      default:
        return type; // 兜底返回原始值
    }
  }
}
