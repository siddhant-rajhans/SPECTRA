import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

/// Central API client for the HearClear backend.
///
/// REST + WebSocket. The backend host is persisted in SharedPreferences so
/// users can point the app at a different machine on a LAN (or a hosted
/// server) without rebuilding. Compile-time default comes from `--dart-define
/// BACKEND_HOST=<host:port>` and falls back to a sensible dev default.
class ApiClient {
  static const String _kHostKey = 'spectra.backendHost';
  static const String _kUserKey = 'spectra.savedUser';
  static const String _defaultHost = String.fromEnvironment(
    'BACKEND_HOST',
    defaultValue: '10.0.2.2:3001',
  );

  static String _host = _defaultHost;
  static String _baseUrl = 'http://$_defaultHost/api';
  static String _wsUrl = 'ws://$_defaultHost/ws';
  static String? _userId;

  /// Load the persisted host (if any) from SharedPreferences. Call once on
  /// app boot, before the first API request.
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kHostKey);
    if (saved != null && saved.isNotEmpty) {
      _applyHost(saved);
    } else {
      _applyHost(_defaultHost);
    }
  }

  /// Update the backend host at runtime and persist it. Accepts forms like
  /// `192.168.1.42:3001`, `localhost:3001`, or `api.example.com`.
  static Future<void> setHost(String host) async {
    final cleaned = _normalizeHost(host);
    _applyHost(cleaned);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kHostKey, cleaned);
  }

  /// Persist the signed-in user as JSON so we can restore the session after
  /// a cold start. The backend doesn't issue auth tokens yet (Tier 2 work),
  /// so this is just a local convenience — every API call still passes the
  /// user id explicitly.
  static Future<void> saveSession(Map<String, dynamic> userJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserKey, jsonEncode(userJson));
  }

  /// Read the previously saved user, or null if the user has logged out / never
  /// signed in. Returned map can be passed back to `User.fromJson`.
  static Future<Map<String, dynamic>?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUserKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Forget the persisted user. Called on explicit logout.
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserKey);
  }

  static String get host => _host;
  static String get baseUrl => _baseUrl;
  static String get wsUrl => _wsUrl;

  /// Backwards-compatible alias for older callers.
  static void configure({required String host}) => _applyHost(_normalizeHost(host));

  static void setUserId(String id) => _userId = id;
  static String? get userId => _userId;

  static String _normalizeHost(String input) {
    var s = input.trim();
    s = s.replaceFirst(RegExp(r'^https?://'), '');
    s = s.replaceFirst(RegExp(r'^wss?://'), '');
    s = s.replaceAll(RegExp(r'/+$'), '');
    return s;
  }

  static void _applyHost(String host) {
    _host = host;
    _baseUrl = 'http://$host/api';
    _wsUrl = 'ws://$host/ws';
  }

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

  /// Quick reachability probe used by the settings screen to confirm the
  /// configured host actually serves the backend.
  static Future<bool> ping() async {
    try {
      final response = await http
          .get(Uri.parse('http://$_host/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
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
