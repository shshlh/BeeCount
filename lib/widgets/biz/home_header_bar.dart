import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../pages/ai/ai_chat_page.dart';
import '../../pages/calendar/calendar_page.dart';
import '../../pages/main/ledgers_page_new.dart';
import '../../providers.dart';
import '../../utils/format_utils.dart';
import 'bee_icon.dart';
import 'ledger_picker_sheet.dart';

/// 首页顶部操作栏：BeeIcon + 账本切换胶囊 + AI 助手/日历。
/// v5.9 从明细页迁到首页，明细页不再重复渲染。
class HomeHeaderBar extends ConsumerWidget {
  const HomeHeaderBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiEnabledAsync = ref.watch(aiAssistantEnabledProvider);
    final aiEnabled = aiEnabledAsync.asData?.value ?? true; // 默认开启

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          BeeIcon(
            color: Theme.of(context).colorScheme.primary,
            size: 28,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Row(
              children: [
                Text(
                  AppLocalizations.of(context).homeAppTitle,
                  maxLines: 1,
                  softWrap: false,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Consumer(builder: (context, ref, _) {
                      final currentLedger = ref.watch(currentLedgerProvider);
                      return currentLedger.when(
                        skipLoadingOnReload: true,
                        data: (ledger) {
                          final isEmpty = ledger == null;
                          return GestureDetector(
                            onTap: () {
                              if (isEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LedgersPageNew(autoOpenCreateDialog: true),
                                  ),
                                );
                              } else {
                                showLedgerPicker(context);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isEmpty) ...[
                                    Icon(
                                      Icons.add,
                                      size: 16,
                                      color: Theme.of(context).textTheme.bodyLarge?.color,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Flexible(
                                    child: Text(
                                      isEmpty
                                          ? AppLocalizations.of(context).ledgersNew
                                          : translateLedgerName(context, ledger.name),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: false,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Theme.of(context).textTheme.bodyLarge?.color,
                                      ),
                                    ),
                                  ),
                                  if (!isEmpty && ledger.isShared) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.handshake,
                                      size: 12,
                                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                    ),
                                    const SizedBox(width: 1),
                                    Text(
                                      '${ledger.memberCount}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                  if (!isEmpty) ...[
                                    const SizedBox(width: 2),
                                    Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 16,
                                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          if (aiEnabled)
            IconButton(
              tooltip: AppLocalizations.of(context).aiChatTitle,
              padding: const EdgeInsets.all(8),
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: Size.zero,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AIChatPage(),
                  ),
                );
              },
              icon: Icon(
                Icons.auto_awesome_outlined,
                size: 20,
                color: Theme.of(context).iconTheme.color,
              ),
            ),
          IconButton(
            tooltip: AppLocalizations.of(context).calendarTitle,
            padding: const EdgeInsets.all(6),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              minimumSize: Size.zero,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CalendarPage(),
                ),
              );
            },
            icon: Icon(
              Icons.calendar_month_outlined,
              size: 20,
              color: Theme.of(context).iconTheme.color,
            ),
          ),
        ],
      ),
    );
  }
}
