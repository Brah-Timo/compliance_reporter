import 'package:test/test.dart';

import 'package:compliance_reporter/compliance_reporter.dart';

void main() {
  group('IntDurationExtensions', () {
    test('days creates correct Duration', () {
      expect(90.days, equals(const Duration(days: 90)));
      expect(1.days, equals(const Duration(days: 1)));
      expect(0.days, equals(Duration.zero));
    });

    test('hours creates correct Duration', () {
      expect(24.hours, equals(const Duration(hours: 24)));
    });

    test('minutes creates correct Duration', () {
      expect(60.minutes, equals(const Duration(minutes: 60)));
    });

    test('seconds creates correct Duration', () {
      expect(30.seconds, equals(const Duration(seconds: 30)));
    });

    test('weeks creates correct Duration (7 days each)', () {
      expect(2.weeks, equals(const Duration(days: 14)));
    });

    test('months creates approximate Duration (30 days each)', () {
      expect(3.months, equals(const Duration(days: 90)));
    });

    test('years creates approximate Duration (365 days each)', () {
      expect(1.years, equals(const Duration(days: 365)));
    });
  });

  group('DurationAgoExtensions', () {
    test('ago returns a date in the past', () {
      final before = DateTime.now();
      final result = 1.days.ago;
      final after = DateTime.now();

      expect(result.isBefore(before), isTrue);
      expect(
        result.isAfter(after.subtract(const Duration(days: 1, seconds: 1))),
        isTrue,
      );
    });

    test('fromNow returns a date in the future', () {
      final result = 1.days.fromNow;
      expect(result.isAfter(DateTime.now()), isTrue);
    });

    test('readable formats correctly', () {
      expect(const Duration(hours: 2, minutes: 15, seconds: 3).readable, '2h 15m 3s');
      expect(const Duration(minutes: 5, seconds: 30).readable, '5m 30s');
      expect(const Duration(seconds: 45).readable, '45s');
    });
  });

  group('DateTimeComplianceExtensions', () {
    final date = DateTime(2026, 6, 15, 14, 30, 0);

    test('operator - subtracts duration', () {
      expect(date - const Duration(days: 5), equals(DateTime(2026, 6, 10, 14, 30, 0)));
    });

    test('operator + adds duration', () {
      expect(date + const Duration(days: 5), equals(DateTime(2026, 6, 20, 14, 30, 0)));
    });

    test('startOfDay returns midnight', () {
      expect(date.startOfDay, equals(DateTime(2026, 6, 15)));
    });

    test('endOfDay returns 23:59:59.999', () {
      expect(date.endOfDay, equals(DateTime(2026, 6, 15, 23, 59, 59, 999)));
    });

    test('startOfMonth returns first day', () {
      expect(date.startOfMonth, equals(DateTime(2026, 6, 1)));
    });

    test('isBetween returns true when in range', () {
      final start = DateTime(2026, 6, 1);
      final end = DateTime(2026, 6, 30);
      expect(date.isBetween(start, end), isTrue);
    });

    test('isBetween returns false when outside range', () {
      final start = DateTime(2026, 7, 1);
      final end = DateTime(2026, 7, 31);
      expect(date.isBetween(start, end), isFalse);
    });

    test('daysUntil returns positive value for future date', () {
      final future = DateTime(2026, 7, 15);
      expect(date.daysUntil(future), equals(30));
    });
  });
}
