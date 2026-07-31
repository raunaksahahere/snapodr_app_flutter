import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/staff_order.dart';
import '../models/table_session.dart';
import 'auth_store.dart';

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ApiClient {
  const ApiClient(this.session);

  final StaffSession session;

  Map<String, String> get _headers => {'Authorization': 'Bearer ${session.token}', 'Content-Type': 'application/json'};

  static Future<StaffSession> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/api/staff/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );
    // Diagnostic: _decode collapses every failure into one generic message, so
    // log the raw response before it is swallowed.
    debugPrint('[login] POST $apiBaseUrl/api/staff/login -> ${response.statusCode}');
    debugPrint('[login] content-type: ${response.headers['content-type']}');
    debugPrint('[login] body: ${response.body}');
    final body = _decode(response, 'Could not sign in.');
    final restaurant = body['restaurant'] as Map<String, dynamic>;
    return StaffSession(
      token: body['token'] as String,
      restaurantName: restaurant['name'] as String,
      restaurantSlug: restaurant['slug'] as String,
    );
  }

  /// Every live order for this restaurant. Status filtering happens on the
  /// client so kitchen and waiter can show different slices of one poll.
  Future<List<StaffOrder>> fetchOrders() async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/api/orders?restaurant=${Uri.encodeQueryComponent(session.restaurantSlug)}'),
      headers: _headers,
    );
    final body = _decode(response, 'Could not load orders.');
    return (body['orders'] as List<dynamic>).map((raw) => StaffOrder.fromJson(raw as Map<String, dynamic>)).toList();
  }

  /// Every open visit for this restaurant, including tables that have not
  /// ordered yet - those produce no orders, so [fetchOrders] cannot see them.
  Future<List<TableSession>> fetchSessions() async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/api/sessions?restaurant=${Uri.encodeQueryComponent(session.restaurantSlug)}'),
      headers: _headers,
    );
    final body = _decode(response, 'Could not load tables.');
    return (body['sessions'] as List<dynamic>).map((raw) => TableSession.fromJson(raw as Map<String, dynamic>)).toList();
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    final response = await http.patch(
      Uri.parse('$apiBaseUrl/api/orders/${Uri.encodeComponent(orderId)}'),
      headers: _headers,
      body: jsonEncode({'status': status}),
    );
    _decode(response, 'Could not update the order.');
  }

  /// Staff override: `force=true` ends the visit even when the kitchen has
  /// already accepted orders, which the customer-facing cancel flow refuses.
  Future<void> deleteSession(String sessionId) async {
    final response = await http.delete(
      Uri.parse('$apiBaseUrl/api/sessions/${Uri.encodeComponent(sessionId)}?force=true'),
      headers: _headers,
    );
    _decode(response, 'Could not delete the session.');
  }

  static Map<String, dynamic> _decode(http.Response response, String fallback) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(response.statusCode == 401 ? 'Your session expired. Please sign in again.' : fallback);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(body['error'] as String? ?? fallback);
    }
    return body;
  }
}
