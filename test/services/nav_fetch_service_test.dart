import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/services/data/nav_fetch_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('JSONP dwjz 优先解析', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/js/000001.js');
      return http.Response(
        'jsonpgz({"fundcode":"000001","name":"TestFund",'
        '"dwjz":"1.2345","gsz":"1.2400"})',
        200,
      );
    });

    final service = NavFetchService(client: client);
    final navs = await service.fetchLatestNavs(['000001']);

    expect(navs, {'000001': 1.2345});
  });

  test('dwjz 缺失时用 gsz 兜底', () async {
    final client = MockClient((request) async {
      return http.Response(
        'jsonpgz({"fundcode":"000002","name":"TestFund","gsz":"2.1111"})',
        200,
      );
    });

    final service = NavFetchService(client: client);
    final navs = await service.fetchLatestNavs(['000002']);

    expect(navs, {'000002': 2.1111});
  });

  test('无效代码过滤，只请求 6 位数字', () async {
    final requested = <String>[];
    final client = MockClient((request) async {
      requested.add(request.url.pathSegments.last);
      return http.Response('jsonpgz({"dwjz":"1.0000"})', 200);
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
    expect(requested, ['000001.js', '000003.js']);
  });

  test('单只失败跳过，不影响其余', () async {
    final client = MockClient((request) async {
      if (request.url.pathSegments.last == '000002.js') {
        throw http.ClientException('down');
      }
      return http.Response('jsonpgz({"dwjz":"1.0000"})', 200);
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
      return http.Response('jsonpgz({"dwjz":"1.0000"})', 200);
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
