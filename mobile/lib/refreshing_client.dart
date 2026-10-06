import 'package:http/http.dart' as http;

/// Retries an authenticated request once after refreshing an expired access token.
class RefreshingClient extends http.BaseClient {
  RefreshingClient(this._inner, this._refreshToken);

  final http.Client _inner;
  final Future<String?> Function() _refreshToken;
  Future<String?>? _refreshInFlight;
  String? _currentToken;

  Future<String?> _refreshOnce() =>
      _refreshInFlight ??= _refreshToken().whenComplete(() {
        _refreshInFlight = null;
      });

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = await request.finalize().toBytes();
    final originalToken = request.headers['Authorization'];

    Future<http.StreamedResponse> sendWithToken(String? token) {
      final replay = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..bodyBytes = body
        ..followRedirects = request.followRedirects
        ..maxRedirects = request.maxRedirects
        ..persistentConnection = request.persistentConnection;
      if (token != null) replay.headers['Authorization'] = 'Bearer $token';
      return _inner.send(replay);
    }

    final first = await sendWithToken(_currentToken);
    if (first.statusCode != 401) return first;

    // Another request may have already refreshed the token.
    var freshToken = _currentToken;
    if (freshToken == null || 'Bearer $freshToken' == originalToken) {
      freshToken = await _refreshOnce();
    }
    if (freshToken == null || freshToken.isEmpty) return first;
    await first.stream.drain();
    _currentToken = freshToken;
    return sendWithToken(freshToken);
  }

  @override
  void close() => _inner.close();
}
