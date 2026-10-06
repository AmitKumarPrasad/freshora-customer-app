import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:talegaon_fresh/refreshing_client.dart';

void main() {
  test('401 refreshes once and retries the same authenticated request', () async {
    final authorization = <String?>[];
    final bodies = <String>[];
    var refreshCalls = 0;
    final client = RefreshingClient(MockClient((request) async {
      authorization.add(request.headers['authorization']);
      bodies.add(request.body);
      return http.Response(
        request.headers['authorization'] == 'Bearer renewed' ? '{}' : 'expired',
        request.headers['authorization'] == 'Bearer renewed' ? 200 : 401,
      );
    }), () async {
      refreshCalls++;
      return 'renewed';
    });

    final response = await client.put(
      Uri.parse('https://example.test/customers/me/cart'),
      headers: {'Authorization': 'Bearer expired'},
      body: '{"items":[]}',
    );
    expect(response.statusCode, 200);
    expect(refreshCalls, 1);
    expect(authorization, ['Bearer expired', 'Bearer renewed']);
    expect(bodies, ['{"items":[]}', '{"items":[]}']);
  });
}
