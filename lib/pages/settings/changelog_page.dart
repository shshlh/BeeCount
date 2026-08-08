import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../styles/tokens.dart';
import '../../utils/ui_scale_extensions.dart';
import '../../widgets/biz/biz.dart';
import '../../widgets/ui/ui.dart';

/// 本地静态更新日志页。
///
/// 自用版不再打开原官网 beejz.com，历史与新增版本记录直接以内置文案展示。
class ChangelogPage extends ConsumerWidget {
  const ChangelogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.aboutChangelog,
            subtitle: l10n.changelogIntro,
            showBack: true,
            compact: true,
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16.0.scaled(context, ref),
                8.0.scaled(context, ref),
                16.0.scaled(context, ref),
                24.0.scaled(context, ref),
              ),
              children: [
                _versionCard(
                  context,
                  ref,
                  title: l10n.changelogV70Title,
                  body: l10n.changelogV70Body,
                ),
                SizedBox(height: 12.0.scaled(context, ref)),
                _versionCard(
                  context,
                  ref,
                  title: l10n.changelogV613Title,
                  body: l10n.changelogV613Body,
                ),
                SizedBox(height: 12.0.scaled(context, ref)),
                _versionCard(
                  context,
                  ref,
                  title: l10n.changelogV60Title,
                  body: l10n.changelogV60Body,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _versionCard(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String body,
  }) {
    return SectionCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15.0.scaled(context, ref),
              fontWeight: FontWeight.w600,
              color: BeeTokens.textPrimary(context),
            ),
          ),
          SizedBox(height: 8.0.scaled(context, ref)),
          Text(
            body,
            style: TextStyle(
              fontSize: 13.0.scaled(context, ref),
              height: 1.6,
              color: BeeTokens.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}
