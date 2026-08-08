import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/services/data/nav_fetch_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('腾讯行情单位净值优先解析', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://qt.gtimg.cn/q=jj000001');
      return http.Response(
        'v_jj000001="000001~华夏成长混合~0.0000~0.0000~~'
        '1.3420~3.9150~2.0532~2026-08-07~";',
        200,
        headers: {'content-type': 'text/plain; charset=utf-8'},
      );
    });

    final service = NavFetchService(client: client);
    final navs = await service.fetchLatestNavs(['000001']);

    expect(navs, {'000001': 1.342});
  });

  test('腾讯行情单位净值缺失时用累计净值兜底', () async {
    final client = MockClient((request) async {
      return http.Response(
        'v_jj000002="000002~测试基金~0.0000~0.0000~~'
        '0.0000~2.1111~0.0000~2026-08-07~";',
        200,
        headers: {'content-type': 'text/plain; charset=utf-8'},
      );
    });

    final service = NavFetchService(client: client);
    final navs = await service.fetchLatestNavs(['000002']);

    expect(navs, {'000002': 2.1111});
  });

  test('主接口异常时回退天天基金历史净值', () async {
    final client = MockClient((request) async {
      if (request.url.toString().startsWith('https://qt.gtimg.cn/')) {
        return http.Response(
          '<html><body>error</body></html>',
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      }
      expect(request.url.toString(),
          'https://fund.eastmoney.com/pingzhongdata/000003.js');
      return http.Response(
        'var Data_netWorthTrend = ['
        '{"x":1786032000000,"y":3.304,"equityReturn":1.4}];',
        200,
        headers: {'content-type': 'text/plain; charset=utf-8'},
      );
    });

    final service = NavFetchService(client: client);
    final navs = await service.fetchLatestNavs(['000003']);

    expect(navs, {'000003': 3.304});
  });

  test('两个接口都返回 HTML 时干净跳过', () async {
    final client = MockClient((request) async {
      return http.Response(
          '<!doctype html><html><body>页面未找到</body></html>', 200,
          headers: {'content-type': 'text/html; charset=utf-8'});
    });

    final service = NavFetchService(client: client);
    final navs = await service.fetchLatestNavs(['000004']);

    expect(navs, isEmpty);
  });

  test('无效代码过滤，只请求 6 位数字', () async {
    final requested = <String>[];
    final client = MockClient((request) async {
      requested.add(request.url.toString());
      final code = request.url.toString().split('q=jj').last;
      return http.Response(
        'v_jj$code="$code~测试~0~0~~1.0000~1.0000~0~2026-08-07~";',
        200,
        headers: {'content-type': 'text/plain; charset=utf-8'},
      );
    });

    final service = NavFetchService(client: client);
    final navs = await service.fetchLatestNavs([
      '000001',
      'abc',
      '12345',
      '1234567',
      '000003',
    ]);

    expect(navs.keys.toSet(), {'000001', '000003'});
    expect(requested, [
      'https://qt.gtimg.cn/q=jj000001',
      'https://qt.gtimg.cn/q=jj000003',
    ]);
  });

  test('单只失败跳过，不影响其余', () async {
    final client = MockClient((request) async {
      final code = request.url.toString().split('q=jj').last;
      if (code == '000002') {
        throw http.ClientException('down');
      }
      return http.Response(
        'v_jj$code="$code~测试~0~0~~1.0000~1.0000~0~2026-08-07~";',
        200,
        headers: {'content-type': 'text/plain; charset=utf-8'},
      );
    });

    final service = NavFetchService(client: client);
    final navs = await service.fetchLatestNavs(['000001', '000002', '000003']);

    expect(navs.keys.toSet(), {'000001', '000003'});
  });

  test('并发数不超过 8', () async {
    var active = 0;
    var maxActive = 0;
    final client = MockClient((request) async {
      active++;
      if (active > maxActive) maxActive = active;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      active--;
      final code = request.url.toString().split('q=jj').last;
      return http.Response(
        'v_jj$code="$code~测试~0~0~~1.0000~1.0000~0~2026-08-07~";',
        200,
        headers: {'content-type': 'text/plain; charset=utf-8'},
      );
    });

    final service = NavFetchService(client: client);
    final codes = List.generate(
      12,
      (i) => i.toString().padLeft(6, '0'),
    );
    final navs = await service.fetchLatestNavs(codes);

    expect(navs.length, 12);
    expect(maxActive, lessThanOrEqualTo(8));
  });
}
