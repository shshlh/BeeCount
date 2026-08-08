import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 7.0.2 全仓原仓库链接清理的回归扫描。
///
/// 明确保留 TNT-Likely 的位置：
/// - docs/HANDOFF.md：追加型历史交接记录，禁止改写；
/// - LICENSE / LICENSE_EN / COMMERCIAL_LICENSE.md / CONTRIBUTING.md：上游法律归属；
/// - docs/contributing/*：上游贡献指南，含 upstream remote 语义，不属于用户可见链接；
/// - README 中仅以作者名出现的纯文本 TNT-Likely（无 URL）。
/// - lib/l10n 的 aboutSelfUse 系列文案：7.0.1「自用说明」按需求保留原作者链接归属。
/// - lib 中帮助页/更新日志的历史注释提及 beejz.com（非用户可见链接），扫描跳过注释行。
const originalRepoOwnerPath = 'TNT-Likely/BeeCount';

void main() {
  group('更新链路链接断言', () {
    final wiredFiles = [
      'lib/services/update/update_checker.dart',
      'lib/services/update/update_downloader.dart',
      'lib/services/update/update_dialogs.dart',
      'lib/pages/auth/welcome_page.dart',
      'lib/pages/cloud/cloud_service_page.dart',
      'lib/pages/settings/about_page.dart',
      'lib/widgets/posters/app_promo_poster.dart',
      'lib/widgets/posters/user_profile_poster.dart',
      'lib/widgets/posters/month_summary_poster.dart',
      'lib/widgets/posters/ledger_summary_poster.dart',
      'lib/widgets/posters/year_summary_poster.dart',
      'lib/widgets/posters/annual_report_poster.dart',
    ];

    for (final file in wiredFiles) {
      test('$file 已接入 ForkLinks', () {
        final content = File(file).readAsStringSync();
        expect(content, contains('ForkLinks'),
            reason: '更新/分享/海报链接应统一走 ForkLinks，而不是硬编码原仓库');
        expect(content.contains('TNT-Likely'), isFalse);
      });
    }
  });

  group('全仓原仓库链接扫描', () {
    test('lib 非 l10n 下无任何 TNT-Likely 残留', () {
      final hits = _scanDir(
        'lib',
        const {'.dart', '.arb'},
        (content) => content.contains('TNT-Likely'),
      ).where((path) => !_isL10nFile(path)).toList();
      expect(hits, isEmpty, reason: '残留文件: $hits');
    });

    test('packages 下无原仓库主链接', () {
      final hits = _scanDir(
        'packages',
        const {'.dart', '.yaml', '.md', '.podspec'},
        (content) => content.contains(originalRepoOwnerPath),
      );
      expect(hits, isEmpty, reason: '残留文件: $hits');
    });

    test('github 配置下无原仓库主链接', () {
      final hits = _scanDir(
        '.github',
        const {'.yml', '.yaml', '.md'},
        (content) => _containsOriginalMainRepoLink(content),
      );
      expect(hits, isEmpty, reason: '残留文件: $hits');
    });

    test('用户可见文档无原仓库主链接', () {
      const files = [
        'README.md',
        'README_EN.md',
        'PRIVACY.md',
        'docs/PROJECT_PLAN.md',
        'docs/cloud-setup.md',
        'docs/cloud-setup_EN.md',
      ];
      final hits = <String>[];
      for (final file in files) {
        if (File(file).readAsStringSync().contains(originalRepoOwnerPath)) {
          hits.add(file);
        }
      }
      expect(hits, isEmpty, reason: '残留文件: $hits');
    });
  });

  group('beejz.com 残留扫描', () {
    test('lib 非 l10n 下无用户可见官网链接', () {
      final hits = _scanDir(
        'lib',
        const {'.dart', '.arb'},
        _containsUserVisibleBeejzLink,
      ).where((path) => !_isL10nFile(path)).toList();
      expect(hits, isEmpty, reason: '残留文件: $hits');
    });
  });
}

List<String> _scanDir(
  String root,
  Set<String> extensions,
  bool Function(String content) predicate,
) {
  final hits = <String>[];
  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is! File) continue;
    if (!extensions.contains(entity.path.toLowerCase().split('.').last)) {
      continue;
    }
    if (predicate(entity.readAsStringSync())) {
      hits.add(entity.path);
    }
  }
  return hits;
}

bool _containsOriginalMainRepoLink(String content) {
  if (!content.contains(originalRepoOwnerPath)) return false;
  return content
      .split('\n')
      .where((line) => line.contains(originalRepoOwnerPath))
      .any((line) => !line.contains('${originalRepoOwnerPath}-'));
}

bool _containsUserVisibleBeejzLink(String content) {
  return content
      .split('\n')
      .where((line) => line.contains('beejz.com'))
      .any((line) {
    final trimmed = line.trimLeft();
    return !trimmed.startsWith('//') &&
        !trimmed.startsWith('/*') &&
        !trimmed.startsWith('*');
  });
}

bool _isL10nFile(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.contains('/l10n/');
}
