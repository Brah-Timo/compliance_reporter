import '../models/access_log.dart';

/// Abstract base class for all log-data sources.
///
/// Implement this class to connect any backend — database, REST API,
/// flat file, in-memory list, message queue, etc. — to the
/// `compliance_reporter` pipeline.
///
/// ## Minimal implementation
///
/// ```dart
/// class MyFirestoreCollector extends BaseLogCollector {
///   @override
///   Future<List<AccessLog>> collect({
///     required DateTime from,
///     required DateTime to,
///     String? userId,
///     String? ipAddress,
///     int? limit,
///     int? offset,
///   }) async {
///     final snapshot = await FirebaseFirestore.instance
///         .collection('audit_logs')
///         .where('loginAt', isGreaterThan: from)
///         .where('loginAt', isLessThan: to)
///         .get();
///     return snapshot.docs
///         .map((d) => AccessLog.fromJson(d.data()))
///         .toList();
///   }
/// }
/// ```
abstract class BaseLogCollector {
  /// Collects access-log entries within the given date range.
  ///
  /// **Parameters**
  /// - [from]        Start of the period (inclusive).
  /// - [to]          End of the period (inclusive).
  /// - [userId]      Optional filter: return only entries for this user.
  /// - [ipAddress]   Optional filter: return only entries from this IP.
  /// - [limit]       Maximum number of entries to return (`null` = all).
  /// - [offset]      Number of entries to skip (for pagination).
  ///
  /// Implementations should return entries sorted by [AccessLog.loginAt]
  /// in **descending** order (newest first) by convention.
  Future<List<AccessLog>> collect({
    required DateTime from,
    required DateTime to,
    String? userId,
    String? ipAddress,
    int? limit,
    int? offset,
  });

  /// Returns the total number of entries available for the given period
  /// **without** fetching the actual data.
  ///
  /// Used to show progress or build pagination UIs. Implementations that
  /// cannot determine the count efficiently may return `-1`.
  Future<int> count({
    required DateTime from,
    required DateTime to,
  });

  /// Returns `true` if the data source is reachable and ready.
  ///
  /// Called before [collect] by the pipeline to provide an early-fail
  /// diagnostic message instead of an obscure timeout error.
  Future<bool> isAvailable();

  /// Optional: releases any resources held by this collector (e.g. DB pool).
  Future<void> dispose() async {}
}
