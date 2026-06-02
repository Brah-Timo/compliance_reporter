import 'package:crypto/crypto.dart';
import 'dart:convert';

import 'risk_level.dart';

/// A single access-log entry — the fundamental data unit of every report.
///
/// Represents one user session: who logged in, from where, using what
/// device, what they did, when they left, and how risky it was.
///
/// Create entries manually for testing:
/// ```dart
/// final log = AccessLog(
///   id: 'log_001',
///   userId: 'u_42',
///   ipAddress: '203.0.113.5',
///   loginAt: DateTime.now().subtract(2.hours),
///   actions: [UserAction(action: 'VIEW_INVOICE', timestamp: DateTime.now())],
/// );
/// ```
///
/// Or deserialise from JSON:
/// ```dart
/// final log = AccessLog.fromJson(jsonDecode(jsonString));
/// ```
class AccessLog {
  // ── Identity ──────────────────────────────────────────────────────────

  /// Unique identifier for this log entry (e.g. UUID or database row ID).
  final String id;

  /// The authenticated user's unique identifier.
  final String userId;

  /// Full display name (may be `null` for anonymous / system accounts).
  final String? userName;

  /// Email address of the user.
  final String? userEmail;

  /// Role or permission group (e.g. `'admin'`, `'auditor'`, `'viewer'`).
  final String? userRole;

  /// Department or business unit.
  final String? department;

  // ── Network ───────────────────────────────────────────────────────────

  /// IPv4 or IPv6 source address.
  final String ipAddress;

  /// ISO 3166-1 alpha-2 country code derived from GeoIP (e.g. `'US'`).
  final String? country;

  /// City name derived from GeoIP.
  final String? city;

  /// ASN / ISP name (useful for cloud-provider / VPN detection).
  final String? isp;

  /// `true` if the IP resolves to a known VPN or Tor exit node.
  final bool isVpn;

  // ── Device & browser ──────────────────────────────────────────────────

  /// High-level device category: `'Mobile'`, `'Desktop'`, `'Tablet'`, `'API'`.
  final String? deviceType;

  /// Operating system (e.g. `'Windows 11'`, `'iOS 17'`).
  final String? operatingSystem;

  /// Browser or client identifier (e.g. `'Chrome 124'`, `'curl/8.1.0'`).
  final String? browser;

  /// Full HTTP User-Agent string.
  final String? userAgent;

  // ── Timing ────────────────────────────────────────────────────────────

  /// Timestamp when the session / login occurred.
  final DateTime loginAt;

  /// Timestamp when the session ended. `null` for still-active sessions.
  final DateTime? logoutAt;

  // ── Activity ──────────────────────────────────────────────────────────

  /// Ordered list of actions performed during this session.
  final List<UserAction> actions;

  /// Authentication method used (e.g. `'password'`, `'sso'`, `'mfa'`, `'api_key'`).
  final String? authMethod;

  // ── Status & risk ─────────────────────────────────────────────────────

  /// Outcome of the login attempt.
  final LoginStatus status;

  /// Risk level assigned by [RiskAnalyzer]. Starts as [RiskLevel.low]
  /// and is updated during the analysis step.
  final RiskLevel riskLevel;

  /// `true` after [AnomalyDetector] flags this session.
  final bool hasAnomaly;

  /// Human-readable notes produced by [RiskAnalyzer] explaining the score.
  final String? notes;

  // ── Extra metadata ────────────────────────────────────────────────────

  /// Arbitrary key-value metadata from the source system.
  final Map<String, dynamic> metadata;

  // ── Constructor ───────────────────────────────────────────────────────

  /// Creates an [AccessLog] entry.
  const AccessLog({
    required this.id,
    required this.userId,
    this.userName,
    this.userEmail,
    this.userRole,
    this.department,
    required this.ipAddress,
    this.country,
    this.city,
    this.isp,
    this.isVpn = false,
    this.deviceType,
    this.operatingSystem,
    this.browser,
    this.userAgent,
    required this.loginAt,
    this.logoutAt,
    this.actions = const [],
    this.authMethod,
    this.status = LoginStatus.success,
    this.riskLevel = RiskLevel.low,
    this.hasAnomaly = false,
    this.notes,
    this.metadata = const {},
  });

  // ── Computed ──────────────────────────────────────────────────────────

  /// Session duration in seconds, or `null` for active sessions.
  int? get sessionDurationSeconds =>
      logoutAt != null ? logoutAt!.difference(loginAt).inSeconds : null;

  /// Session duration as a [Duration], or `null` for active sessions.
  Duration? get sessionDuration => logoutAt != null
      ? logoutAt!.difference(loginAt)
      : null;

  /// `true` if the session is still active (no logout recorded).
  bool get isActive => logoutAt == null;

  /// Number of actions recorded in this session.
  int get actionCount => actions.length;

  /// `true` if any [UserAction] has `isSensitive == true`.
  bool get hasSensitiveActions => actions.any((a) => a.isSensitive);

  // ── Serialisation ─────────────────────────────────────────────────────

  /// Creates an [AccessLog] from a JSON map.
  factory AccessLog.fromJson(Map<String, dynamic> json) {
    return AccessLog(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? json['user_id'] as String,
      userName: json['userName'] as String? ?? json['user_name'] as String?,
      userEmail: json['userEmail'] as String? ?? json['user_email'] as String?,
      userRole: json['userRole'] as String? ?? json['user_role'] as String?,
      department: json['department'] as String?,
      ipAddress: json['ipAddress'] as String? ??
          json['ip_address'] as String? ??
          '0.0.0.0',
      country: json['country'] as String?,
      city: json['city'] as String?,
      isp: json['isp'] as String?,
      isVpn: (json['isVpn'] as bool?) ?? (json['is_vpn'] as bool?) ?? false,
      deviceType: json['deviceType'] as String? ?? json['device_type'] as String?,
      operatingSystem: json['operatingSystem'] as String? ??
          json['operating_system'] as String?,
      browser: json['browser'] as String?,
      userAgent: json['userAgent'] as String? ?? json['user_agent'] as String?,
      loginAt: _parseDate(json['loginAt'] ?? json['login_at'])!,
      logoutAt: _parseDate(json['logoutAt'] ?? json['logout_at']),
      actions: (json['actions'] as List<dynamic>?)
              ?.map((e) => UserAction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      authMethod: json['authMethod'] as String? ?? json['auth_method'] as String?,
      status: _parseLoginStatus(json['status'] as String?),
      riskLevel: _parseRiskLevel(json['riskLevel'] as String?),
      hasAnomaly: (json['hasAnomaly'] as bool?) ?? false,
      notes: json['notes'] as String?,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }

  /// Converts this entry to a JSON map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'userRole': userRole,
        'department': department,
        'ipAddress': ipAddress,
        'country': country,
        'city': city,
        'isp': isp,
        'isVpn': isVpn,
        'deviceType': deviceType,
        'operatingSystem': operatingSystem,
        'browser': browser,
        'userAgent': userAgent,
        'loginAt': loginAt.toIso8601String(),
        'logoutAt': logoutAt?.toIso8601String(),
        'actions': actions.map((a) => a.toJson()).toList(),
        'authMethod': authMethod,
        'status': status.name,
        'riskLevel': riskLevel.name,
        'hasAnomaly': hasAnomaly,
        'notes': notes,
        'metadata': metadata,
      };

  // ── Privacy helpers ───────────────────────────────────────────────────

  /// Returns a copy with PII fields masked for GDPR / HIPAA compliance.
  AccessLog anonymized() => AccessLog(
        id: id,
        userId: _obfuscate(userId),
        userName: '*** ***',
        userEmail: _maskEmail(userEmail),
        userRole: userRole,
        department: department,
        ipAddress: _maskIp(ipAddress),
        country: country,
        city: null,
        isp: null,
        isVpn: isVpn,
        deviceType: deviceType,
        operatingSystem: operatingSystem,
        browser: null,
        userAgent: null,
        loginAt: loginAt,
        logoutAt: logoutAt,
        actions: actions.map((a) => a.withoutSensitiveMetadata()).toList(),
        authMethod: authMethod,
        status: status,
        riskLevel: riskLevel,
        hasAnomaly: hasAnomaly,
        notes: notes,
        metadata: const {},
      );

  /// Returns a copy with updated risk information (immutable-style update).
  AccessLog withRisk({
    required RiskLevel riskLevel,
    bool hasAnomaly = false,
    String? notes,
  }) =>
      AccessLog(
        id: id,
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        userRole: userRole,
        department: department,
        ipAddress: ipAddress,
        country: country,
        city: city,
        isp: isp,
        isVpn: isVpn,
        deviceType: deviceType,
        operatingSystem: operatingSystem,
        browser: browser,
        userAgent: userAgent,
        loginAt: loginAt,
        logoutAt: logoutAt,
        actions: actions,
        authMethod: authMethod,
        status: status,
        riskLevel: riskLevel,
        hasAnomaly: hasAnomaly,
        notes: notes ?? this.notes,
        metadata: metadata,
      );

  // ── Private helpers ───────────────────────────────────────────────────

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  static LoginStatus _parseLoginStatus(String? s) {
    return LoginStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => LoginStatus.success,
    );
  }

  static RiskLevel _parseRiskLevel(String? s) {
    return RiskLevel.values.firstWhere(
      (e) => e.name == s,
      orElse: () => RiskLevel.low,
    );
  }

  static String _obfuscate(String value) {
    final digest = sha256.convert(utf8.encode(value));
    return digest.toString().substring(0, 12);
  }

  static String? _maskEmail(String? email) {
    if (email == null) return null;
    final parts = email.split('@');
    if (parts.length != 2) return '***@***.***';
    final local = parts[0];
    final domain = parts[1];
    final masked = local.length <= 2
        ? '**'
        : '${local[0]}${'*' * (local.length - 2)}${local[local.length - 1]}';
    return '$masked@$domain';
  }

  static String _maskIp(String ip) {
    final parts = ip.split('.');
    if (parts.length == 4) return '${parts[0]}.${parts[1]}.*.*';
    // IPv6 — mask last 4 groups
    final v6 = ip.split(':');
    if (v6.length > 4) {
      return '${v6.take(4).join(':')}:****:****:****:****';
    }
    return '***';
  }

  @override
  String toString() =>
      'AccessLog(id=$id, userId=$userId, ip=$ipAddress, '
      'loginAt=${loginAt.toIso8601String()}, risk=${riskLevel.name})';
}

// ── UserAction ────────────────────────────────────────────────────────────

/// A single action performed by a user within a session.
class UserAction {
  /// Action code (e.g. `'VIEW_REPORT'`, `'DELETE_USER'`, `'EXPORT_CSV'`).
  final String action;

  /// The type of resource affected (e.g. `'Invoice'`, `'UserProfile'`).
  final String? resourceType;

  /// The ID of the affected resource.
  final String? resourceId;

  /// When the action occurred.
  final DateTime timestamp;

  /// `true` for destructive or privileged actions (delete, export, config).
  final bool isSensitive;

  /// HTTP method if the action maps to an API call (GET, POST, DELETE, etc.).
  final String? httpMethod;

  /// HTTP response code returned.
  final int? httpStatus;

  /// Additional structured context.
  final Map<String, dynamic> metadata;

  /// Creates a [UserAction].
  const UserAction({
    required this.action,
    this.resourceType,
    this.resourceId,
    required this.timestamp,
    this.isSensitive = false,
    this.httpMethod,
    this.httpStatus,
    this.metadata = const {},
  });

  /// Deserialises from JSON.
  factory UserAction.fromJson(Map<String, dynamic> json) => UserAction(
        action: json['action'] as String,
        resourceType: json['resourceType'] as String?,
        resourceId: json['resourceId'] as String?,
        timestamp: DateTime.parse(json['timestamp'] as String),
        isSensitive: (json['isSensitive'] as bool?) ?? false,
        httpMethod: json['httpMethod'] as String?,
        httpStatus: json['httpStatus'] as int?,
        metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
      );

  /// Serialises to JSON.
  Map<String, dynamic> toJson() => {
        'action': action,
        'resourceType': resourceType,
        'resourceId': resourceId,
        'timestamp': timestamp.toIso8601String(),
        'isSensitive': isSensitive,
        'httpMethod': httpMethod,
        'httpStatus': httpStatus,
        'metadata': metadata,
      };

  /// Returns a copy with metadata cleared (used during anonymisation).
  UserAction withoutSensitiveMetadata() => UserAction(
        action: action,
        resourceType: resourceType,
        resourceId: resourceId,
        timestamp: timestamp,
        isSensitive: isSensitive,
        httpMethod: httpMethod,
        httpStatus: httpStatus,
      );
}

// ── LoginStatus ───────────────────────────────────────────────────────────

/// The outcome of a login attempt or session event.
enum LoginStatus {
  /// Authentication succeeded.
  success,

  /// Authentication failed (bad credentials).
  failed,

  /// Account was blocked before or during the attempt.
  blocked,

  /// Session was terminated by an administrator.
  forcedLogout,

  /// Session expired due to inactivity timeout.
  sessionExpired,

  /// Multi-factor authentication challenge failed.
  mfaFailed;

  /// Human-readable label for display in reports.
  String get label => switch (this) {
        LoginStatus.success => 'Success',
        LoginStatus.failed => 'Failed',
        LoginStatus.blocked => 'Blocked',
        LoginStatus.forcedLogout => 'Forced Logout',
        LoginStatus.sessionExpired => 'Session Expired',
        LoginStatus.mfaFailed => 'MFA Failed',
      };

  /// `true` for statuses that represent a security event.
  bool get isSecurityEvent => switch (this) {
        LoginStatus.success || LoginStatus.sessionExpired => false,
        _ => true,
      };
}
