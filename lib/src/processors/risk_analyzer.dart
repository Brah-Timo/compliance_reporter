import '../models/access_log.dart';
import '../models/compliance_standard.dart';
import '../models/risk_level.dart';

/// Scores every [AccessLog] entry against a configurable set of risk rules
/// and assigns a [RiskLevel].
///
/// ## Scoring rules
///
/// | Rule                                   | Score |
/// |----------------------------------------|-------|
/// | IP is blacklisted                      | +50   |
/// | Login status: `blocked`                | +35   |
/// | Login status: `failed`                 | +10   |
/// | Login status: `mfaFailed`              | +20   |
/// | Login at night (02:00–05:59 UTC)       | +15   |
/// | Coming from a VPN / Tor exit node      | +20   |
/// | Login from a new country (>1 country)  | +15   |
/// | Contains a sensitive action (DELETE…)  | +20   |
/// | Action count > 100                     | +15   |
/// | Action count > 500                     | +25   |
/// | Session duration > 8 h                 | +10   |
/// | No MFA used on an admin account        | +15   |
/// | First login ever (no prior history)    | +5    |
///
/// Final score → [RiskLevel]:
/// - 0–14 → low
/// - 15–29 → medium
/// - 30–49 → high
/// - ≥ 50 → critical
class RiskAnalyzer {
  /// The compliance standard — affects which rules carry extra weight.
  final ComplianceStandard standard;

  /// IP addresses that automatically push the score to critical territory.
  final List<String> blacklistedIps;

  /// Action codes that are classified as sensitive.
  final List<String> sensitiveActions;

  /// Roles that should always use MFA.
  final List<String> mfaRequiredRoles;

  /// Creates a [RiskAnalyzer].
  RiskAnalyzer({
    this.standard = ComplianceStandard.generic,
    this.blacklistedIps = const [],
    this.sensitiveActions = const [
      'DELETE',
      'BULK_DELETE',
      'EXPORT',
      'BULK_EXPORT',
      'PERMISSION_CHANGE',
      'ROLE_CHANGE',
      'USER_CREATE',
      'USER_DELETE',
      'CONFIG_CHANGE',
      'PASSWORD_RESET',
      'API_KEY_CREATE',
      'DOWNLOAD',
    ],
    this.mfaRequiredRoles = const ['admin', 'superadmin', 'root', 'security'],
  });

  /// Analyses each entry and returns a new list with [AccessLog.riskLevel]
  /// and [AccessLog.notes] populated.
  List<AccessLog> analyze(List<AccessLog> logs) {
    // Track countries per user for cross-country detection
    final userCountries = <String, Set<String>>{};
    for (final log in logs) {
      if (log.country != null) {
        (userCountries[log.userId] ??= {}).add(log.country!);
      }
    }

    return logs.map((log) {
      final result = _score(log, userCountries);
      return log.withRisk(
        riskLevel: RiskLevel.fromScore(result.score),
        hasAnomaly: result.score >= RiskLevel.high.minScore,
        notes: result.notes.isEmpty ? null : result.notes.join(' | '),
      );
    }).toList();
  }

  _ScoreResult _score(
    AccessLog log,
    Map<String, Set<String>> userCountries,
  ) {
    var score = 0;
    final notes = <String>[];

    // ── Rule 1: Blacklisted IP ────────────────────────────────────────────
    if (blacklistedIps.contains(log.ipAddress)) {
      score += 50;
      notes.add('IP ${log.ipAddress} is blacklisted');
    }

    // ── Rule 2: Login status ──────────────────────────────────────────────
    switch (log.status) {
      case LoginStatus.blocked:
        score += 35;
        notes.add('Account blocked during login');
      case LoginStatus.failed:
        score += 10;
        notes.add('Login attempt failed');
      case LoginStatus.mfaFailed:
        score += 20;
        notes.add('MFA challenge failed');
      case LoginStatus.forcedLogout:
        score += 15;
        notes.add('Session was forcibly terminated');
      default:
        break;
    }

    // ── Rule 3: After-hours login (02:00–05:59 UTC) ───────────────────────
    final hour = log.loginAt.toUtc().hour;
    if (hour >= 2 && hour < 6) {
      score += 15;
      notes.add('After-hours login at ${hour.toString().padLeft(2, '0')}:00 UTC');
    }

    // ── Rule 4: VPN / Tor ─────────────────────────────────────────────────
    if (log.isVpn) {
      score += 20;
      notes.add('Login via VPN or anonymising proxy');
    }

    // ── Rule 5: Multi-country user ────────────────────────────────────────
    final countries = userCountries[log.userId] ?? {};
    if (countries.length > 1) {
      score += 15;
      notes.add(
        'User accessed from ${countries.length} different countries: '
        '${countries.take(5).join(', ')}',
      );
    }

    // ── Rule 6: Sensitive actions ─────────────────────────────────────────
    final hasSensitive = log.actions.any(
      (a) => sensitiveActions.any((s) => a.action.toUpperCase().contains(s)),
    );
    if (hasSensitive) {
      score += 20;
      final sensitiveList = log.actions
          .where((a) => sensitiveActions.any(
                (s) => a.action.toUpperCase().contains(s),
              ))
          .map((a) => a.action)
          .take(3)
          .join(', ');
      notes.add('Sensitive actions performed: $sensitiveList');
    }

    // ── Rule 7: High action count ─────────────────────────────────────────
    if (log.actions.length > 500) {
      score += 25;
      notes.add(
        'Extremely high action count: ${log.actions.length} actions',
      );
    } else if (log.actions.length > 100) {
      score += 15;
      notes.add('High action count: ${log.actions.length} actions');
    }

    // ── Rule 8: Long session (> 8 hours) ──────────────────────────────────
    final durSec = log.sessionDurationSeconds ?? 0;
    if (durSec > 28800) {
      score += 10;
      notes.add(
        'Unusually long session: ${(durSec / 3600).toStringAsFixed(1)} hours',
      );
    }

    // ── Rule 9: Admin without MFA ─────────────────────────────────────────
    final isAdminRole = mfaRequiredRoles
        .any((r) => (log.userRole ?? '').toLowerCase().contains(r));
    final usedMfa =
        log.authMethod?.toLowerCase().contains('mfa') == true ||
        log.authMethod?.toLowerCase().contains('totp') == true ||
        log.authMethod?.toLowerCase().contains('2fa') == true;
    if (isAdminRole && !usedMfa) {
      score += 15;
      notes.add(
        'Privileged role "${log.userRole}" logged in without MFA',
      );
    }

    // ── SOC 2 extra weight: any security event ────────────────────────────
    if (standard == ComplianceStandard.soc2 &&
        log.status.isSecurityEvent) {
      score += 5;
    }

    return _ScoreResult(score: score, notes: notes);
  }
}

class _ScoreResult {
  final int score;
  final List<String> notes;
  const _ScoreResult({required this.score, required this.notes});
}
