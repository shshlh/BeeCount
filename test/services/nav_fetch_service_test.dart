import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/services/data/nav_fetch_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  String tencentBody(
    String code, {
    String unit = '1.0000',
    String cum = '1.0000',
    String pct = '0',
    String date = '2026-08-07',
  }) =>
      'v_jj$code="$code~测试~0~0~~$unit~$cum~$pct~$date~";';

  String eastmoneyBody(List<(String, String)> items) {
    final entries =
        items.map((e) => '{"x":${e.$1},"y":${e.$2}}').join(',');
    return 'var Data_netWorthTrend = [$entries];';
  }

  void expectQuote(
    Map<String, FundNavQuote> navs,
    String code,
    double nav,
    DateTime navDate,
  ) {
    expect(navs.keys, contains(code));
    expect(navs[code]!.nav, nav);
    expect(navs[code]!.navDate, navDate);
  }

  test('天天基金历史为主源：腾讯正常返回时也能拿到 3 档', () async {
    final requests = <String>[];
    final client = MockClient((request) async {
      requests.add(request.url.toString());
      if (request.url.toString().startsWith('https://fund.eastmoney.com/')) {
        return http.Response(
          eastmoneyBody([
            ('1785972800000', '1.2'),
            ('1786059200000', '1.3'),
            ('1786145600000', '1.4'),
          ]),
          200,
          headers: {'content-type': 'text/plain; charset=utf-8'},
        );
      }
      expect(request.url.toString(), 'https://qt.gtimg.cn/q=jj000001');
      return http.Response(
        tencentBody('000001'),
        200,
        headers: {'content-type': 'text/plain; charset=utf-8'},
      );
    });

    final service = NavFetchService(client: client);
    final histories = await service.fetchNavHistories(['000001']);

    expect(histories['000001']!.length, 3);
    expect(
      histories['000001']!.map((q) => q.nav).toList(),
      [1.2, 1.3, 1.4],
    );
    expect(requests.first, startsWith('https://fund.eastmoney.com/'));
  });

  test('天天基金不可用时回退腾讯最新一档', () async {
    final client = MockClient((request) async {
      if (request.url.toString().startsWith('https://fund.eastmoney.com/')) {
        return http.Response(
          '<html>down</html>',
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      }
      return http.Response(
        tencentBody('000001', unit: '1.3420', cum: '3.9150', pct: '2.0532'),
        200,
        headers: {'content-type': 'text/plain; charset=utf-8'},
      );
    });

    final service = NavFetchService(client: client);
    final histories = await service.fetchNavHistories(['000001']);

    expect(histories['000001']!.length, 1);
    expectQuote(
      {for (final e in histories.entries) e.key: e.value.last},
      '000001',
      1.342,
      DateTime(2026, 8, 7),
    );
  });

  test('腾讯行情单位净值缺失时用累计净值兜底', () async {
    final client = MockClient((request) async {
      if (request.url.toString().startsWith('https://fund.eastmoney.com/')) {
        return http.Response(
          '<html>down</html>',
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      }
      return http.Response(
        tencentBody('000002', unit: '0.0000', cum: '2.1111'),
        200,
        headers: {'content-type': 'text/plain; charset=utf-8'},
      );
    });

    final service = NavFetchService(client: client);
    final histories = await service.fetchNavHistories(['000002']);

    expectQuote(
      {for (final e in histories.entries) e.key: e.value.last},
      '000002',
      2.1111,
      DateTime(2026, 8, 7),
    );
  });

  test('腾讯行情缺日期且天天基金无数据时跳过', () async {
    final client = MockClient((request) async {
      if (request.url.toString().startsWith('https://fund.eastmoney.com/')) {
        return http.Response(
          '<html>not found</html>',
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      }
      return http.Response(
        tencentBody('000005', date: ''),
        200,
        headers: {'content-type': 'text/plain; charset=utf-8'},
      );
    });

    final service = NavFetchService(client: client);
    final histories = await service.fetchNavHistories(['000005']);

    expect(histories, isEmpty);
  });

  test('两个接口都返回 HTML 时干净跳过', () async {
    final client = MockClient((request) async {
      return http.Response(
          '<!doctype html><html><body>页面未找到</body></html>', 200,
          headers: {'content-type': 'text/html; charset=utf-8'});
    });

    final service = NavFetchService(client: client);
    final histories = await service.fetchNavHistories(['000004']);

    expect(histories, isEmpty);
  });

  test('无效代码过滤，只请求 6 位数字', () async {
    final requested = <String>[];
    final client = MockClient((request) async {
      requested.add(request.url.toString());
      return http.Response(
        eastmoneyBody([('1786145600000', '1.0000')]),
        200,
        headers: {'content-type': 'text/plain; charset=utf-8'},
      );
    });

    final service = NavFetchService(client: client);
    final histories = await service.fetchNavHistories([
      '000001',
      'abc',
      '12345',
      '1234567',
      '000003',
    ]);

    expect(histories.keys.toSet(), {'000001', '000003'});
    expect(requested, [
      'https://fund.eastmoney.com/pingzhongdata/000001.js',
      'https://fund.eastmoney.com/pingzhongdata/000003.js',
    ]);
  });

  test('单只失败跳过，不影响其余', () async {
    final client = MockClient((request) async {
      final match =
          RegExp(r'/(\d{6})\.js').firstMatch(request.url.toString());
      final code = match!.group(1)!;
      if (code == '000002') {
        throw http.ClientException('down');
      }
      return http.Response(
        eastmoneyBody([('1786145600000', '1.0000')]),
        200,
        headers: {'content-type': 'text/plain; charset=utf-8'},
      );
    });

    final service = NavFetchService(client: client);
    final histories =
        await service.fetchNavHistories(['000001', '000002', '000003']);

    expect(histories.keys.toSet(), {'000001', '000003'});
  });

  test('并发数不超过 8', () async {
    var active = 0;
    var maxActive = 0;
    final client = MockClient((request) async {
      active++;
      if (active > maxActive) maxActive = active;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      active--;
      return http.Response(
        eastmoneyBody([('1786145600000', '1.0000')]),
        200,
        headers: {'content-type': 'text/plain; charset=utf-8'},
      );
    });

    final service = NavFetchService(client: client);
    final codes = List.generate(
      12,
      (i) => i.toString().padLeft(6, '0'),
    );
    final histories = await service.fetchNavHistories(codes);

    expect(histories.length, 12);
    expect(maxActive, lessThanOrEqualTo(8));
  });

  test('fetchLatestNavs 取历史最后一档', () async {
    final client = MockClient((request) async {
      return http.Response(
        eastmoneyBody([
          ('1785972800000', '1.2'),
          ('1786059200000', '1.3'),
          ('1786145600000', '1.4'),
        ]),
        200,
        headers: {'content-type': 'text/plain; charset=utf-8'},
      );
    });

    final service = NavFetchService(client: client);
    final navs = await service.fetchLatestNavs(['000003']);

    expectQuote(
      navs,
      '000003',
      1.4,
      DateTime.fromMillisecondsSinceEpoch(1786145600000),
    );
  });
}
