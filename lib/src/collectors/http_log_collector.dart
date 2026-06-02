import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'base_log_collector.dart';
import '../models/access_log.dart';

/// A [BaseLogCollector] that fetches [AccessLog] entries from a REST API.
///
/// Sends a GET request with date-range and filter parameters in the
/// query string.  Expects either:
/// - A JSON **array** as the response body, or
/// - A JSON **object** with a `data` / `items` / `logs` / `results` key
///   containing the array.
///
/// ## Default query parameters
///
/// | Key          | Description                                  |
/// |--------------|----------------------------------------------|
/// | `from`       | ISO 8601 start timestamp                     |
/// | `to`         | ISO 8601 end timestamp                       |
/// | `userId`     | Optional user filter                         |
/// | `ipAddress`  | Optional IP filter                           |
/// | `limit`      | Optional max entries                         |
/// | `offset`     | Optional pagination offset                   |
///
/// Override [buildQueryParameters] to customise the query-string mapping
/// for your API.
///
/// ## Example
///
/// ```dart
/// final collector = HttpLogCollector(
///   baseUrl: 'https://api.myapp.com/audit-logs',
///   headers: {
///     'Authorization': 'Bearer $token',
///     'X-Tenant-ID': tenantId,
///   },
///   customParser: (json) => AccessLog.fromJson(json),
/// );
/// ```
class HttpLogCollector extends BaseLogCollector {
  static final _log = Logger('HttpLogCollector');

  /// Base URL of the audit-log endpoint.
  final String baseUrl;

  /// Headers sent with every request.
  final Map<String, String> headers;

  /// Request timeout. Defaults to 30 seconds.
  final Duration timeout;

  /// Optional custom JSON parser for non-standard schemas.
  final AccessLog Function(Map<String, dynamic>)? customParser;

  /// Optional function to build query parameters from filter values.
  ///
  /// Receives the same parameters as [collect] and must return a
  /// `Map<String, String>` to append to the request URL.
  final Map<String, String> Function(
    DateTime from,
    DateTime to,
    String? userId,
    String? ipAddress,
    int? limit,
    int? offset,
  )? buildQueryParameters;

  /// Number of retry attempts on transient errors (5xx, timeouts).
  final int maxRetries;

  /// Creates an [HttpLogCollector].
  HttpLogCollector({
    required this.baseUrl,
    this.headers = const {},
    this.timeout = const Duration(seconds: 30),
    this.customParser,
    this.buildQueryParameters,
    this.maxRetries = 2,
  });

  @override
  Future<List<AccessLog>> collect({
    required DateTime from,
    required DateTime to,
    String? userId,
    String? ipAddress,
    int? limit,
    int? offset,
  }) async {
    final params = buildQueryParameters != null
        ? buildQueryParameters!(from, to, userId, ipAddress, limit, offset)
        : _defaultParams(from, to, userId, ipAddress, limit, offset);

    final uri = Uri.parse(baseUrl).replace(queryParameters: params);
    _log.fine('GET $uri');

    final response = await _withRetry(() => http.get(uri, headers: headers));

    if (response.statusCode != 200) {
      throw HttpLogCollectorException(
        'Unexpected HTTP ${response.statusCode} from $baseUrl',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    return _parseBody(response.body);
  }

  @override
  Future<int> count({
    required DateTime from,
    required DateTime to,
  }) async {
    final countUrl = Uri.parse('$baseUrl/count').replace(queryParameters: {
      'from': from.toIso8601String(),
      'to': to.toIso8601String(),
    });
    try {
      final response = await http
          .get(countUrl, headers: headers)
          .timeout(timeout);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map) {
          return (body['count'] as int?) ??
              (body['total'] as int?) ??
              (body['totalCount'] as int?) ??
              -1;
        }
        if (body is int) return body;
      }
    } catch (_) {
      // Count endpoint is optional — return -1 on failure
    }
    return -1;
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final healthUrl = Uri.parse('$baseUrl/health');
      final response = await http
          .get(healthUrl, headers: headers)
          .timeout(const Duration(seconds: 5));
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────

  List<AccessLog> _parseBody(String body) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (e) {
      throw FormatException('Could not decode response from $baseUrl: $e');
    }

    List<dynamic> list;
    if (decoded is List) {
      list = decoded;
    } else if (decoded is Map<String, dynamic>) {
      // Try common envelope keys
      final decodedMap = decoded;
      final key = ['data', 'items', 'logs', 'results', 'records']
          .firstWhere((k) => decodedMap.containsKey(k), orElse: () => '');
      if (key.isEmpty || decodedMap[key] is! List) {
        throw FormatException(
          'Expected a JSON array or an object with a "data"/"items"/"logs" '
          'key from $baseUrl. Got: ${decodedMap.keys.join(', ')}',
        );
      }
      list = decodedMap[key] as List<dynamic>;
    } else {
      throw FormatException(
        'Expected JSON array or object from $baseUrl, '
        'got ${decoded.runtimeType}.',
      );
    }

    final parser = customParser ?? AccessLog.fromJson;
    return list
        .cast<Map<String, dynamic>>()
        .map<AccessLog>(parser)
        .toList();
  }

  static Map<String, String> _defaultParams(
    DateTime from,
    DateTime to,
    String? userId,
    String? ipAddress,
    int? limit,
    int? offset,
  ) =>
      {
        'from': from.toIso8601String(),
        'to': to.toIso8601String(),
        if (userId != null) 'userId': userId,
        if (ipAddress != null) 'ipAddress': ipAddress,
        if (limit != null) 'limit': limit.toString(),
        if (offset != null) 'offset': offset.toString(),
      };

  Future<http.Response> _withRetry(
    Future<http.Response> Function() fn,
  ) async {
    var attempts = 0;
    while (true) {
      try {
        return await fn().timeout(timeout);
      } catch (e) {
        attempts++;
        if (attempts > maxRetries) rethrow;
        final delay = Duration(milliseconds: 500 * attempts);
        _log.warning(
          'Request failed (attempt $attempts/$maxRetries). '
          'Retrying in ${delay.inMilliseconds}ms. Error: $e',
        );
        await Future<void>.delayed(delay);
      }
    }
  }
}

/// Thrown by [HttpLogCollector] when the remote API returns an error.
class HttpLogCollectorException implements Exception {
  /// Error message.
  final String message;

  /// HTTP status code.
  final int statusCode;

  /// Response body (truncated to 500 chars for brevity).
  final String body;

  /// Creates an [HttpLogCollectorException].
  HttpLogCollectorException(
    this.message, {
    required this.statusCode,
    required String body,
  }) : body = body.length > 500 ? '${body.substring(0, 500)}…' : body;

  @override
  String toString() =>
      'HttpLogCollectorException($statusCode): $message\nBody: $body';
}
