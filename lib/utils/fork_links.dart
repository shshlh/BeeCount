/// 自用 fork 仓库链接统一管理。
///
/// 7.0.2 起，更新检测、下载 Referer、问题反馈、捐赠、海报二维码等入口
/// 全部指向自身 fork，避免把用户引导到原仓库。
class ForkLinks {
  ForkLinks._();

  static const String gitHubBase = 'https://github.com/shshlh/BeeCount';
  static const String gitHubReleases = '$gitHubBase/releases';
  static const String gitHubIssues = '$gitHubBase/issues';
  static const String gitHubApiReleasesLatest =
      'https://api.github.com/repos/shshlh/BeeCount/releases/latest';

  static const String donateDocsZh =
      '$gitHubBase/blob/main/docs/donate/README_ZH.md';
  static const String donateDocsEn =
      '$gitHubBase/blob/main/docs/donate/README_EN.md';

  static const String supabaseWikiGuide =
      '$gitHubBase/wiki/Supabase-%E4%BA%91%E5%90%8C%E6%AD%A5%E9%85%8D%E7%BD%AE';
  static const String webdavWikiGuide =
      '$gitHubBase/wiki/WebDAV-%E4%BA%91%E5%90%8C%E6%AD%A5%E9%85%8D%E7%BD%AE';
}
