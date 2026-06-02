import 'access_log.dart';
import 'risk_level.dart';

/// A higher-level aggregation of all [AccessLog] entries for a single user
/// within the report period.
///
/// Used by the "User Statistics" sheet in the Excel generator and by the
/// per-user summary tables in the PDF.
class UserSession {
  /// The user's unique identifier.
  final String userId;

  /// Display name (may be masked in anonymised reports).
  final String? userName;

  /// Email address (may be masked).
  final String? userEmail;

  /// Role or permission group.
  final String? userRole;

  /// All individual [AccessLog] entries for this user in the period.
  final List<AccessLog> logs;

  /// Creates a [UserSession].
  const UserSession({
    required this.userId,
    this.userName,
    this.userEmail,
    this.userRole,
    required this.logs,
  });

  // ── Computed aggregate stats ──────────────────────────────────────────

  /// Total login count (all statuses).
  int get loginCount => logs.length;

  /// Number of successful logins.
  int get successfulLogins =>
      logs.where((l) => l.status == LoginStatus.success).length;

  /// Number of failed login attempts.
  int get failedLogins =>
      logs.where((l) => l.status == LoginStatus.failed).length;

  /// Total actions across all sessions.
  int get totalActions => logs.fold(0, (sum, l) => sum + l.actionCount);

  /// Set of all unique IP addresses used.
  Set<String> get uniqueIps => logs.map((l) => l.ipAddress).toSet();

  /// Set of all unique countries seen.
  Set<String> get uniqueCountries =>
      logs.map((l) => l.country ?? 'Unknown').toSet();

  /// Highest risk level recorded across all sessions.
  RiskLevel get maxRiskLevel => logs.isEmpty
      ? RiskLevel.low
      : logs.map((l) => l.riskLevel).reduce((a, b) => a.max(b));

  /// `true` if any session was flagged as anomalous.
  bool get hasAnomaly => logs.any((l) => l.hasAnomaly);

  /// Average session duration in seconds (excludes active sessions).
  double get avgSessionDurationSeconds {
    final durations = logs
        .where((l) => l.sessionDurationSeconds != null)
        .map((l) => l.sessionDurationSeconds!)
        .toList();
    if (durations.isEmpty) return 0;
    return durations.reduce((a, b) => a + b) / durations.length;
  }

  /// First login time in the period.
  DateTime? get firstLogin =>
      logs.isEmpty ? null : logs.map((l) => l.loginAt).reduce(_min);

  /// Last login time in the period.
  DateTime? get lastLogin =>
      logs.isEmpty ? null : logs.map((l) => l.loginAt).reduce(_max);

  // ── Factory ───────────────────────────────────────────────────────────

  /// Builds a [UserSession] by grouping a flat list of [AccessLog] entries.
  ///
  /// Returns one [UserSession] per unique [AccessLog.userId].
  static List<UserSession> groupFromLogs(List<AccessLog> logs) {
    final map = <String, List<AccessLog>>{};
    for (final log in logs) {
      (map[log.userId] ??= []).add(log);
    }
    return map.entries.map((e) {
      final first = e.value.first;
      return UserSession(
        userId: e.key,
        userName: first.userName,
        userEmail: first.userEmail,
        userRole: first.userRole,
        logs: List.unmodifiable(e.value),
      );
    }).toList()
      ..sort((a, b) => b.loginCount.compareTo(a.loginCount));
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  static DateTime _min(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
  static DateTime _max(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  @override
  String toString() =>
      'UserSession(userId=$userId, logins=$loginCount, '
      'risk=${maxRiskLevel.name})';
}
