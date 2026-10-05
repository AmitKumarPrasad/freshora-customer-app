import 'dart:convert';

import 'package:http/http.dart' as http;

import 'main.dart';

class OrderApiException implements Exception {
  const OrderApiException(this.message);
  final String message;

  @override
  String toString() => 'OrderApiException: $message';
}

class CreateOrderRequest {
  const CreateOrderRequest({
    required this.items,
    required this.total,
    required this.payment,
    required this.address,
  });

  final List<OrderLine> items;
  final double total;
  final String payment;
  final CustomerAddress address;

  Map<String, dynamic> toJson() => {
        'items': items.map((item) => item.toJson()).toList(),
        'total': total,
        'payment': payment,
        'address': address.toJson(),
      };
}

abstract class OrderRepository {
  Future<OrderRecord> createOrder(CreateOrderRequest request);
  Future<List<OrderRecord>> fetchOrders();
}

class HttpOrderRepository implements OrderRepository {
  HttpOrderRepository({String? baseUrl, this.token, http.Client? client})
      : baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue:
                  'https://talegaon-fresh-ai-backend.onrender.com',
            ),
        _client = client ?? http.Client();

  final String baseUrl;
  final String? token;
  final http.Client _client;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null && token!.isNotEmpty)
          'Authorization': 'Bearer $token',
      };

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  @override
  Future<OrderRecord> createOrder(CreateOrderRequest request) async {
    final response = await _client.post(
      _uri('/customers/me/orders'),
      headers: _headers,
      body: jsonEncode(request.toJson()),
    );
    _ensureSuccess(response);

    final decoded = jsonDecode(response.body);
    final value =
        decoded is Map && decoded['order'] != null ? decoded['order'] : decoded;
    final order = OrderRecord.fromJson(value);
    if (order == null) {
      throw const OrderApiException('INVALID_ORDER_RESPONSE');
    }
    return order;
  }

  @override
  Future<List<OrderRecord>> fetchOrders() async {
    final response =
        await _client.get(_uri('/customers/me/orders'), headers: _headers);
    _ensureSuccess(response);

    final decoded = jsonDecode(response.body);
    final values = decoded is Map && decoded['orders'] is List
        ? decoded['orders'] as List
        : decoded is List
            ? decoded
            : const [];
    return values.map(OrderRecord.fromJson).whereType<OrderRecord>().toList();
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode == 401) {
      throw const OrderApiException('AUTH_UNAUTHORIZED');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'ORDER_API_ERROR';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['detail'] is String) {
          message = decoded['detail'] as String;
        } else if (decoded is Map && decoded['message'] is String) {
          message = decoded['message'] as String;
        } else if (decoded is Map && decoded['error'] is String) {
          message = decoded['error'] as String;
        }
      } catch (_) {}
      throw OrderApiException(message);
    }
  }
}
