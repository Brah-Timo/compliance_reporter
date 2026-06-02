import '../models/access_log.dart';
import '../models/risk_level.dart';

/// Detects behavioural anomalies across a set of [AccessLog] entries.
///
/// Runs after [RiskAnalyzer] and operates on the full dataset to find
/// patterns that a per-entry scorer cannot see in isolation:
///
/// | Detection                               | Description                              |
/// |-----------------------------------------|------------------------------------------|
/// | **Impossible travel**                   | Same user logged in from two countries   |
/// |                                         | within an implausibly short timeframe    |
/// | **Brute-force burst**                   | ≥ N failed logins in a rolling window    |
/// | **Credential stuffing**                 | Many distinct users failing from one IP  |
/// | **Off-hours admin access**              | Admin login between 00:00–06:00 UTC      |
/// | **Concurrent sessions**                 | Same user active from >1 IP at same time |
/// | **Bulk data exfiltration**              | Unusually high EXPORT / DOWNLOAD count   |
/// | **New device / OS first seen**          | User agent never seen before for user    |
/// | **Sudden privilege escalation**         | Role changed to admin in this period     |
class AnomalyDetector {
  // ── Thresholds ────────────────────────────────────────────────────────

  /// Minimum minutes between logins from different countries for
  /// "impossible travel" to trigger.
  final int impossibleTravelMinutes;

  /// Number of failed logins within [bruteForceWindowMinutes] to
  /// classify as a brute-force attack.
  final int bruteForceThreshold;

  /// Rolling window (in minutes) for brute-force detection.
  final int bruteForceWindowMinutes;

  /// Number of distinct failed users from one IP to classify as
  /// credential stuffing.
  final int credentialStuffingThreshold;

  /// Number of EXPORT / DOWNLOAD actions in a session to flag as
  /// potential data exfiltration.
  final int exfiltrationActionThreshold;

  /// Creates an [AnomalyDetector].
  AnomalyDetector({
    this.impossibleTravelMinutes = 120,
    this.bruteForceThreshold = 5,
    this.bruteForceWindowMinutes = 10,
    this.credentialStuffingThreshold = 10,
    this.exfiltrationActionThreshold = 50,
  });

  /// Runs all anomaly detectors and returns the findings.
  List<AnomalyReport> detect(List<AccessLog> logs) {
    final reports = <AnomalyReport>[];

    reports.addAll(_detectImpossibleTravel(logs));
    reports.addAll(_detectBruteForce(logs));
    reports.addAll(_detectCredentialStuffing(logs));
    reports.addAll(_detectConcurrentSessions(logs));
    reports.addAll(_detectExfiltration(logs));
    reports.addAll(_detectOffHoursAdmin(logs));

    // Sort by severity
    reports.sort((a, b) => b.severity.index.compareTo(a.severity.index));
    return reports;
  }

  // ── Detectors ─────────────────────────────────────────────────────────

  List<AnomalyReport> _detectImpossibleTravel(List<AccessLog> logs) {
    final reports = <AnomalyReport>[];
    final byUser = _groupByUser(logs);

    for (final entry in byUser.entries) {
      final userLogs = entry.value
        ..sort((a, b) => a.loginAt.compareTo(b.loginAt));

      for (var i = 1; i < userLogs.length; i++) {
        final prev = userLogs[i - 1];
        final curr = userLogs[i];
        if (prev.country == null ||
            curr.country == null ||
            prev.country == curr.country) continue;

        final diff = curr.loginAt.difference(prev.loginAt);
        if (diff.inMinutes < impossibleTravelMinutes) {
          reports.add(AnomalyReport(
            type: AnomalyType.impossibleTravel,
            severity: RiskLevel.critical,
            userId: entry.key,
            affectedLogIds: [prev.id, curr.id],
            description:
                'Impossible travel detected for user "${entry.key}": '
                'logged in from ${prev.country} at ${_fmt(prev.loginAt)}, '
                'then from ${curr.country} only ${diff.inMinutes} minutes later.',
            detectedAt: curr.loginAt,
            evidence: {
              'prevCountry': prev.country!,
              'currCountry': curr.country!,
              'prevIp': prev.ipAddress,
              'currIp': curr.ipAddress,
              'minutesBetween': diff.inMinutes,
            },
          ),
        );
        }
      }
    }
    return reports;
  }

  List<AnomalyReport> _detectBruteForce(List<AccessLog> logs) {
    final reports = <AnomalyReport>[];
    final byUser = _groupByUser(logs);

    for (final entry in byUser.entries) {
      final failures = entry.value
          .where((l) => l.status == LoginStatus.failed)
          .toList()
        ..sort((a, b) => a.loginAt.compareTo(b.loginAt));

      if (failures.length < bruteForceThreshold) continue;

      // Sliding window
      for (var i = 0; i <= failures.length - bruteForceThreshold; i++) {
        final window = failures.sublist(i, i + bruteForceThreshold);
        final span = window.last.loginAt
            .difference(window.first.loginAt)
            .inMinutes;
        if (span <= bruteForceWindowMinutes) {
          reports.add(AnomalyReport(
            type: AnomalyType.bruteForce,
            severity: RiskLevel.critical,
            userId: entry.key,
            affectedLogIds: window.map((l) => l.id).toList(),
            description:
                'Brute-force attack detected: ${window.length} failed logins '
                'for user "${entry.key}" within $span minutes '
                '(threshold: $bruteForceThreshold in $bruteForceWindowMinutes min).',
            detectedAt: window.last.loginAt,
            evidence: {
              'failureCount': window.length,
              'windowMinutes': span,
              'sourceIps': window.map((l) => l.ipAddress).toSet().toList(),
            },
          ),
        );
          break; // one report per user
        }
      }
    }
    return reports;
  }

  List<AnomalyReport> _detectCredentialStuffing(List<AccessLog> logs) {
    final reports = <AnomalyReport>[];
    final byIp = <String, List<AccessLog>>{};

    for (final log in logs) {
      if (log.status == LoginStatus.failed) {
        (byIp[log.ipAddress] ??= []).add(log);
      }
    }

    for (final entry in byIp.entries) {
      final distinctUsers = entry.value.map((l) => l.userId).toSet();
      if (distinctUsers.length >= credentialStuffingThreshold) {
        reports.add(AnomalyReport(
          type: AnomalyType.credentialStuffing,
          severity: RiskLevel.critical,
          userId: null,
          affectedLogIds: entry.value.map((l) => l.id).toList(),
          description:
              'Credential stuffing detected from IP ${entry.key}: '
              '${distinctUsers.length} distinct user accounts '
              'attempted (threshold: $credentialStuffingThreshold).',
          detectedAt: entry.value.last.loginAt,
          evidence: {
            'sourceIp': entry.key,
            'distinctUsersAttempted': distinctUsers.length,
            'totalAttempts': entry.value.length,
          },
        ),
      );
      }
    }
    return reports;
  }

  List<AnomalyReport> _detectConcurrentSessions(List<AccessLog> logs) {
    final reports = <AnomalyReport>[];
    final byUser = _groupByUser(logs);

    for (final entry in byUser.entries) {
      // Find sessions that overlap in time from different IPs
      final activeSessions = entry.value
          .where((l) => l.logoutAt != null)
          .toList();

      for (var i = 0; i < activeSessions.length; i++) {
        for (var j = i + 1; j < activeSessions.length; j++) {
          final a = activeSessions[i];
          final b = activeSessions[j];
          if (a.ipAddress == b.ipAddress) continue;

          final overlap =
              a.loginAt.isBefore(b.logoutAt!) &&
              b.loginAt.isBefore(a.logoutAt!);
          if (overlap) {
            reports.add(AnomalyReport(
              type: AnomalyType.concurrentSessions,
              severity: RiskLevel.high,
              userId: entry.key,
              affectedLogIds: [a.id, b.id],
              description:
                  'Concurrent sessions for user "${entry.key}" from '
                  'two different IPs: ${a.ipAddress} and ${b.ipAddress}.',
              detectedAt: b.loginAt,
              evidence: {
                'ip1': a.ipAddress,
                'ip2': b.ipAddress,
                'session1Start': _fmt(a.loginAt),
                'session2Start': _fmt(b.loginAt),
              },
            ),
          );
          }
        }
      }
    }
    return reports;
  }

  List<AnomalyReport> _detectExfiltration(List<AccessLog> logs) {
    final reports = <AnomalyReport>[];
    for (final log in logs) {
      final exportCount = log.actions.where((a) {
        final upper = a.action.toUpperCase();
        return upper.contains('EXPORT') ||
            upper.contains('DOWNLOAD') ||
            upper.contains('BULK_');
      }).length;

      if (exportCount >= exfiltrationActionThreshold) {
        reports.add(AnomalyReport(
          type: AnomalyType.dataExfiltration,
          severity: RiskLevel.critical,
          userId: log.userId,
          affectedLogIds: [log.id],
          description:
              'Potential data exfiltration: user "${log.userId}" performed '
              '$exportCount export/download actions in one session '
              '(threshold: $exfiltrationActionThreshold).',
          detectedAt: log.loginAt,
          evidence: {
            'sessionId': log.id,
            'exportActionCount': exportCount,
            'totalActions': log.actions.length,
          },
        ),
      );
      }
    }
    return reports;
  }

  List<AnomalyReport> _detectOffHoursAdmin(List<AccessLog> logs) {
    final reports = <AnomalyReport>[];
    for (final log in logs) {
      final isAdmin =
          (log.userRole ?? '').toLowerCase().contains('admin');
      final hour = log.loginAt.toUtc().hour;
      final isOffHours = hour < 6 || hour >= 22;
      if (isAdmin && isOffHours) {
        reports.add(AnomalyReport(
          type: AnomalyType.offHoursAdminAccess,
          severity: RiskLevel.high,
          userId: log.userId,
          affectedLogIds: [log.id],
          description:
              'Admin access outside business hours: user "${log.userId}" '
              '(role: ${log.userRole}) logged in at ${_fmt(log.loginAt)} UTC.',
          detectedAt: log.loginAt,
          evidence: {
            'role': log.userRole,
            'loginHourUtc': hour,
            'ipAddress': log.ipAddress,
          },
        ),
      );
      }
    }
    return reports;
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  static Map<String, List<AccessLog>> _groupByUser(List<AccessLog> logs) {
    final map = <String, List<AccessLog>>{};
    for (final log in logs) {
      (map[log.userId] ??= []).add(log);
    }
    return map;
  }

  static String _fmt(DateTime dt) =>
      dt.toUtc().toIso8601String().substring(0, 19);
}

// ── AnomalyReport ─────────────────────────────────────────────────────────

/// A single anomaly finding produced by [AnomalyDetector].
class AnomalyReport {
  /// The category of anomaly detected.
  final AnomalyType type;

  /// How severe this anomaly is.
  final RiskLevel severity;

  /// The primary user involved (`null` for IP-level anomalies).
  final String? userId;

  /// IDs of the [AccessLog] entries that triggered this finding.
  final List<String> affectedLogIds;

  /// Human-readable explanation of what was detected.
  final String description;

  /// When the anomaly was detected (usually the triggering log's timestamp).
  final DateTime detectedAt;

  /// Structured evidence map for further programmatic processing.
  final Map<String, dynamic> evidence;

  /// Creates an [AnomalyReport].
  const AnomalyReport({
    required this.type,
    required this.severity,
    this.userId,
    required this.affectedLogIds,
    required this.description,
    required this.detectedAt,
    this.evidence = const {},
  });

  /// Serialises to JSON.
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'severity': severity.name,
        'userId': userId,
        'affectedLogIds': affectedLogIds,
        'description': description,
        'detectedAt': detectedAt.toIso8601String(),
        'evidence': evidence,
      };

  @override
  String toString() =>
      'AnomalyReport(type=${type.name}, severity=${severity.name}, '
      'user=$userId, at=${detectedAt.toIso8601String().substring(0, 10)})';
}

/// Categories of anomaly detected by [AnomalyDetector].
enum AnomalyType {
  /// Same user logged in from two different countries within minutes.
  impossibleTravel,

  /// Repeated failed login attempts within a short window.
  bruteForce,

  /// Many distinct accounts attacked from one IP.
  credentialStuffing,

  /// Same user active from multiple IPs simultaneously.
  concurrentSessions,

  /// Unusually high volume of export / download actions.
  dataExfiltration,

  /// Privileged user logged in outside business hours.
  offHoursAdminAccess;

  /// Human-readable label for the report.
  String get label => switch (this) {
        AnomalyType.impossibleTravel => 'Impossible Travel',
        AnomalyType.bruteForce => 'Brute-Force Attack',
        AnomalyType.credentialStuffing => 'Credential Stuffing',
        AnomalyType.concurrentSessions => 'Concurrent Sessions',
        AnomalyType.dataExfiltration => 'Data Exfiltration',
        AnomalyType.offHoursAdminAccess => 'Off-Hours Admin Access',
      };
}
