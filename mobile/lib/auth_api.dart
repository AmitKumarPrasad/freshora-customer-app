import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'main.dart';

abstract class AuthRepository {
  Future<CustomerSession> register(String phone, String pin, String name);
  Future<CustomerSession> login(String phone, String pin);
  Future<CustomerSession?> restoreSession();
  Future<void> logout();
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
}

class DemoAuthRepository implements AuthRepository {
  const DemoAuthRepository();
  @override Future<CustomerSession> register(String phone, String pin, String name) async => CustomerSession(phone: phone, name: name.isEmpty ? 'Talegaon Customer' : name, token: 'demo-token', refreshToken: 'demo-refresh');
  @override Future<CustomerSession> login(String phone, String pin) async {
    if (pin != '123456') throw const AuthException('Invalid mobile number or PIN.');
    return CustomerSession(phone: phone, name: 'Talegaon Customer', token: 'demo-token', refreshToken: 'demo-refresh');
  }
  @override Future<CustomerSession?> restoreSession() async => null;
  @override Future<void> logout() async {}
}

class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository({http.Client? client, String? baseUrl, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage(),
        _baseUrl = (baseUrl ?? const String.fromEnvironment('AUTH_BASE_URL', defaultValue: 'https://talegaon-fresh-ai-backend.onrender.com')).replaceFirst(RegExp(r'/+$'), '');

  final http.Client _client;
  final FlutterSecureStorage _storage;
  final String _baseUrl;

  Future<String> _deviceId() async {
    const key = 'talegaon_fresh_device_id';
    final existing = await _storage.read(key: key);
    if (existing != null && existing.length >= 16) return existing;
    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    final value = base64UrlEncode(bytes).replaceAll('=', '');
    await _storage.write(key: key, value: value);
    return value;
  }

  Future<CustomerSession> _sessionFromResponse(
    http.Response response, {
    String? fallbackPhone,
    String fallbackName = 'Talegaon Customer',
  }) async {
    _ensureSuccess(response, fallback: 'Authentication failed.');
    final body = jsonDecode(response.body);
    if (body is! Map || body['access_token'] is! String || body['refresh_token'] is! String) {
      throw const AuthException('Invalid authentication response.');
    }
    final customer = body['customer'];
    final responsePhone = customer is Map ? customer['phone'] : null;
    final responseName = customer is Map ? customer['name'] : null;
    return CustomerSession(
      phone: responsePhone is String && responsePhone.trim().isNotEmpty
          ? responsePhone
          : fallbackPhone ?? '',
      name: responseName is String && responseName.trim().isNotEmpty
          ? responseName
          : fallbackName,
      token: body['access_token'],
      refreshToken: body['refresh_token'],
    );
  }

  Future<void> _save(CustomerSession session) async {
    await _storage.write(key: 'talegaon_fresh_access_token', value: session.token);
    await _storage.write(key: 'talegaon_fresh_refresh_token', value: session.refreshToken);
    await _storage.write(key: 'talegaon_fresh_phone', value: session.phone);
    await _storage.write(key: 'talegaon_fresh_name', value: session.name);
  }

  @override
  Future<CustomerSession> register(String phone, String pin, String name) async {
    final response = await _client.post(Uri.parse('$_baseUrl/auth/register'),
      headers: const {'Accept':'application/json','Content-Type':'application/json'},
      body: jsonEncode({'phone': phone, 'pin': pin, 'name': name, 'device_id': await _deviceId()}));
    final session = await _sessionFromResponse(
      response,
      fallbackPhone: phone,
      fallbackName: name,
    );
    await _save(session);
    return session;
  }

  @override
  Future<CustomerSession> login(String phone, String pin) async {
    final response = await _client.post(Uri.parse('$_baseUrl/auth/login'),
      headers: const {'Accept':'application/json','Content-Type':'application/json'},
      body: jsonEncode({'phone': phone, 'pin': pin, 'device_id': await _deviceId()}));
    final session = await _sessionFromResponse(response, fallbackPhone: phone);
    await _save(session);
    return session;
  }

  @override
  Future<CustomerSession?> restoreSession() async {
    final refresh = await _storage.read(key: 'talegaon_fresh_refresh_token');
    if (refresh == null || refresh.isEmpty) return null;
    final phone = await _storage.read(key: 'talegaon_fresh_phone');
    final name = await _storage.read(key: 'talegaon_fresh_name');
    final response = await _client.post(Uri.parse('$_baseUrl/auth/refresh'),
      headers: const {'Accept':'application/json','Content-Type':'application/json'},
      body: jsonEncode({'refresh_token': refresh, 'device_id': await _deviceId()}));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await _clear();
      return null;
    }
    final session = await _sessionFromResponse(
      response,
      fallbackPhone: phone,
      fallbackName: name ?? 'Talegaon Customer',
    );
    await _save(session);
    return session;
  }

  @override
  Future<void> logout() async {
    final refresh = await _storage.read(key: 'talegaon_fresh_refresh_token');
    if (refresh != null && refresh.isNotEmpty) {
      try {
        await _client.post(Uri.parse('$_baseUrl/auth/logout-session'),
          headers: const {'Accept':'application/json','Content-Type':'application/json'},
          body: jsonEncode({'refresh_token': refresh, 'device_id': await _deviceId()}));
      } catch (_) {
        // Best-effort server revocation; local credentials are cleared below.
      }
    }
    await _clear();
  }

  Future<void> uploadFcmToken(String fcmToken, String accessToken) async {
    try {
      final response = await _client.put(
        Uri.parse('$_baseUrl/customers/me/fcm-token'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'fcm_token': fcmToken}),
      );
      _ensureSuccess(response, fallback: 'Failed to upload FCM token.');
    } catch (e) {
      // Non-blocking; continue even if upload fails
    }
  }

  Future<void> _clear() async {
    for (final key in ['talegaon_fresh_access_token','talegaon_fresh_refresh_token','talegaon_fresh_phone','talegaon_fresh_name']) {
      await _storage.delete(key: key);
    }
  }

  void _ensureSuccess(http.Response response, {required String fallback}) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['detail'] is String) throw AuthException(body['detail']);
      if (body is Map && body['message'] is String) throw AuthException(body['message']);
    } on AuthException { rethrow; } on FormatException { /* malformed error payload */ }
    throw AuthException(fallback);
  }
}
