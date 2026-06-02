import 'dart:io';
import 'dart:typed_data';

import '../models/compliance_standard.dart';
import '../models/report_format.dart';
import '../models/risk_level.dart';
import '../processors/anomaly_detector.dart';

/// The result of a [ComplianceReporter.generate] call.
///
/// Holds the raw bytes of the generated files (PDF, Excel, HTML) together
/// with rich metadata — entry counts, risk breakdown, anomaly flags,
/// generation timing, and integrity hash.
///
/// ```dart
/// final result = await reporter.generate(from: 90.days.ago);
///
/// // Save to disk
/// await result.savePdfToFile('/reports/audit.pdf');
///
/// // Stream bytes to an HTTP response
/// response.add(result.pdfBytes!);
///
/// // Human-readable summary
/// print(result);
/// ```
class ReportResult {
  // ── Generated file bytes ──────────────────────────────────────────────

  /// Raw bytes of the generated PDF file, or `null` if not generated.
  final Uint8List? pdfBytes;

  /// Raw bytes of the generated Excel (.xlsx) file, or `null` if not generated.
  final Uint8List? excelBytes;

  /// Raw bytes of the generated HTML file, or `null` if not generated.
  final Uint8List? htmlBytes;

  // ── Report identity ───────────────────────────────────────────────────

  /// Auto-generated unique ID for this report (UUID v4).
  final String reportId;

  /// The compliance format(s) that were generated.
  final ReportFormat format;

  /// The compliance standard this report was built against.
  final ComplianceStandard standard;

  // ── Time range ────────────────────────────────────────────────────────

  /// Start of the audit period.
  final DateTime from;

  /// End of the audit period.
  final DateTime to;

  /// Exact timestamp when report generation finished.
  final DateTime generatedAt;

  /// Wall-clock duration of the generation pipeline.
  final Duration generationDuration;

  // ── Counts ────────────────────────────────────────────────────────────

  /// Total number of [AccessLog] entries included in this report.
  final int totalEntries;

  /// Number of unique users in this report.
  final int uniqueUsers;

  /// Number of unique IP addresses in this report.
  final int uniqueIps;

  /// Number of failed login attempts.
  final int failedLogins;

  /// Breakdown of entries per [RiskLevel].
  final Map<RiskLevel, int> riskBreakdown;

  /// List of detected anomalies (may be empty).
  final List<AnomalyReport> anomalies;

  // ── Integrity ─────────────────────────────────────────────────────────

  /// SHA-256 hex digest of the PDF bytes (empty string if no PDF).
  final String pdfHash;

  /// SHA-256 hex digest of the Excel bytes (empty string if no Excel).
  final String excelHash;

  // ── Constructor ───────────────────────────────────────────────────────

  /// Creates a [ReportResult].
  const ReportResult({
    required this.reportId,
    this.pdfBytes,
    this.excelBytes,
    this.htmlBytes,
    required this.format,
    required this.standard,
    required this.from,
    required this.to,
    required this.generatedAt,
    required this.generationDuration,
    required this.totalEntries,
    required this.uniqueUsers,
    required this.uniqueIps,
    required this.failedLogins,
    required this.riskBreakdown,
    this.anomalies = const [],
    this.pdfHash = '',
    this.excelHash = '',
  });

  // ── Computed properties ───────────────────────────────────────────────

  /// Number of detected anomalies.
  int get anomaliesDetected => anomalies.length;

  /// `true` if the report contains any anomaly flags.
  bool get hasAnomalies => anomalies.isNotEmpty;

  /// Length of the audit period in days.
  int get periodDays => to.difference(from).inDays;

  /// PDF file size in kilobytes, or `null` if not generated.
  double? get pdfSizeKb =>
      pdfBytes != null ? pdfBytes!.lengthInBytes / 1024 : null;

  /// Excel file size in kilobytes, or `null` if not generated.
  double? get excelSizeKb =>
      excelBytes != null ? excelBytes!.lengthInBytes / 1024 : null;

  /// HTML file size in kilobytes, or `null` if not generated.
  double? get htmlSizeKb =>
      htmlBytes != null ? htmlBytes!.lengthInBytes / 1024 : null;

  /// Number of critical-risk entries.
  int get criticalCount => riskBreakdown[RiskLevel.critical] ?? 0;

  /// Number of high-risk entries.
  int get highRiskCount => riskBreakdown[RiskLevel.high] ?? 0;

  /// `true` if any critical or high-risk entries were found.
  bool get requiresImmediateAttention =>
      criticalCount > 0 || highRiskCount > 0;

  // ── File I/O ──────────────────────────────────────────────────────────

  /// Writes the PDF bytes to [path] and returns the created [File].
  ///
  /// Throws [StateError] if this result contains no PDF bytes.
  Future<File> savePdfToFile(String path) async {
    if (pdfBytes == null) {
      throw StateError(
        'This ReportResult does not contain PDF bytes. '
        'Re-run generate() with ReportFormat.pdf or ReportFormat.both.',
      );
    }
    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsBytes(pdfBytes!);
    return file;
  }

  /// Writes the Excel bytes to [path] and returns the created [File].
  ///
  /// Throws [StateError] if this result contains no Excel bytes.
  Future<File> saveExcelToFile(String path) async {
    if (excelBytes == null) {
      throw StateError(
        'This ReportResult does not contain Excel bytes. '
        'Re-run generate() with ReportFormat.excel or ReportFormat.both.',
      );
    }
    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsBytes(excelBytes!);
    return file;
  }

  /// Writes the HTML bytes to [path] and returns the created [File].
  ///
  /// Throws [StateError] if this result contains no HTML bytes.
  Future<File> saveHtmlToFile(String path) async {
    if (htmlBytes == null) {
      throw StateError(
        'This ReportResult does not contain HTML bytes. '
        'Re-run generate() with ReportFormat.html or ReportFormat.all.',
      );
    }
    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsBytes(htmlBytes!);
    return file;
  }

  // ── Serialisation ─────────────────────────────────────────────────────

  /// Returns a JSON-serialisable summary (without the raw bytes).
  Map<String, dynamic> toSummaryJson() => {
        'reportId': reportId,
        'format': format.name,
        'standard': standard.name,
        'from': from.toIso8601String(),
        'to': to.toIso8601String(),
        'periodDays': periodDays,
        'generatedAt': generatedAt.toIso8601String(),
        'generationMs': generationDuration.inMilliseconds,
        'totalEntries': totalEntries,
        'uniqueUsers': uniqueUsers,
        'uniqueIps': uniqueIps,
        'failedLogins': failedLogins,
        'anomaliesDetected': anomaliesDetected,
        'requiresImmediateAttention': requiresImmediateAttention,
        'riskBreakdown': {
          for (final e in riskBreakdown.entries) e.key.name: e.value,
        },
        'pdfSizeKb': pdfSizeKb?.toStringAsFixed(2),
        'excelSizeKb': excelSizeKb?.toStringAsFixed(2),
        'htmlSizeKb': htmlSizeKb?.toStringAsFixed(2),
        'pdfHash': pdfHash,
        'excelHash': excelHash,
      };

  @override
  String toString() => '''
ComplianceReport {
  reportId       : $reportId
  standard       : ${standard.name.toUpperCase()}
  period         : ${from.toIso8601String().substring(0, 10)} → ${to.toIso8601String().substring(0, 10)} ($periodDays days)
  totalEntries   : $totalEntries
  uniqueUsers    : $uniqueUsers
  uniqueIps      : $uniqueIps
  failedLogins   : $failedLogins
  anomalies      : $anomaliesDetected
  riskBreakdown  : ${riskBreakdown.entries.map((e) => '${e.key.name}=${e.value}').join(', ')}
  generatedAt    : ${generatedAt.toIso8601String()}
  generationTime : ${generationDuration.inMilliseconds}ms
  pdfSize        : ${pdfSizeKb?.toStringAsFixed(2) ?? 'N/A'} KB
  excelSize      : ${excelSizeKb?.toStringAsFixed(2) ?? 'N/A'} KB
  htmlSize       : ${htmlSizeKb?.toStringAsFixed(2) ?? 'N/A'} KB
  pdfHash        : ${pdfHash.isEmpty ? 'N/A' : pdfHash}
  excelHash      : ${excelHash.isEmpty ? 'N/A' : excelHash}
}''';
}
