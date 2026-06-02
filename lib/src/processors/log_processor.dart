import '../core/report_config.dart';
import '../models/access_log.dart';
import '../models/compliance_standard.dart';
import 'data_anonymizer.dart';

/// Filters, cleans, sorts, and optionally anonymises a raw list of
/// [AccessLog] entries before they enter the risk-analysis stage.
///
/// Applied steps (in order):
/// 1. Apply [ReportConfig] field filters (userIds, IPs, countries, etc.)
/// 2. Remove duplicates (same id)
/// 3. Optionally anonymise PII via [DataAnonymizer]
/// 4. Apply standard-specific field defaulting
/// 5. Sort (by risk desc if configured, otherwise by date desc)
class LogProcessor {
  final bool anonymize;
  final ComplianceStandard standard;
  final ReportConfig config;

  /// Creates a [LogProcessor].
  LogProcessor({
    required this.anonymize,
    required this.standard,
    required this.config,
  });

  /// Processes [rawLogs] and returns the filtered, cleaned list.
  List<AccessLog> process(List<AccessLog> rawLogs) {
    var logs = List<AccessLog>.from(rawLogs);

    // ── 1. Remove duplicates ─────────────────────────────────────────────
    final seen = <String>{};
    logs = logs.where((l) => seen.add(l.id)).toList();

    // ── 2. Apply config-based filters ────────────────────────────────────
    logs = _applyFilters(logs);

    // ── 3. Anonymise if required ─────────────────────────────────────────
    if (anonymize || standard.requiresAnonymisation) {
      final anonymizer = DataAnonymizer(standard: standard);
      logs = logs.map(anonymizer.anonymize).toList();
    }

    // ── 4. Standard-specific field normalisation ─────────────────────────
    logs = _normalise(logs);

    // ── 5. Sort ──────────────────────────────────────────────────────────
    if (config.sortByRiskDescending) {
      logs.sort(
        (a, b) {
          final riskCmp =
              b.riskLevel.index.compareTo(a.riskLevel.index);
          if (riskCmp != 0) return riskCmp;
          return b.loginAt.compareTo(a.loginAt);
        },
      );
    } else {
      logs.sort((a, b) => b.loginAt.compareTo(a.loginAt));
    }

    // ── 6. Enforce maxTotalEntries ────────────────────────────────────────
    if (config.maxTotalEntries > 0 && logs.length > config.maxTotalEntries) {
      logs = logs.take(config.maxTotalEntries).toList();
    }

    return logs;
  }

  // ── Private ───────────────────────────────────────────────────────────

  List<AccessLog> _applyFilters(List<AccessLog> logs) {
    return logs.where((log) {
      // User ID whitelist
      if (config.filterByUserIds != null &&
          !config.filterByUserIds!.contains(log.userId)) {
        return false;
      }

      // IP whitelist
      if (config.filterByIpAddresses != null &&
          !config.filterByIpAddresses!.contains(log.ipAddress)) {
        return false;
      }

      // IP blacklist (exclude)
      if (config.excludeIpAddresses != null &&
          config.excludeIpAddresses!.contains(log.ipAddress)) {
        return false;
      }

      // Country filter
      if (config.filterByCountries != null && log.country != null &&
          !config.filterByCountries!.contains(log.country)) {
        return false;
      }

      // Role filter
      if (config.filterByRoles != null &&
          log.userRole != null &&
          !config.filterByRoles!.contains(log.userRole)) {
        return false;
      }

      // Risk level filter
      if (config.includeOnlyRiskLevels != null &&
          !config.includeOnlyRiskLevels!.contains(log.riskLevel)) {
        return false;
      }

      // Failures only
      if (config.showFailuresOnly &&
          log.status == LoginStatus.success) {
        return false;
      }

      // Anomalies only
      if (config.showAnomaliesOnly && !log.hasAnomaly) {
        return false;
      }

      return true;
    }).toList();
  }

  List<AccessLog> _normalise(List<AccessLog> logs) {
    switch (standard) {
      case ComplianceStandard.pciDss:
        // PCI-DSS: mask full card / account numbers in action metadata
        return logs
            .map(
              (l) => l.withRisk(
                riskLevel: l.riskLevel,
                hasAnomaly: l.hasAnomaly,
                notes: l.notes,
              ),
            )
            .toList();
      default:
        return logs;
    }
  }
}
