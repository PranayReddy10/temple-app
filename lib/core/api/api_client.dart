import 'dart:convert';

import 'package:http/http.dart' as http;

/// Errors the UI can name: a 404 reads differently from a lost connection.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.errors = const {}});

  final String message;
  final int? statusCode;
  final Map<String, List<String>> errors;

  bool get isNotFound => statusCode == 404;
  bool get isUnauthenticated => statusCode == 401;
  bool get isValidation => statusCode == 422;

  @override
  String toString() => message;
}

/// Thin HTTP layer over `/api/v1`.
///
/// Knows nothing about Laravel beyond the response envelope. The base URL is
/// mutable so the Profile screen can point a build at a staging server.
class ApiClient {
  ApiClient({required String baseUrl, http.Client? client, this.timeout = const Duration(seconds: 12)})
      : _baseUrl = _trim(baseUrl),
        _http = client ?? http.Client();

  String _baseUrl;
  final http.Client _http;
  final Duration timeout;
  String? token;

  String get baseUrl => _baseUrl;
  set baseUrl(String v) => _baseUrl = _trim(v);

  static String _trim(String v) {
    var s = v.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  Uri _uri(String path, [Map<String, String?>? query]) {
    final q = <String, String>{
      if (query != null)
        for (final e in query.entries)
          if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
    };
    return Uri.parse('$_baseUrl/api/v1/$path').replace(queryParameters: q.isEmpty ? null : q);
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> get(String path, [Map<String, String?>? query]) async {
    final res = await _http.get(_uri(path, query), headers: _headers).timeout(timeout);
    return _decode(res);
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final res = await _http.post(_uri(path), headers: _headers, body: jsonEncode(body)).timeout(timeout);
    return _decode(res);
  }

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) async {
    final res = await _http.patch(_uri(path), headers: _headers, body: jsonEncode(body)).timeout(timeout);
    return _decode(res);
  }

  Future<Map<String, dynamic>> put(String path, [Map<String, dynamic> body = const {}]) async {
    final res = await _http.put(_uri(path), headers: _headers, body: jsonEncode(body)).timeout(timeout);
    return _decode(res);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final res = await _http.delete(_uri(path), headers: _headers).timeout(timeout);
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> body = const {};
    if (res.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      } catch (_) {
        // Non-JSON body: a maintenance page or a proxy error.
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    final errors = <String, List<String>>{};
    final raw = body['errors'];
    if (raw is Map) {
      for (final e in raw.entries) {
        errors['${e.key}'] = (e.value is List ? e.value as List : [e.value]).map((v) => '$v').toList();
      }
    }
    throw ApiException(
      body['message']?.toString() ?? 'Request failed (${res.statusCode})',
      statusCode: res.statusCode,
      errors: errors,
    );
  }
}
