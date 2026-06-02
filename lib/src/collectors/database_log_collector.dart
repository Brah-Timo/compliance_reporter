import 'base_log_collector.dart';
import '../models/access_log.dart';

/// A [BaseLogCollector] adapter for SQL / NoSQL databases.
///
/// Because `compliance_reporter` is a pure Dart package with no direct
/// database dependency, this class acts as a **bridge**: you supply two
/// callbacks — [queryFn] and [countFn] — that execute the actual query
/// in your database layer and return raw row maps.
///
/// This design works with **any** database driver:
/// - `sqflite` (SQLite on mobile)
/// - `drift` (type-safe SQLite ORM)
/// - `postgres` (PostgreSQL)
/// - `mysql_client` (MySQL)
/// - Firebase Firestore (via snapshot maps)
/// - Supabase, PlanetScale, Neon (via REST / dart clients)
///
/// ## Example with `sqflite`
///
/// ```dart
/// final db = await openDatabase('app.db');
///
/// final collector = DatabaseLogCollector(
///   queryFn: ({
///     required from,
///     required to,
///     userId,
///     ipAddress,
///     limit,
///     offset,
///   }) async {
///     final rows = await db.query(
///       'access_logs',
///       where: 'login_at BETWEEN ? AND ?'
///           '${userId != null ? " AND user_id = ?" : ""}'
///           '${ipAddress != null ? " AND ip_address = ?" : ""}',
///       whereArgs: [
///         from.toIso8601String(),
///         to.toIso8601String(),
///         if (userId != null) userId,
///         if (ipAddress != null) ipAddress,
///       ],
///       orderBy: 'login_at DESC',
///       limit: limit,
///       offset: offset,
///     );
///     return rows;
///   },
///   countFn: ({required from, required to}) async {
///     final result = await db.rawQuery(
///       'SELECT COUNT(*) FROM access_logs WHERE login_at BETWEEN ? AND ?',
///       [from.toIso8601String(), to.toIso8601String()],
///     );
///     return Sqflite.firstIntValue(result) ?? 0;
///   },
///   rowMapper: (row) => AccessLog(
///     id: row['id'].toString(),
///     userId: row['user_id'] as String,
///     ipAddress: row['ip_address'] as String,
///     loginAt: DateTime.parse(row['login_at'] as String),
///   ),
/// );
/// ```
class DatabaseLogCollector extends BaseLogCollector {
  /// Executes the query and returns raw row maps from your DB driver.
  final Future<List<Map<String, dynamic>>> Function({
    required DateTime from,
    required DateTime to,
    String? userId,
    String? ipAddress,
    int? limit,
    int? offset,
  }) queryFn;

  /// Returns the total count for a date range (used by [count]).
  ///
  /// If not provided, [count] returns `-1`.
  final Future<int> Function({
    required DateTime from,
    required DateTime to,
  })? countFn;

  /// Checks database connectivity (used by [isAvailable]).
  ///
  /// If not provided, [isAvailable] returns `true`.
  final Future<bool> Function()? pingFn;

  /// Converts a raw database row into an [AccessLog].
  ///
  /// If not provided, the row is passed to [AccessLog.fromJson] directly.
  final AccessLog Function(Map<String, dynamic> row)? rowMapper;

  /// Creates a [DatabaseLogCollector].
  DatabaseLogCollector({
    required this.queryFn,
    this.countFn,
    this.pingFn,
    this.rowMapper,
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
    final rows = await queryFn(
      from: from,
      to: to,
      userId: userId,
      ipAddress: ipAddress,
      limit: limit,
      offset: offset,
    );

    final mapper = rowMapper ?? AccessLog.fromJson;
    return rows.map<AccessLog>(mapper).toList();
  }

  @override
  Future<int> count({
    required DateTime from,
    required DateTime to,
  }) async {
    if (countFn == null) return -1;
    return countFn!(from: from, to: to);
  }

  @override
  Future<bool> isAvailable() async {
    if (pingFn == null) return true;
    try {
      return await pingFn!();
    } catch (_) {
      return false;
    }
  }
}
