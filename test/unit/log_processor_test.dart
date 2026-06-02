import 'package:test/test.dart';

import 'package:compliance_reporter/compliance_reporter.dart';

AccessLog _makeLog({
  required String id,
  String userId = 'u_01',
  String ipAddress = '1.2.3.4',
  String? country,
  String? userRole,
  LoginStatus status = LoginStatus.success,
  RiskLevel riskLevel = RiskLevel.low,
  bool hasAnomaly = false,
  DateTime? loginAt,
}) =>
    AccessLog(
      id: id,
      userId: userId,
      ipAddress: ipAddress,
      country: country,
      userRole: userRole,
      status: status,
      riskLevel: riskLevel,
      hasAnomaly: hasAnomaly,
      loginAt: loginAt ?? DateTime(2026, 3, 15, 10),
    );

void main() {
  group('LogProcessor', () {
    test('removes duplicate IDs', () {
      final logs = [
        _makeLog(id: 'same'),
        _makeLog(id: 'same'), // duplicate
        _makeLog(id: 'diff'),
      ];
      final processor = LogProcessor(
        anonymize: false,
        standard: ComplianceStandard.generic,
        config: const ReportConfig(),
      );
      final result = processor.process(logs);
      expect(result.length, equals(2));
      expect(result.map((l) => l.id).toSet().length, equals(2));
    });

    test('filters by userId whitelist', () {
      final logs = [
        _makeLog(id: '1', userId: 'alice'),
        _makeLog(id: '2', userId: 'bob'),
        _makeLog(id: '3', userId: 'charlie'),
      ];
      final processor = LogProcessor(
        anonymize: false,
        standard: ComplianceStandard.generic,
        config: ReportConfig(filterByUserIds: {'alice', 'bob'}),
      );
      final result = processor.process(logs);
      expect(result.length, equals(2));
      expect(result.every((l) => l.userId == 'alice' || l.userId == 'bob'), isTrue);
    });

    test('filters by IP whitelist', () {
      final logs = [
        _makeLog(id: '1', ipAddress: '1.1.1.1'),
        _makeLog(id: '2', ipAddress: '2.2.2.2'),
      ];
      final processor = LogProcessor(
        anonymize: false,
        standard: ComplianceStandard.generic,
        config: ReportConfig(filterByIpAddresses: {'1.1.1.1'}),
      );
      final result = processor.process(logs);
      expect(result.length, equals(1));
      expect(result.first.ipAddress, equals('1.1.1.1'));
    });

    test('excludes blacklisted IPs', () {
      final logs = [
        _makeLog(id: '1', ipAddress: '1.1.1.1'),
        _makeLog(id: '2', ipAddress: '99.99.99.99'),
      ];
      final processor = LogProcessor(
        anonymize: false,
        standard: ComplianceStandard.generic,
        config: ReportConfig(excludeIpAddresses: {'99.99.99.99'}),
      );
      final result = processor.process(logs);
      expect(result.length, equals(1));
      expect(result.first.ipAddress, equals('1.1.1.1'));
    });

    test('showFailuresOnly removes successful logins', () {
      final logs = [
        _makeLog(id: '1', status: LoginStatus.success),
        _makeLog(id: '2', status: LoginStatus.failed),
        _makeLog(id: '3', status: LoginStatus.blocked),
      ];
      final processor = LogProcessor(
        anonymize: false,
        standard: ComplianceStandard.generic,
        config: const ReportConfig(showFailuresOnly: true),
      );
      final result = processor.process(logs);
      expect(result.length, equals(2));
      expect(result.every((l) => l.status != LoginStatus.success), isTrue);
    });

    test('showAnomaliesOnly keeps only flagged entries', () {
      final logs = [
        _makeLog(id: '1', hasAnomaly: false),
        _makeLog(id: '2', hasAnomaly: true),
        _makeLog(id: '3', hasAnomaly: true),
      ];
      final processor = LogProcessor(
        anonymize: false,
        standard: ComplianceStandard.generic,
        config: const ReportConfig(showAnomaliesOnly: true),
      );
      final result = processor.process(logs);
      expect(result.length, equals(2));
    });

    test('maxTotalEntries limits output', () {
      final logs = List.generate(
        20,
        (i) => _makeLog(id: 'l_$i', loginAt: DateTime(2026, 3, 15, 10, i)),
      );
      final processor = LogProcessor(
        anonymize: false,
        standard: ComplianceStandard.generic,
        config: const ReportConfig(maxTotalEntries: 5),
      );
      final result = processor.process(logs);
      expect(result.length, lessThanOrEqualTo(5));
    });

    test('anonymise masks email under GDPR', () {
      final logs = [
        AccessLog(
          id: 'a1',
          userId: 'user123',
          userEmail: 'alice@example.com',
          ipAddress: '1.2.3.4',
          loginAt: DateTime(2026, 3, 15),
        ),
      ];
      final processor = LogProcessor(
        anonymize: true,
        standard: ComplianceStandard.gdpr,
        config: const ReportConfig(),
      );
      final result = processor.process(logs);
      expect(result.first.userEmail, isNot('alice@example.com'));
      expect(result.first.userEmail, contains('@example.com'));
    });
  });
}
