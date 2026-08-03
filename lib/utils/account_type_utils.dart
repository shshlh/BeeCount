import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../l10n/app_localizations.dart';
import '../services/custom_icon_service.dart';

/// v4.5 账户体系改造：7 个一级类型，取消资产/负债二分法
///
/// 7 个一级类型（按展示顺序）：
///   cash           — 现金（钱包、备用金）
///   bank_card      — 储蓄（借记卡、存折）
///   virtual_account — 虚拟账户（支付宝/微信/公交卡等电子支付）
///   receivable     — 债权（借出款、应收款）
///   credit_card    — 信用（信用卡、花呗、白条）
///   loan           — 负债（房贷、车贷、消费贷）
///   investment     — 投资（基金、股票、理财、不动产、保险等）
///
/// 旧类型兼容映射：alipay/wechat → virtual_account；real_estate/vehicle/
/// insurance/social_fund → investment；other_account → bank_card。

// ─────────────────────── 类型常量 ───────────────────────

/// 一级账户类型：现金
const accountTypeCash = 'cash';
/// 一级账户类型：储蓄
const accountTypeBankCard = 'bank_card';
/// 一级账户类型：虚拟账户
const accountTypeVirtualAccount = 'virtual_account';
/// 一级账户类型：债权
const accountTypeReceivable = 'receivable';
/// 一级账户类型：信用
const accountTypeCreditCard = 'credit_card';
/// 一级账户类型：负债
const accountTypeLoan = 'loan';
/// 一级账户类型：投资
const accountTypeInvestment = 'investment';

/// 全部 7 个一级类型（按展示顺序：先资产→债权→信用→负债→投资）
const allAccountTypes = [
  accountTypeCash,
  accountTypeBankCard,
  accountTypeVirtualAccount,
  accountTypeReceivable,
  accountTypeCreditCard,
  accountTypeLoan,
  accountTypeInvestment,
];

/// 资产类账户类型列表（用于资产区展示排序）
const assetTypeOrder = [
  accountTypeCash,
  accountTypeBankCard,
  accountTypeVirtualAccount,
  accountTypeReceivable,
  accountTypeInvestment,
];

/// 负债类账户类型列表（用于负债区展示排序）
const liabilityTypeOrder = [
  accountTypeCreditCard,
  accountTypeLoan,
];

// ─────────────────────── 旧类型映射 ───────────────────────

/// 旧版类型字符串 → 新版类型字符串
/// 在 v33 数据库迁移中已执行映射，此函数仅供代码层兼容性使用
String normalizeAccountType(String type) {
  switch (type) {
    case 'alipay': return accountTypeVirtualAccount;
    case 'wechat': return accountTypeVirtualAccount;
    case 'real_estate': return accountTypeInvestment;
    case 'vehicle': return accountTypeInvestment;
    case 'insurance': return accountTypeInvestment;
    case 'social_fund': return accountTypeInvestment;
    case 'other_account': return accountTypeBankCard;
    default: return allAccountTypes.contains(type) ? type : accountTypeCash;
  }
}

// ─────────────────────── 资产/负债分类 ───────────────────────

/// 账户分类：资产 vs 负债
/// 注意：此分类仅用于净资产计算（总资产 = sum(资产余额) - sum(|负债余额|)）
enum AccountClassification { asset, liability }

/// 是否为负债类型
bool isLiabilityType(String type) =>
    type == accountTypeCreditCard || type == accountTypeLoan;

/// 获取账户的资产/负债分类
AccountClassification getAccountClassification(String type) {
  if (isLiabilityType(type)) return AccountClassification.liability;
  return AccountClassification.asset;
}

/// 是否为资产类型
bool isAssetType(String type) => !isLiabilityType(type);

/// 是否为估值/投资类账户（不参与日常收支记账的账户选择器）
/// v4.9: 应收款(receivable)移出估值类型 —— 余额语义 = 初始资金 + 流水,
/// 详情页不再提供「更新估值」入口;仅 investment / loan 保留估值语义。
bool isValuationOrInvestmentType(String type) {
  return type == accountTypeInvestment || type == accountTypeLoan;
}

/// 是否为可交易账户类型（参与日常转账/支出选择器）
/// 排除投资、债权、负债（这些通过专有流程操作）
bool isTradableType(String type) {
  final t = normalizeAccountType(type);
  return t != accountTypeInvestment && t != accountTypeReceivable && t != accountTypeLoan;
}

/// 是否为记账可选账户类型（支出/收入/转账的账户选择器）
/// v5.0: 放开债权(receivable)/负债(loan)，仅投资账户保持不可选（投资走专属流程）
bool isBookingAccountType(String type) {
  return normalizeAccountType(type) != accountTypeInvestment;
}

// ─────────────────────── 图标 ───────────────────────

/// 获取账户类型的 Material 图标（备用，用于无 SVG 的场景）
IconData getIconForAccountType(String type) {
  switch (normalizeAccountType(type)) {
    case 'cash':
      return Icons.payments_outlined;
    case 'bank_card':
      return Icons.credit_card;
    case 'virtual_account':
      return Icons.phone_android;
    case 'credit_card':
      return Icons.credit_score;
    case 'investment':
      return Icons.trending_up;
    case 'loan':
      return Icons.house_outlined;
    case 'receivable':
      return Icons.call_received;
    default:
      return Icons.account_balance_wallet_outlined;
  }
}

/// 获取账户类型名称
String getAccountTypeLabel(BuildContext context, String type) {
  final l10n = AppLocalizations.of(context);
  switch (normalizeAccountType(type)) {
    case 'cash':
      return l10n.accountTypeCash;
    case 'bank_card':
      return l10n.accountTypeBankCard;
    case 'virtual_account':
      return l10n.accountTypeVirtualAccount;
    case 'credit_card':
      return l10n.accountTypeCreditCard;
    case 'investment':
      return l10n.accountTypeInvestment;
    case 'loan':
      return l10n.accountTypeLoan;
    case 'receivable':
      return l10n.accountTypeReceivable;
    default:
      return type;
  }
}

/// 获取账户类型的品牌颜色
Color getColorForAccountType(String type, Color primaryColor) {
  switch (normalizeAccountType(type)) {
    case 'cash':
      return Colors.orange;
    case 'bank_card':
      return const Color(0xFF1890FF);
    case 'virtual_account':
      return const Color(0xFF00B96B);
    case 'credit_card':
      return Colors.purple;
    case 'investment':
      return const Color(0xFFFF9800);
    case 'loan':
      return const Color(0xFFE91E63);
    case 'receivable':
      return const Color(0xFF009688);
    default:
      return primaryColor;
  }
}

/// 获取 SVG 路径（所有类型均有彩色 SVG）
String _getSvgPath(String type) {
  switch (normalizeAccountType(type)) {
    case 'cash':
      return 'assets/icons/cash.svg';
    case 'bank_card':
      return 'assets/icons/bank_card.svg';
    case 'virtual_account':
      return 'assets/icons/virtual_account.svg';
    case 'credit_card':
      return 'assets/icons/credit_card.svg';
    case 'investment':
      return 'assets/icons/investment.svg';
    case 'loan':
      return 'assets/icons/loan.svg';
    case 'receivable':
      return 'assets/icons/receivable.svg';
    default:
      return 'assets/icons/cash.svg';
  }
}

/// 统一的账户类型图标 Widget
/// 所有类型均使用彩色 SVG 图标
/// 设置 [monochrome] 为 true + [color] 可将图标渲染为单色（用于渐变卡片上的白色图标）
class AccountTypeIcon extends StatelessWidget {
  final String type;
  final double size;
  final Color? color;
  /// 是否以单色模式渲染（忽略 SVG 原始颜色，统一用 [color] 着色）
  final bool monochrome;
  /// v5.6: 自定义 logo（iconType='custom' 时使用 customIconPath 渲染图片）
  final String? iconType;
  final String? customIconPath;

  const AccountTypeIcon({
    super.key,
    required this.type,
    this.size = 20,
    this.color,
    this.monochrome = false,
    this.iconType,
    this.customIconPath,
  });

  @override
  Widget build(BuildContext context) {
    if (iconType == 'custom' && customIconPath != null) {
      return FutureBuilder<String>(
        future: CustomIconService().resolveIconPath(customIconPath!),
        builder: (context, snapshot) {
          final path = snapshot.data;
          if (snapshot.hasData && path != null && File(path).existsSync()) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.25),
              child: Image.file(
                File(path),
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _defaultIcon(context),
              ),
            );
          }
          return _defaultIcon(context);
        },
      );
    }
    return _defaultIcon(context);
  }

  Widget _defaultIcon(BuildContext context) {
    return SvgPicture.asset(
      _getSvgPath(type),
      width: size,
      height: size,
      colorFilter: monochrome && color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );
  }
}
