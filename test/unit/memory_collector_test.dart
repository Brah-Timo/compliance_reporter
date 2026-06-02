import 'package:test/test.dart';

import 'package:compliance_reporter/compliance_reporter.dart';

List<AccessLog> _generateLogs(int count) => List.generate(
      count,
      (i) => AccessLog(
        id: 'log_$i',
        userId: 'user_${i % 5}',
        ipAddress: '192.168.${i % 10}.${i % 20}',
        loginAt: DateTime(2026, 1, 1).add(Duration(days: i)),
        country: ['US', 'GB', 'DE', 'AE', 'AU'][i % 5],
      ),
    );

void main() {
  group('MemoryLogCollector', () {
    test('collects all logs within date range', () async {
      final logs = _generateLogs(10);
      final collector = MemoryLogCollector(logs: logs);

      final result = await collector.collect(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 15),
      );
      expect(result.isNotEmpty, isTrue);
      for (final log in result) {
        expect(
          log.loginAt.isAfter(DateTime(2025, 12, 31)) &&
              log.loginAt.isBefore(DateTime(2026, 1, 16)),
          isTrue,
        );
      }
    });

    test('returns empty list when no logs in range', () async {
      final logs = _generateLogs(5);
      final collector = MemoryLogCollector(logs: logs);

      final result = await collector.collect(
        from: DateTime(2025, 1, 1),
        to: DateTime(2025, 1, 31),
      );
      expect(result, isEmpty);
    });

    test('filters by userId', () async {
      final logs = _generateLogs(10);
      final collector = MemoryLogCollector(logs: logs);

      final result = await collector.collect(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
        userId: 'user_0',
      );
      expect(result.every((l) => l.userId == 'user_0'), isTrue);
    });

    test('filters by ipAddress', () async {
      final logs = _generateLogs(10);
      final collector = MemoryLogCollector(logs: logs);
      final targetIp = logs.first.ipAddress;

      final result = await collector.collect(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
        ipAddress: targetIp,
      );
      expect(result.every((l) => l.ipAddress == targetIp), isTrue);
    });

    test('respects limit parameter', () async {
      final logs = _generateLogs(20);
      final collector = MemoryLogCollector(logs: logs);

      final result = await collector.collect(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
        limit: 5,
      );
      expect(result.length, lessThanOrEqualTo(5));
    });

    test('respects offset parameter', () async {
      final logs = _generateLogs(10);
      final collector = MemoryLogCollector(logs: logs);

      final allResults = await collector.collect(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
      );
      final offsetResults = await collector.collect(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
        offset: 3,
      );
      expect(offsetResults.length, equals(allResults.length - 3));
    });

    test('results are sorted newest first', () async {
      final logs = _generateLogs(5);
      final collector = MemoryLogCollector(logs: logs);

      final result = await collector.collect(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
      );
      for (var i = 1; i < result.length; i++) {
        expect(
          result[i - 1].loginAt.isAfter(result[i].loginAt) ||
              result[i - 1].loginAt.isAtSameMomentAs(result[i].loginAt),
          isTrue,
        );
      }
    });

    test('count returns correct number', () async {
      final logs = _generateLogs(10);
      final collector = MemoryLogCollector(logs: logs);

      final count = await collector.count(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
      );
      expect(count, greaterThan(0));
      expect(count, lessThanOrEqualTo(10));
    });

    test('isAvailable always returns true', () async {
      final collector = MemoryLogCollector(logs: []);
      expect(await collector.isAvailable(), isTrue);
    });

    test('length returns backing list size', () {
      final logs = _generateLogs(7);
      final collector = MemoryLogCollector(logs: logs);
      expect(collector.length, equals(7));
    });
  });
}
