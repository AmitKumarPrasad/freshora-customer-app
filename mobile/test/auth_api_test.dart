import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:talegaon_fresh/auth_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final values = <String, String>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async {
      final args = Map<String, dynamic>.from(call.arguments as Map? ?? const {});
      switch (call.method) {
        case 'read':
          return values[args['key'] as String];
        case 'write':
          values[args['key'] as String] = args['value'] as String;
          return null;
        case 'delete':
          values.remove(args['key'] as String);
          return null;
        default:
          return null;
      }
    },
  );
  test('demo repository supports PIN registration', () async {
    const repository = DemoAuthRepository();
    final session = await repository.register('9876543210', '123456', 'Test Customer');
    expect(session.phone, '9876543210');
    expect(session.refreshToken, 'demo-refresh');
  });

  test('demo repository rejects invalid PIN', () async {
    const repository = DemoAuthRepository();
    expect(() => repository.login('9876543210', '000000'), throwsA(isA<AuthException>()));
  });

  test('HTTP repository sends secure PIN login request', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(), 'https://example.test/auth/login');
      expect(jsonDecode(request.body), containsPair('phone', '9876543210'));
      expect(jsonDecode(request.body), containsPair('pin', '654321'));
      return http.Response(jsonEncode({
        'access_token': 'jwt-token',
        'refresh_token': 'refresh-token',
        'customer': {'phone': '9876543210', 'name': 'Amit Customer'}
      }), 200, headers: {'content-type':'application/json'});
    });
    final repository = HttpAuthRepository(client: client, baseUrl: 'https://example.test');
    final session = await repository.login('9876543210', '654321');
    expect(session.token, 'jwt-token');
    expect(session.refreshToken, 'refresh-token');
  });

  test('reviewer mode follows authenticated server response', () async {
    final repository = HttpAuthRepository(
      client: MockClient((_) async => http.Response(jsonEncode({
        'access_token': 'jwt-token',
        'refresh_token': 'refresh-token',
        'customer': {'phone': '9876543210', 'name': 'Reviewer', 'is_reviewer': true},
      }), 200)),
      baseUrl: 'https://example.test',
    );
    expect((await repository.login('9876543210', '654321')).isReviewer, isTrue);
    expect((await repository.restoreSession())!.isReviewer, isTrue);
  });

  test('login preserves the entered mobile number when customer is omitted', () async {
    final repository = HttpAuthRepository(
      client: MockClient((_) async => http.Response(jsonEncode({
        'access_token': 'jwt-token',
        'refresh_token': 'refresh-token',
      }), 200)),
      baseUrl: 'https://example.test',
    );

    final session = await repository.login('9876543210', '654321');

    expect(session.phone, '9876543210');
    expect(session.name, 'Talegaon Customer');
    expect(session.isReviewer, isFalse);
  });

  test('session restore preserves saved customer details when omitted by API', () async {
    values['talegaon_fresh_access_token'] = 'old-access';
    values['talegaon_fresh_refresh_token'] = 'old-refresh';
    values['talegaon_fresh_phone'] = '9876543210';
    values['talegaon_fresh_name'] = 'Amit Customer';
    final repository = HttpAuthRepository(
      client: MockClient((request) async {
        expect(request.url.path, '/auth/refresh');
        return http.Response(jsonEncode({
          'access_token': 'new-access',
          'refresh_token': 'new-refresh',
        }), 200);
      }),
      baseUrl: 'https://example.test',
    );

    final session = await repository.restoreSession();

    expect(session?.phone, '9876543210');
    expect(session?.name, 'Amit Customer');
    expect(values['talegaon_fresh_access_token'], 'new-access');
    expect(values['talegaon_fresh_refresh_token'], 'new-refresh');
  });
  for (final status in [429, 500, 503]) {
    test('refresh HTTP $status preserves credentials and supports retry', () async {
      values['talegaon_fresh_access_token'] = 'old-access';
      values['talegaon_fresh_refresh_token'] = 'old-refresh';
      var requests = 0;
      final repository = HttpAuthRepository(
        client: MockClient((_) async {
          requests++;
          if (requests == 1) return http.Response('{}', status);
          return http.Response(jsonEncode({
            'access_token': 'new-access',
            'refresh_token': 'new-refresh',
          }), 200);
        }),
        baseUrl: 'https://example.test',
      );

      await expectLater(repository.restoreSession(), throwsA(isA<AuthException>()));
      expect(values['talegaon_fresh_refresh_token'], 'old-refresh');
      expect(values['talegaon_fresh_access_token'], 'old-access');
      expect((await repository.restoreSession())?.token, 'new-access');
      expect(requests, 2);
    });
  }

  for (final status in [401, 403]) {
    test('refresh HTTP $status clears rejected credentials', () async {
      values['talegaon_fresh_refresh_token'] = 'rejected-refresh';
      values['talegaon_fresh_access_token'] = 'old-access';
      final repository = HttpAuthRepository(
        client: MockClient((_) async => http.Response('{}', status)),
        baseUrl: 'https://example.test',
      );

      expect(await repository.restoreSession(), isNull);
      expect(values.containsKey('talegaon_fresh_refresh_token'), isFalse);
      expect(values.containsKey('talegaon_fresh_access_token'), isFalse);
    });
  }
  test('logout clears local credentials when backend never responds', () async {
    values['talegaon_fresh_refresh_token'] = 'refresh-token';
    values['talegaon_fresh_access_token'] = 'access-token';
    final response = Completer<http.Response>();
    final requestStarted = Completer<void>();
    final repository = HttpAuthRepository(
      client: MockClient((_) {
        requestStarted.complete();
        return response.future;
      }),
      baseUrl: 'https://example.test',
      logoutTimeout: const Duration(milliseconds: 50),
    );

    final logout = repository.logout();
    await requestStarted.future;
    await logout.timeout(const Duration(seconds: 1));

    expect(values.containsKey('talegaon_fresh_refresh_token'), isFalse);
    expect(values.containsKey('talegaon_fresh_access_token'), isFalse);
    response.complete(http.Response('{}', 200));
  });

  test('logout clears local credentials when backend request throws', () async {
    values['talegaon_fresh_refresh_token'] = 'refresh-token';
    values['talegaon_fresh_access_token'] = 'access-token';
    final repository = HttpAuthRepository(
      client: MockClient((_) async => throw http.ClientException('offline')),
      baseUrl: 'https://example.test',
    );

    await repository.logout();

    expect(values.containsKey('talegaon_fresh_refresh_token'), isFalse);
    expect(values.containsKey('talegaon_fresh_access_token'), isFalse);
  });

}
