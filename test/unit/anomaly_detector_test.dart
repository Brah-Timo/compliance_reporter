import 'package:test/test.dart';

import 'package:compliance_reporter/compliance_reporter.dart';

AccessLog _log({
  required String id,
  required String userId,
  required DateTime loginAt,
  DateTime? logoutAt,
  String ipAddress = '1.2.3.4',
  String? country,
  LoginStatus status = LoginStatus.success,
  String? userRole,
  List<UserAction> actions = const [],
}) =>
    AccessLog(
      id: id,
      userId: userId,
      ipAddress: ipAddress,
      loginAt: loginAt,
      logoutAt: logoutAt,
      country: country,
      status: status,
      userRole: userRole,
      actions: actions,
    );

void main() {
  group('AnomalyDetector', () {
    late AnomalyDetector detector;

    setUp(() {
      detector = AnomalyDetector(
        impossibleTravelMinutes: 60,
        bruteForceThreshold: 3,
        bruteForceWindowMinutes: 5,
        credentialStuffingThreshold: 3,
        exfiltrationActionThreshold: 5,
      );
    });

    // ── Impossible travel ─────────────────────────────────────────────────

    test('detects impossible travel when same user appears in two countries within threshold', () {
      final base = DateTime.utc(2026, 3, 15, 10, 0);
      final logs = [
        _log(id: 'l1', userId: 'u1', loginAt: base,                     country: 'US'),
        _log(id: 'l2', userId: 'u1', loginAt: base.add(30.minutes), country: 'GB'),
      ];
      final anomalies = detector.detect(logs);
      expect(anomalies.any((a) => a.type == AnomalyType.impossibleTravel), isTrue);
    });

    test('does NOT flag travel beyond the time threshold', () {
      final base = DateTime.utc(2026, 3, 15, 10, 0);
      final logs = [
        _log(id: 'l1', userId: 'u1', loginAt: base,                         country: 'US'),
        _log(id: 'l2', userId: 'u1', loginAt: base.add(120.minutes), country: 'GB'),
      ];
      final anomalies = detector.detect(logs);
      expect(anomalies.any((a) => a.type == AnomalyType.impossibleTravel), isFalse);
    });

    test('does NOT flag same country logins', () {
      final base = DateTime.utc(2026, 3, 15, 10, 0);
      final logs = [
        _log(id: 'l1', userId: 'u1', loginAt: base,                     country: 'US'),
        _log(id: 'l2', userId: 'u1', loginAt: base.add(10.minutes), country: 'US'),
      ];
      final anomalies = detector.detect(logs);
      expect(anomalies.any((a) => a.type == AnomalyType.impossibleTravel), isFalse);
    });

    // ── Brute force ───────────────────────────────────────────────────────

    test('detects brute force when N failures within window', () {
      final base = DateTime.utc(2026, 3, 15, 2, 0);
      final logs = List.generate(
        4,
        (i) => _log(
          id: 'bf_$i',
          userId: 'victim',
          loginAt: base.add(Duration(minutes: i)),
          status: LoginStatus.failed,
        ),
      );
      final anomalies = detector.detect(logs);
      expect(anomalies.any((a) => a.type == AnomalyType.bruteForce), isTrue);
    });

    test('does NOT flag brute force below threshold', () {
      final base = DateTime.utc(2026, 3, 15, 2, 0);
      final logs = [
        _log(id: 'bf_1', userId: 'victim', loginAt: base,                      status: LoginStatus.failed),
        _log(id: 'bf_2', userId: 'victim', loginAt: base.add(1.minutes), status: LoginStatus.failed),
      ];
      final anomalies = detector.detect(logs);
      expect(anomalies.any((a) => a.type == AnomalyType.bruteForce), isFalse);
    });

    // ── Credential stuffing ───────────────────────────────────────────────

    test('detects credential stuffing from same IP', () {
      final base = DateTime.utc(2026, 3, 15, 5, 0);
      final logs = List.generate(
        4,
        (i) => _log(
          id: 'cs_$i',
          userId: 'user_$i',
          loginAt: base.add(Duration(minutes: i)),
          ipAddress: '99.99.99.99',
          status: LoginStatus.failed,
        ),
      );
      final anomalies = detector.detect(logs);
      expect(anomalies.any((a) => a.type == AnomalyType.credentialStuffing), isTrue);
    });

    // ── Data exfiltration ─────────────────────────────────────────────────

    test('detects exfiltration when export action count exceeds threshold', () {
      final base = DateTime.utc(2026, 3, 15, 9, 0);
      final actions = List.generate(
        6,
        (i) => UserAction(
          action: 'EXPORT_CSV',
          timestamp: base.add(Duration(minutes: i)),
          isSensitive: true,
        ),
      );
      final logs = [
        _log(id: 'exfil_1', userId: 'u_bad', loginAt: base, actions: actions),
      ];
      final anomalies = detector.detect(logs);
      expect(anomalies.any((a) => a.type == AnomalyType.dataExfiltration), isTrue);
    });

    // ── Off-hours admin ───────────────────────────────────────────────────

    test('detects off-hours admin access', () {
      final logs = [
        _log(
          id: 'oha_1',
          userId: 'admin_user',
          loginAt: DateTime.utc(2026, 3, 15, 3, 0),
          userRole: 'admin',
        ),
      ];
      final anomalies = detector.detect(logs);
      expect(anomalies.any((a) => a.type == AnomalyType.offHoursAdminAccess), isTrue);
    });

    // ── Empty input ───────────────────────────────────────────────────────

    test('returns empty list for empty log input', () {
      expect(detector.detect([]), isEmpty);
    });

    test('anomalies are sorted by severity (critical first)', () {
      final base = DateTime.utc(2026, 3, 15, 3, 0);
      final logs = [
        // Off-hours admin (high)
        _log(id: 'oha', userId: 'admin', loginAt: base, userRole: 'admin'),
        // Brute force (critical)
        ...List.generate(
          4,
          (i) => _log(
            id: 'bf_$i',
            userId: 'victim',
            loginAt: base.add(Duration(minutes: i)),
            status: LoginStatus.failed,
          ),
        ),
      ];
      final anomalies = detector.detect(logs);
      if (anomalies.length >= 2) {
        expect(
          anomalies.first.severity.index >=
              anomalies.last.severity.index,
          isTrue,
        );
      }
    });
  });
}
