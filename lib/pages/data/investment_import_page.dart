import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../services/billing/post_processor.dart';
import '../../services/import/investment_csv_import_service.dart';
import '../../styles/tokens.dart';
import '../../widgets/ui/ui.dart';

/// 投资数据专用导入页（7.10.3）。
///
/// 由 [ImportPage] 在检测到 `_investments_` 文件名时进入，直接解析并恢复
/// 持仓 / 投资流水 / 分组，不走通用 CSV 映射流程。
class InvestmentImportPage extends ConsumerStatefulWidget {
  final String csvText;

  const InvestmentImportPage({super.key, required this.csvText});

  @override
  ConsumerState<InvestmentImportPage> createState() =>
      _InvestmentImportPageState();
}

class _InvestmentImportPageState extends ConsumerState<InvestmentImportPage> {
  bool _importing = true;
  InvestmentImportResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final repo = ref.read(repositoryProvider);
    final investmentRepo = ref.read(investmentRepositoryProvider);
    final ledgerId = ref.read(currentLedgerIdProvider);
    try {
      final result = await InvestmentCsvImportService(
        repo: repo,
        investmentRepo: investmentRepo,
      ).importCsv(ledgerId: ledgerId, csvText: widget.csvText);
      if (!mounted) return;
      setState(() {
        _importing = false;
        _result = result;
      });

      ref.invalidate(currentHoldingsProvider);
      ref.invalidate(countsForLedgerProvider(ledgerId));
      ref.read(statsRefreshProvider.notifier).state++;
      try {
        // ignore: unawaited_futures
        PostProcessor.sync(ref, ledgerId: ledgerId);
      } catch (_) {
        // 同步触发失败不阻断导入完成。
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(title: l10n.importInvestmentTitle, showBack: true),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _importing
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_error != null) ...[
                            Icon(Icons.error_outline,
                                color: Theme.of(context).colorScheme.error,
                                size: 40),
                            const SizedBox(height: 12),
                            Text(
                              l10n.importInvestmentFailed(_error!),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: BeeTokens.textSecondary(context)),
                            ),
                          ] else if (_result != null) ...[
                            Icon(Icons.check_circle_outline,
                                color: Theme.of(context).colorScheme.primary,
                                size: 40),
                            const SizedBox(height: 12),
                            Text(
                              l10n.importInvestmentResult(
                                _result!.holdingsImported,
                                _result!.flowsImported,
                                _result!.flowsSkipped,
                                _result!.groupsImported,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(l10n.importInvestmentDone),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
