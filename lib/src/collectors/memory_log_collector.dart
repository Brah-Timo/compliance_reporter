import 'base_log_collector.dart';
import '../models/access_log.dart';

/// A [BaseLogCollector] that reads from an in-memory [List<AccessLog>].
///
/// Ideal for:
/// - Unit tests (inject fixed fixtures, assert exact output).
/// - Applications that load all logs upfront (e.g. from SharedPreferences
///   or a local SQLite cache) before building a report.
/// - Demo / example apps.
///
/// ## Example
///
/// ```dart
/// final logs = <AccessLog>[...]; // your data
///
/// final reporter = ComplianceReporter(
///   collector: MemoryLogCollector(logs: logs),
/// );
///
/// final result = await reporter.generate(from: 90.days.ago);
/// ```
class MemoryLogCollector extends BaseLogCollector {
  final List<AccessLog> _logs;

  /// Creates a [MemoryLogCollector] backed by [logs].
  ///
  /// The list is copied internally to avoid mutation surprises.
  MemoryLogCollector({required List<AccessLog> logs})
      : _logs = List.unmodifiable(logs);

  @override
  Future<List<AccessLog>> collect({
    required DateTime from,
    required DateTime to,
    String? userId,
    String? ipAddress,
    int? limit,
    int? offset,
  }) async {
    var result = _logs.where((log) {
      // ── Date range filter ────────────────────────────────────────────
      final inRange =
          !log.loginAt.isBefore(from) && !log.loginAt.isAfter(to);

      // ── Optional field filters ───────────────────────────────────────
      final matchesUser = userId == null || log.userId == userId;
      final matchesIp = ipAddress == null || log.ipAddress == ipAddress;

      return inRange && matchesUser && matchesIp;
    }).toList()
      ..sort((a, b) => b.loginAt.compareTo(a.loginAt)); // newest first

    if (offset != null && offset > 0) {
      result = result.skip(offset).toList();
    }
    if (limit != null && limit > 0) {
      result = result.take(limit).toList();
    }
    return result;
  }

  @override
  Future<int> count({
    required DateTime from,
    required DateTime to,
  }) async =>
      _logs
          .where(
            (l) => !l.loginAt.isBefore(from) && !l.loginAt.isAfter(to),
          )
          .length;

  @override
  Future<bool> isAvailable() async => true;

  /// Number of entries currently in the collector.
  int get length => _logs.length;
}
