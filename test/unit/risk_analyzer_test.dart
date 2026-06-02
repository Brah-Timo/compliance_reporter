import 'package:test/test.dart';

import 'package:compliance_reporter/compliance_reporter.dart';

AccessLog _makeLog({
  String id = 'test_log',
  String userId = 'u_test',
  String ipAddress = '192.168.1.1',
  DateTime? loginAt,
  LoginStatus status = LoginStatus.success,
  bool isVpn = false,
  String? userRole,
  String? authMethod,
  List<UserAction> actions = const [],
  String? country,
}) =>
    AccessLog(
      id: id,
      userId: userId,
      ipAddress: ipAddress,
      loginAt: loginAt ?? DateTime.utc(2026, 3, 15, 10, 0),
      status: status,
      isVpn: isVpn,
      userRole: userRole,
      authMethod: authMethod,
      actions: actions,
      country: country,
    );

void main() {
  group('RiskAnalyzer', () {
    late RiskAnalyzer analyzer;

    setUp(() {
      analyzer = RiskAnalyzer(
        blacklistedIps: ['10.0.0.99'],
      );
    });

    test('low risk for normal daytime login', () {
      final log = _makeLog(loginAt: DateTime.utc(2026, 3, 15, 10, 0));
      final result = analyzer.analyze([log]);
      expect(result.first.riskLevel, equals(RiskLevel.low));
    });

    test('adds score for blacklisted IP → critical', () {
      final log = _makeLog(ipAddress: '10.0.0.99');
      final result = analyzer.analyze([log]);
      expect(result.first.riskLevel, equals(RiskLevel.critical));
    });

    test('adds score for after-hours login (03:00 UTC)', () {
      final log = _makeLog(loginAt: DateTime.utc(2026, 3, 15, 3, 0));
      final result = analyzer.analyze([log]);
      expect(result.first.riskLevel.isAtLeast(RiskLevel.medium), isTrue);
    });

    test('adds score for VPN login', () {
      final log = _makeLog(isVpn: true);
      final result = analyzer.analyze([log]);
      expect(result.first.riskLevel.isAtLeast(RiskLevel.medium), isTrue);
    });

    test('adds score for blocked status', () {
      final log = _makeLog(status: LoginStatus.blocked);
      final result = analyzer.analyze([log]);
      expect(result.first.riskLevel.isAtLeast(RiskLevel.high), isTrue);
    });

    test('adds score for sensitive DELETE action', () {
      final actions = [
        UserAction(
          action: 'DELETE_USER',
          timestamp: DateTime.utc(2026, 3, 15, 10, 5),
          isSensitive: true,
        ),
      ];
      final log = _makeLog(actions: actions);
      final result = analyzer.analyze([log]);
      expect(result.first.riskLevel.isAtLeast(RiskLevel.medium), isTrue);
    });

    test('adds score for admin without MFA', () {
      final log = _makeLog(userRole: 'admin', authMethod: 'password');
      final result = analyzer.analyze([log]);
      expect(result.first.riskLevel.isAtLeast(RiskLevel.medium), isTrue);
    });

    test('admin WITH MFA gets no extra score', () {
      final log = _makeLog(userRole: 'admin', authMethod: 'mfa_totp');
      final result = analyzer.analyze([log]);
      expect(result.first.riskLevel, equals(RiskLevel.low));
    });

    test('multi-country user gets extra score', () {
      final logs = [
        _makeLog(id: 'l1', userId: 'u_traveler', country: 'US'),
        _makeLog(id: 'l2', userId: 'u_traveler', country: 'DE'),
      ];
      final result = analyzer.analyze(logs);
      // Both logs should have at least medium risk
      expect(result.every((l) => l.riskLevel.isAtLeast(RiskLevel.medium)), isTrue);
    });

    test('notes are populated for non-low risk', () {
      final log = _makeLog(ipAddress: '10.0.0.99');
      final result = analyzer.analyze([log]);
      expect(result.first.notes, isNotNull);
      expect(result.first.notes, contains('blacklisted'));
    });

    test('analyze returns same number of logs', () {
      final logs = List.generate(
        10,
        (i) => _makeLog(id: 'l_$i', userId: 'u_$i'),
      );
      final result = analyzer.analyze(logs);
      expect(result.length, equals(logs.length));
    });
  });
}
