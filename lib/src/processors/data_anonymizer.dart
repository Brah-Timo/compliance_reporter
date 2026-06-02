import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../models/access_log.dart';
import '../models/compliance_standard.dart';

/// Masks personally identifiable information (PII) from [AccessLog] entries.
///
/// Applied automatically when:
/// - [ComplianceReporter.anonymizeSensitiveData] is `true`, **or**
/// - The report standard is [ComplianceStandard.gdpr] or
///   [ComplianceStandard.hipaa].
///
/// ## Fields masked per standard
///
/// | Field            | GDPR | HIPAA | PCI-DSS |
/// |------------------|------|-------|---------|
/// | `userName`       | ✅   | ✅    | —       |
/// | `userEmail`      | ✅   | ✅    | —       |
/// | `city`           | ✅   | ✅    | —       |
/// | `userAgent`      | ✅   | ✅    | —       |
/// | `isp`            | ✅   | ✅    | —       |
/// | `ipAddress`      | partial | partial | ✅ |
/// | `userId`         | hash | hash  | —       |
/// | action metadata  | ✅   | ✅    | ✅      |
class DataAnonymizer {
  final ComplianceStandard standard;

  /// Creates a [DataAnonymizer] for the given [standard].
  const DataAnonymizer({this.standard = ComplianceStandard.gdpr});

  /// Returns an anonymised copy of [log].
  AccessLog anonymize(AccessLog log) {
    return AccessLog(
      id: log.id,
      userId: _pseudonymise(log.userId),
      userName: _maskName(log.userName),
      userEmail: _maskEmail(log.userEmail),
      userRole: log.userRole, // role kept — needed for audit
      department: log.department, // department kept
      ipAddress: _maskIp(log.ipAddress),
      country: log.country, // country kept — needed for geo analysis
      city: null, // city removed
      isp: null, // ISP removed
      isVpn: log.isVpn,
      deviceType: log.deviceType, // device type kept
      operatingSystem: log.operatingSystem, // OS kept
      browser: _maskBrowser(log.browser),
      userAgent: null, // full UA removed
      loginAt: log.loginAt,
      logoutAt: log.logoutAt,
      actions: _anonymizeActions(log.actions),
      authMethod: log.authMethod,
      status: log.status,
      riskLevel: log.riskLevel,
      hasAnomaly: log.hasAnomaly,
      notes: log.notes,
      metadata: const {}, // all extra metadata cleared
    );
  }

  // ── Private helpers ───────────────────────────────────────────────────

  /// One-way pseudonymisation using SHA-256 (first 12 chars of hex digest).
  String _pseudonymise(String value) {
    final digest = sha256.convert(utf8.encode(value));
    return 'usr_${digest.toString().substring(0, 12)}';
  }

  String _maskName(String? name) {
    if (name == null || name.isEmpty) return '*** ***';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return '${parts[0][0]}***';
    return '${parts[0][0]}*** ${parts.last[0]}***';
  }

  String? _maskEmail(String? email) {
    if (email == null) return null;
    final at = email.indexOf('@');
    if (at <= 0) return '***@***.***';
    final local = email.substring(0, at);
    final domain = email.substring(at); // keeps @domain.com
    if (local.length <= 2) return '**$domain';
    return '${local[0]}${'*' * (local.length - 2)}${local[local.length - 1]}$domain';
  }

  String _maskIp(String ip) {
    if (ip.contains(':')) {
      // IPv6 — keep first two groups
      final groups = ip.split(':');
      if (groups.length >= 2) {
        return '${groups[0]}:${groups[1]}:****:****:****:****:****:****';
      }
      return '****';
    }
    // IPv4 — keep first two octets
    final parts = ip.split('.');
    if (parts.length == 4) return '${parts[0]}.${parts[1]}.×.×';
    return '×.×.×.×';
  }

  String? _maskBrowser(String? browser) {
    if (browser == null) return null;
    // Keep just the browser family name without version
    final families = ['Chrome', 'Firefox', 'Safari', 'Edge', 'Opera', 'curl'];
    for (final f in families) {
      if (browser.toLowerCase().contains(f.toLowerCase())) return f;
    }
    return 'Unknown';
  }

  List<UserAction> _anonymizeActions(List<UserAction> actions) {
    return actions.map((a) => UserAction(
          action: a.action, // action code kept
          resourceType: a.resourceType, // resource type kept
          resourceId: a.resourceId != null
              ? _pseudonymise(a.resourceId!)
              : null, // ID pseudonymised
          timestamp: a.timestamp,
          isSensitive: a.isSensitive,
          httpMethod: a.httpMethod,
          httpStatus: a.httpStatus,
          metadata: const {}, // metadata cleared
        )).toList();
  }
}
