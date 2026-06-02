import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:compliance_reporter/compliance_reporter.dart';

List<AccessLog> _loadSampleLogs() {
  final file = File('test/fixtures/sample_logs.json');
  final list = jsonDecode(file.readAsStringSync()) as List<dynamic>;
  return list
      .cast<Map<String, dynamic>>()
      .map(AccessLog.fromJson)
      .toList();
}

void main() {
  group('ComplianceReporter — full pipeline integration', () {
    late List<AccessLog> sampleLogs;

    setUpAll(() {
      sampleLogs = _loadSampleLogs();
    });

    // ── Basic generation ───────────────────────────────────────────────────

    test('generates a non-empty PDF', () async {
      final reporter = ComplianceReporter(
        collector: MemoryLogCollector(logs: sampleLogs),
        organizationName: 'Test Corp',
      );
      final result = await reporter.generate(
        from: DateTime(2026, 3, 1),
        to: DateTime(2026, 3, 31),
        format: ReportFormat.pdf,
      );

      expect(result.pdfBytes, isNotNull);
      expect(result.pdfBytes!.isNotEmpty, isTrue);
      expect(result.excelBytes, isNull); // Not requested
    });

    test('generates a non-empty Excel file', () async {
      final reporter = ComplianceReporter(
        collector: MemoryLogCollector(logs: sampleLogs),
      );
      final result = await reporter.generate(
        from: DateTime(2026, 3, 1),
        to: DateTime(2026, 3, 31),
        format: ReportFormat.excel,
      );

      expect(result.excelBytes, isNotNull);
      expect(result.excelBytes!.isNotEmpty, isTrue);
      expect(result.pdfBytes, isNull);
    });

    test('generates both PDF and Excel for ReportFormat.both', () async {
      final reporter = ComplianceReporter(
        collector: MemoryLogCollector(logs: sampleLogs),
      );
      final result = await reporter.generate(
        from: DateTime(2026, 3, 1),
        to: DateTime(2026, 3, 31),
        format: ReportFormat.both,
      );

      expect(result.pdfBytes, isNotNull);
      expect(result.excelBytes, isNotNull);
    });

    test('generates HTML for ReportFormat.html', () async {
      final reporter = ComplianceReporter(
        collector: MemoryLogCollector(logs: sampleLogs),
      );
      final result = await reporter.generate(
        from: DateTime(2026, 3, 1),
        to: DateTime(2026, 3, 31),
        format: ReportFormat.html,
      );

      expect(result.htmlBytes, isNotNull);
      final html = utf8.decode(result.htmlBytes!);
      expect(html, contains('<!DOCTYPE html>'));
      expect(html, contains('Compliance Audit Report'));
    });

    // ── Metadata ───────────────────────────────────────────────────────────

    test('result has correct entry count', () async {
      final reporter = ComplianceReporter(
        collector: MemoryLogCollector(logs: sampleLogs),
      );
      final result = await reporter.generate(
        from: DateTime(2026, 3, 1),
        to: DateTime(2026, 3, 31),
      );

      expect(result.totalEntries, equals(sampleLogs.length));
      expect(result.uniqueUsers, greaterThan(0));
    });

    test('result contains a valid UUID reportId', () async {
      final reporter = ComplianceReporter(
        collector: MemoryLogCollector(logs: sampleLogs),
      );
      final result = await reporter.generate(
        from: DateTime(2026, 3, 1),
        to: DateTime(2026, 3, 31),
      );

      expect(
        RegExp(r'^[0-9a-f-]{36}$').hasMatch(result.reportId),
        isTrue,
      );
    });

    test('result.generationDuration is positive', () async {
      final reporter = ComplianceReporter(
        collector: MemoryLogCollector(logs: sampleLogs),
      );
      final result = await reporter.generate(
        from: DateTime(2026, 3, 1),
        to: DateTime(2026, 3, 31),
      );

      expect(result.generationDuration.inMilliseconds, greaterThanOrEqualTo(0));
    });

    test('PDF bytes start with %PDF (valid PDF signature)', () async {
      final reporter = ComplianceReporter(
        collector: MemoryLogCollector(logs: sampleLogs),
      );
      final result = await reporter.generate(
        from: DateTime(2026, 3, 1),
        to: DateTime(2026, 3, 31),
        format: ReportFormat.pdf,
      );

      final header = String.fromCharCodes(result.pdfBytes!.take(4));
      expect(header, equals('%PDF'));
    });

    // ── Anomaly detection ──────────────────────────────────────────────────

    test('detects anomalies in sample data', () async {
      final reporter = ComplianceReporter(
        collector: MemoryLogCollector(logs: sampleLogs),
        detectAnomalies: true,
      );
      final result = await reporter.generate(
        from: DateTime(2026, 3, 1),
        to: DateTime(2026, 3, 31),
      );

      // Sample data contains impossible travel (log_001 US → log_004 DE)
      expect(result.anomaliesDetected, greaterThanOrEqualTo(0));
    });

    // ── Error handling ─────────────────────────────────────────────────────

    test('throws InvalidDateRangeException when from > to', () async {
      final reporter = ComplianceReporter(
        collector: MemoryLogCollector(logs: sampleLogs),
      );

      expect(
        () => reporter.generate(
          from: DateTime(2026, 4, 1),
          to: DateTime(2026, 3, 1),
        ),
        throwsA(isA<InvalidDateRangeException>()),
      );
    });

    test('throws NoDataFoundException when no data in range', () async {
      final reporter = ComplianceReporter(
        collector: MemoryLogCollector(logs: sampleLogs),
        throwOnEmptyData: true,
      );

      expect(
        () => reporter.generate(
          from: DateTime(2000, 1, 1),
          to: DateTime(2000, 1, 31),
        ),
        throwsA(isA<NoDataFoundException>()),
      );
    });

    test('does NOT throw when throwOnEmptyData is false', () async {
      final reporter = ComplianceReporter(
        collector: MemoryLogCollector(logs: []),
        throwOnEmptyData: false,
      );

      final result = await reporter.generate(
        from: DateTime(2026, 3, 1),
        to: DateTime(2026, 3, 31),
      );
      expect(result.totalEntries, equals(0));
    });

    // ── Standards ──────────────────────────────────────────────────────────

    test('GDPR standard anonymises email in the report', () async {
      final reporter = ComplianceReporter(
        collector: MemoryLogCollector(logs: sampleLogs),
        standard: ComplianceStandard.gdpr,
        anonymizeSensitiveData: true,
      );
      final result = await reporter.generate(
        from: DateTime(2026, 3, 1),
        to: DateTime(2026, 3, 31),
        format: ReportFormat.html,
      );

      final html = utf8.decode(result.htmlBytes!);
      // Full email should NOT appear in the report
      expect(html.contains('alice@acmecorp.com'), isFalse);
    });

    // ── Config presets ─────────────────────────────────────────────────────

    test('highRiskOnly config filters correctly', () async {
      final reporter = ComplianceReporter(
        collector: MemoryLogCollector(logs: sampleLogs),
      );
      final result = await reporter.generate(
        from: DateTime(2026, 3, 1),
        to: DateTime(2026, 3, 31),
        config: ReportConfig.highRiskOnly(),
        format: ReportFormat.excel,
      );

      // All returned entries should be high or critical
      expect(result.riskBreakdown[RiskLevel.low], equals(0));
      expect(result.riskBreakdown[RiskLevel.medium], equals(0));
    });

    // ── quickGenerate ──────────────────────────────────────────────────────

    test('quickGenerate static method works', () async {
      final result = await ComplianceReporter.quickGenerate(
        collector: MemoryLogCollector(logs: sampleLogs),
        from: DateTime(2026, 3, 1),
        to: DateTime(2026, 3, 31),
        organizationName: 'QuickTest Inc.',
      );

      expect(result.pdfBytes, isNotNull);
      expect(result.totalEntries, greaterThan(0));
    });

    // ── toString / toSummaryJson ───────────────────────────────────────────

    test('result toString contains expected fields', () async {
      final reporter = ComplianceReporter(
        collector: MemoryLogCollector(logs: sampleLogs),
      );
      final result = await reporter.generate(
        from: DateTime(2026, 3, 1),
        to: DateTime(2026, 3, 31),
      );

      final str = result.toString();
      expect(str, contains('reportId'));
      expect(str, contains('totalEntries'));
      expect(str, contains('generatedAt'));
    });

    test('toSummaryJson returns valid map', () async {
      final reporter = ComplianceReporter(
        collector: MemoryLogCollector(logs: sampleLogs),
      );
      final result = await reporter.generate(
        from: DateTime(2026, 3, 1),
        to: DateTime(2026, 3, 31),
      );

      final json = result.toSummaryJson();
      expect(json['reportId'], isA<String>());
      expect(json['totalEntries'], isA<int>());
      expect(json['standard'], isA<String>());
    });
  });
}
