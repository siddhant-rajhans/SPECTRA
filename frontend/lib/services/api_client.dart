import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

/// Central API client for the HearClear backend.
/// Handles REST calls and WebSocket connections.
class ApiClient {
  // Default to localhost for iOS simulator.
  // For Android emulator use 10.0.2.2:3001
  // For physical device use your LAN IP (e.g., 192.168.1.x:3001)
  static String _baseUrl = 'http://localhost:3001/api';
  static String _wsUrl = 'ws://localhost:3001/ws';
  static String? _userId;

  /// Configure the base URL (call before any API calls).
  /// [host] should be like '192.168.1.5:3001' or 'localhost:3001'
  static void configure({required String host}) {
    _baseUrl = 'http://$host/api';
    _wsUrl = 'ws://$host/ws';
  }

  static void setUserId(String id) => _userId = id;
  static String? get userId => _userId;
  static String get baseUrl => _baseUrl;

  // ─── HTTP Helpers ─────────────────────────────────────────────

  static Future<Map<String, dynamic>> get(String path) async {
    final response = await http.get(
      Uri.parse('$_baseUrl$path'),
      headers: _headers(),
    ).timeout(const Duration(seconds: 10));
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) async {
    final response = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: _headers(),
      body: body != null ? jsonEncode(body) : null,
    ).timeout(const Duration(seconds: 10));
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> put(String path, [Map<String, dynamic>? body]) async {
    final response = await http.put(
      Uri.parse('$_baseUrl$path'),
      headers: _headers(),
      body: body != null ? jsonEncode(body) : null,
    ).timeout(const Duration(seconds: 10));
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> patch(String path, [Map<String, dynamic>? body]) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl$path'),
      headers: _headers(),
      body: body != null ? jsonEncode(body) : null,
    ).timeout(const Duration(seconds: 10));
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> delete(String path) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl$path'),
      headers: _headers(),
    ).timeout(const Duration(seconds: 10));
    return _handleResponse(response);
  }

  // ─── WebSocket ────────────────────────────────────────────────

  static WebSocketChannel connectWebSocket() {
    return IOWebSocketChannel.connect(
      Uri.parse(_wsUrl),
      pingInterval: const Duration(seconds: 30),
    );
  }

  // ─── Internals ────────────────────────────────────────────────

  static Map<String, String> _headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_userId != null) {
      headers['X-User-Id'] = _userId!;
    }
    return headers;
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {'success': true};
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: _extractError(response),
      );
    }
  }

  static String _extractError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      return body['error'] ?? body['message'] ?? 'Request failed';
    } catch (_) {
      return 'Request failed with status ${response.statusCode}';
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
