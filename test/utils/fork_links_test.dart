import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/utils/fork_links.dart';

void main() {
  group('ForkLinks', () {
    test('仓库相关链接全部指向自身 fork', () {
      expect(ForkLinks.gitHubBase, 'https://github.com/shshlh/BeeCount');
      expect(
        ForkLinks.gitHubReleases,
        'https://github.com/shshlh/BeeCount/releases',
      );
      expect(
        ForkLinks.gitHubIssues,
        'https://github.com/shshlh/BeeCount/issues',
      );
      expect(
        ForkLinks.gitHubApiReleasesLatest,
        'https://api.github.com/repos/shshlh/BeeCount/releases/latest',
      );
    });

    test('任何链接都不再指向原仓库', () {
      expect(ForkLinks.gitHubBase.contains('TNT-Likely'), isFalse);
      expect(ForkLinks.gitHubReleases.contains('TNT-Likely'), isFalse);
      expect(ForkLinks.gitHubIssues.contains('TNT-Likely'), isFalse);
      expect(ForkLinks.gitHubApiReleasesLatest.contains('TNT-Likely'), isFalse);
    });
  });
}
