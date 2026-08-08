import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../styles/tokens.dart';
import '../../utils/ui_scale_extensions.dart';
import '../../widgets/biz/biz.dart';
import '../../widgets/ui/ui.dart';

/// 本地 AI 设置与使用说明页。
class AiTutorialPage extends ConsumerWidget {
  const AiTutorialPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.aiSettingsTitle,
            subtitle: 'AI 设置与使用',
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
                  title: '服务商配置',
                  body: '在「我的 → AI 设置 → 服务商管理」添加服务商并填写 API Key，'
                      '常见服务商可点击「获取 Key」进入官网申请。',
                ),
                SizedBox(height: 12.0.scaled(context, ref)),
                _section(
                  context,
                  ref,
                  title: l10n.aiCapabilitySelectTitle,
                  body: '文本、视觉、语音三种能力分别绑定已配置的服务商；'
                      '未绑定的能力在对应记账入口会提示先去设置。',
                ),
                SizedBox(height: 12.0.scaled(context, ref)),
                _section(
                  context,
                  ref,
                  title: '图片 / 拍照记账',
                  body: '首页长按底部「+」选择「相册」或「拍照」，'
                      'AI 视觉模型会自动识别金额、商家、时间等信息。',
                ),
                SizedBox(height: 12.0.scaled(context, ref)),
                _section(
                  context,
                  ref,
                  title: '语音记账',
                  body: '首页长按底部「+」选择「语音」，说出记账内容即可；'
                      '需先绑定语音服务商。',
                ),
                SizedBox(height: 12.0.scaled(context, ref)),
                _section(
                  context,
                  ref,
                  title: '截图自动识别',
                  body: '在智能记账设置中开启截图识别，支付截图会自动进入识别流程；'
                      '识别结果可在通知中确认。',
                ),
                SizedBox(height: 12.0.scaled(context, ref)),
                _section(
                  context,
                  ref,
                  title: l10n.aiChatTitle,
                  body: 'AI 小助手支持对话分析、财务健康检查、月度总结、'
                      '分类占比与预算规划等快捷指令。',
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
