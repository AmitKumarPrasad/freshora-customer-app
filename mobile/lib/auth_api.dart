import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
  HttpAuthRepository({http.Client? client, String? baseUrl, FlutterSecureStorage? storage, this.logoutTimeout = const Duration(seconds: 5)})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage(),
        _baseUrl = (baseUrl ?? const String.fromEnvironment('AUTH_BASE_URL', defaultValue: 'https://talegaon-fresh-ai-backend.onrender.com')).replaceFirst(RegExp(r'/+$'), '');

  final http.Client _client;
  final FlutterSecureStorage _storage;
  final String _baseUrl;
  final Duration logoutTimeout;
  Future<CustomerSession?>? _refreshInFlight;

  Future<String> _deviceId() async {
    // Device identifiers are not secrets. Keep this stable identifier in
    // SharedPreferences so an Android Keystore problem cannot prevent the
    // login/register request from ever reaching the backend.
    const key = 'talegaon_fresh_device_id';
    try {
      final preferences = await SharedPreferences.getInstance();
      final existing = preferences.getString(key);
      if (existing != null && existing.length >= 16) return existing;

      // Migrate existing installs from the old secure-storage location.
      String? legacy;
      try {
        legacy = await _storage.read(key: key);
      } catch (_) {
        // Secure storage may be unavailable on some Play Store installs.
      }
      if (legacy != null && legacy.length >= 16) {
        await preferences.setString(key, legacy);
        return legacy;
      }

      final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
      final value = base64UrlEncode(bytes).replaceAll('=', '');
      final saved = await preferences.setString(key, value);
      if (!saved) {
        throw const AuthException('Could not prepare this device. Please restart the app and try again.');
      }
      return value;
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException('Could not prepare this device. Please update the app, restart your phone, and try again.');
    }
  }

  Future<http.Response> _postAuth(String path, Map<String, dynamic> body) async {
    try {
      return await _client
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: const {'Accept': 'application/json', 'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const AuthException('The server took too long to respond. Check your internet and try again. If creating an account, try signing in before registering again.');
    } on SocketException {
      throw const AuthException('No internet connection. Connect to the internet and try again.');
    } on http.ClientException {
      throw const AuthException('Could not connect to FRESHORA. Check your internet connection and try again.');
    }
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
      isReviewer: customer is Map && customer['is_reviewer'] == true,
    );
  }

  Future<void> _save(CustomerSession session) async {
    try {
      await _storage.write(key: 'talegaon_fresh_access_token', value: session.token);
      await _storage.write(key: 'talegaon_fresh_refresh_token', value: session.refreshToken);
      await _storage.write(key: 'talegaon_fresh_phone', value: session.phone);
      await _storage.write(key: 'talegaon_fresh_name', value: session.name);
    } catch (_) {
      // Do not store auth tokens in plain preferences if secure storage fails.
      try {
        await _clear();
      } catch (_) {
        // Best effort cleanup of a partial write.
      }
      throw const AuthException('FRESHORA could not securely save your session on this device. Restart the app and try again. If creating an account, the account may already exist—try Sign in first.');
    }
  }

  @override
  Future<CustomerSession> register(String phone, String pin, String name) async {
    final response = await _postAuth('/auth/register', {
      'phone': phone,
      'pin': pin,
      'name': name,
      'device_id': await _deviceId(),
    });
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
    final response = await _postAuth('/auth/login', {
      'phone': phone,
      'pin': pin,
      'device_id': await _deviceId(),
    });
    final session = await _sessionFromResponse(response, fallbackPhone: phone);
    await _save(session);
    return session;
  }

  @override
  Future<CustomerSession?> restoreSession() =>
      _refreshInFlight ??= _restoreSessionOnce().whenComplete(() {
        _refreshInFlight = null;
      });

  Future<CustomerSession?> _restoreSessionOnce() async {
    final refresh = await _storage.read(key: 'talegaon_fresh_refresh_token');
    if (refresh == null || refresh.isEmpty) return null;
    final phone = await _storage.read(key: 'talegaon_fresh_phone');
    final name = await _storage.read(key: 'talegaon_fresh_name');
    final response = await _client.post(Uri.parse('$_baseUrl/auth/refresh'),
      headers: const {'Accept':'application/json','Content-Type':'application/json'},
      body: jsonEncode({'refresh_token': refresh, 'device_id': await _deviceId()}));
    if (response.statusCode == 401 || response.statusCode == 403) {
      await _clear();
      return null;
    }
    // A temporary outage or rate limit does not invalidate the saved session.
    // Preserve the refresh token so a later retry can recover without a login.
    _ensureSuccess(response, fallback: 'Could not restore your session. Please retry.');
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
    try {
      await _revokeSession().timeout(logoutTimeout);
    } catch (_) {
      // Remote revocation is best effort, including when the server stalls.
    } finally {
      await _clear();
    }
  }

  Future<void> _revokeSession() async {
    final refresh = await _storage.read(key: 'talegaon_fresh_refresh_token');
    if (refresh == null || refresh.isEmpty) return;
    await _client.post(Uri.parse('$_baseUrl/auth/logout-session'),
      headers: const {'Accept':'application/json','Content-Type':'application/json'},
      body: jsonEncode({'refresh_token': refresh, 'device_id': await _deviceId()}));
  }

  Future<void> uploadFcmToken(String fcmToken, String accessToken) async {
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

