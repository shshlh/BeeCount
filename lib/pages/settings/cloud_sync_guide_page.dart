import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../styles/tokens.dart';
import '../../utils/ui_scale_extensions.dart';
import '../../widgets/biz/biz.dart';
import '../../widgets/ui/ui.dart';

/// 本地云同步设置说明页。
///
/// 登录页「注册指引」改为打开本页，不再跳转原官网文档。
class CloudSyncGuidePage extends ConsumerWidget {
  const CloudSyncGuidePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.cloudTutorialTitle,
            subtitle: '云同步设置说明',
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
                _section(
                  context,
                  ref,
                  title: l10n.cloudCustomSupabaseTitle,
                  body: '在云服务页选择「自定义 Supabase」，填入 Supabase 项目 URL 与 anon key。'
                      '适合已有 Supabase 账号、希望使用官方托管服务的用户。',
                ),
                SizedBox(height: 12.0.scaled(context, ref)),
                _section(
                  context,
                  ref,
                  title: l10n.cloudCustomWebdavTitle,
                  body: '选择 WebDAV 后填写服务器地址、用户名与密码（建议使用应用专用密码），'
                      '并指定远程路径，例如坚果云 / Nextcloud / NAS。',
                ),
                SizedBox(height: 12.0.scaled(context, ref)),
                _section(
                  context,
                  ref,
                  title: l10n.cloudBeeCountCloudTitle,
                  body: '自建服务器可使用 Docker 一行命令部署，首次启动日志中会打印管理员账号；'
                      '加入他人服务器时，让管理员在 Web 后台为你添加账号，然后填写服务器地址登录。',
                ),
                SizedBox(height: 12.0.scaled(context, ref)),
                _section(
                  context,
                  ref,
                  title: l10n.cloudCustomS3Title,
                  body: '支持 AWS S3 / Cloudflare R2 / MinIO 等 S3 协议存储，'
                      '在云服务页配置 Endpoint、Access Key 与 Bucket 即可。',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
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
