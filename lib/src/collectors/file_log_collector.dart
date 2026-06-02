import 'dart:convert';
import 'dart:io';

import 'base_log_collector.dart';
import '../models/access_log.dart';

/// A [BaseLogCollector] that reads [AccessLog] entries from a local file.
///
/// ## Supported file formats
///
/// | Extension | Format                                      |
/// |-----------|---------------------------------------------|
/// | `.json`   | JSON array of access-log objects            |
/// | `.jsonl`  | Newline-delimited JSON (one object per line) |
/// | `.ndjson` | Same as `.jsonl`                            |
/// | `.csv`    | Comma-separated — requires [CsvRowParser]   |
///
/// ## JSON array example (`audit.json`)
///
/// ```json
/// [
///   { "id": "1", "userId": "u01", "ipAddress": "1.2.3.4",
///     "loginAt": "2026-01-15T09:00:00Z", "status": "success" },
///   ...
/// ]
/// ```
///
/// ## JSONL example (`audit.jsonl`)
///
/// ```
/// {"id":"1","userId":"u01","ipAddress":"1.2.3.4","loginAt":"2026-01-15T09:00:00Z"}
/// {"id":"2","userId":"u02","ipAddress":"5.6.7.8","loginAt":"2026-01-16T11:00:00Z"}
/// ```
///
/// ## Usage
///
/// ```dart
/// final collector = FileLogCollector(filePath: '/var/log/audit.json');
/// final collector2 = FileLogCollector(
///   filePath: '/var/log/audit.csv',
///   csvRowParser: (row) => AccessLog(
///     id: row[0], userId: row[1], ipAddress: row[2],
///     loginAt: DateTime.parse(row[3]),
///   ),
/// );
/// ```
class FileLogCollector extends BaseLogCollector {
  /// Absolute or relative path to the log file.
  final String filePath;

  /// Custom parser for CSV rows.
  ///
  /// Each [row] is a `List<String>` of cell values (already split by comma).
  /// Required when [filePath] ends with `.csv`.
  final AccessLog Function(List<String> row)? csvRowParser;

  /// Custom JSON object parser.
  ///
  /// Use when your JSON schema differs from [AccessLog.fromJson].
  final AccessLog Function(Map<String, dynamic> json)? jsonParser;

  /// Creates a [FileLogCollector].
  FileLogCollector({
    required this.filePath,
    this.csvRowParser,
    this.jsonParser,
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
    final file = File(filePath);
    if (!file.existsSync()) {
      throw FileSystemException('Log file not found', filePath);
    }

    final ext = filePath.toLowerCase();
    List<AccessLog> all;

    if (ext.endsWith('.json')) {
      all = await _parseJsonArray(file);
    } else if (ext.endsWith('.jsonl') || ext.endsWith('.ndjson')) {
      all = await _parseJsonLines(file);
    } else if (ext.endsWith('.csv')) {
      all = await _parseCsv(file);
    } else {
      // Fallback: try JSON array
      all = await _parseJsonArray(file);
    }

    var result = all.where((log) {
      final inRange =
          !log.loginAt.isBefore(from) && !log.loginAt.isAfter(to);
      final matchesUser = userId == null || log.userId == userId;
      final matchesIp = ipAddress == null || log.ipAddress == ipAddress;
      return inRange && matchesUser && matchesIp;
    }).toList()
      ..sort((a, b) => b.loginAt.compareTo(a.loginAt));

    if (offset != null && offset > 0) result = result.skip(offset).toList();
    if (limit != null && limit > 0) result = result.take(limit).toList();
    return result;
  }

  @override
  Future<int> count({required DateTime from, required DateTime to}) async {
    final all = await collect(from: from, to: to);
    return all.length;
  }

  @override
  Future<bool> isAvailable() async => File(filePath).existsSync();

  // ── Parsers ───────────────────────────────────────────────────────────

  Future<List<AccessLog>> _parseJsonArray(File file) async {
    final content = await file.readAsString();
    final dynamic decoded = jsonDecode(content);
    if (decoded is! List) {
      throw FormatException(
        'Expected a JSON array in "$filePath". '
        'For newline-delimited JSON use a .jsonl extension.',
      );
    }
    return decoded
        .cast<Map<String, dynamic>>()
        .map<AccessLog>(
          jsonParser != null ? jsonParser! : AccessLog.fromJson,
        )
        .toList();
  }

  Future<List<AccessLog>> _parseJsonLines(File file) async {
    final lines = await file.readAsLines();
    final result = <AccessLog>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('//')) continue;
      final map = jsonDecode(trimmed) as Map<String, dynamic>;
      result.add(jsonParser != null ? jsonParser!(map) : AccessLog.fromJson(map));
    }
    return result;
  }

  Future<List<AccessLog>> _parseCsv(File file) async {
    if (csvRowParser == null) {
      throw StateError(
        'A csvRowParser is required to read CSV files. '
        'Provide one when constructing FileLogCollector.',
      );
    }
    final lines = await file.readAsLines();
    if (lines.isEmpty) return [];
    // Skip header row if present
    final dataLines = lines.first.contains('userId') ||
            lines.first.contains('user_id')
        ? lines.skip(1).toList()
        : lines;
    return dataLines
        .where((l) => l.trim().isNotEmpty)
        .map((l) => csvRowParser!(_splitCsvRow(l)))
        .toList();
  }

  /// Very basic CSV row splitter (handles quoted commas).
  static List<String> _splitCsvRow(String row) {
    final fields = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < row.length; i++) {
      final ch = row[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == ',' && !inQuotes) {
        fields.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    fields.add(buffer.toString().trim());
    return fields;
  }
}
