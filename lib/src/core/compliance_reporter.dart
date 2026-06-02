import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

import '../collectors/base_log_collector.dart';
import '../exceptions/compliance_exception.dart';
import '../exceptions/invalid_date_range_exception.dart';
import '../exceptions/no_data_found_exception.dart';
import '../generators/excel_generator.dart';
import '../generators/html_generator.dart';
import '../generators/pdf_generator.dart';
import '../models/access_log.dart';
import '../models/compliance_standard.dart';
import '../models/report_format.dart';
import '../models/risk_level.dart';
import '../processors/anomaly_detector.dart';
import '../processors/log_processor.dart';
import '../processors/risk_analyzer.dart';
import '../security/report_signer.dart';
import '../security/watermark_service.dart';
import '../templates/base_template.dart';
import '../templates/corporate_template.dart';
import '../templates/gdpr_template.dart';
import '../templates/soc2_template.dart';
import 'report_config.dart';
import 'report_result.dart';

/// The main entry point for the `compliance_reporter` package.
///
/// Orchestrates the full report-generation pipeline:
/// collect → process → analyze → detect anomalies → generate → secure.
///
/// ## Basic usage
///
/// ```dart
/// final reporter = ComplianceReporter(
///   collector: MemoryLogCollector(logs: myLogs),
///   organizationName: 'Acme Corp',
/// );
///
/// final result = await reporter.generate(
///   from: DateTime.now() - 90.days,
///   format: ReportFormat.pdf,
/// );
///
/// await result.savePdfToFile('/reports/audit.pdf');
/// ```
///
/// ## Advanced usage
///
/// ```dart
/// final reporter = ComplianceReporter(
///   collector: HttpLogCollector(baseUrl: 'https://api.app.com/logs'),
///   standard: ComplianceStandard.gdpr,
///   enableDigitalSignature: true,
///   enableWatermark: true,
///   anonymizeSensitiveData: true,
///   detectAnomalies: true,
///   organizationName: 'FinTech Ltd.',
/// );
///
/// final result = await reporter.generate(
///   from: 3.months.ago,
///   format: ReportFormat.both,
///   config: ReportConfig.soc2Audit(),
/// );
/// ```
class ComplianceReporter {
  static final _log = Logger('ComplianceReporter');
  static const _uuid = Uuid();

  // ── Configuration ─────────────────────────────────────────────────────

  /// The data source that provides [AccessLog] entries.
  final BaseLogCollector collector;

  /// Optional custom template; defaults to [CorporateTemplate].
  final BaseTemplate? template;

  /// The compliance standard driving field selection and anonymisation.
  final ComplianceStandard standard;

  /// When `true`, the PDF is signed using a HMAC-SHA256 trailer record.
  final bool enableDigitalSignature;

  /// When `true`, a "CONFIDENTIAL" watermark is stamped on every PDF page.
  final bool enableWatermark;

  /// Your organisation's display name, printed on the report header.
  final String? organizationName;

  /// Path (or URL) to your organisation's logo image (PNG / JPEG).
  final String? organizationLogo;

  /// When `true`, personal data (name, email, city, user-agent) is masked
  /// before report generation. Automatically `true` for
  /// [ComplianceStandard.gdpr] and [ComplianceStandard.hipaa].
  final bool anonymizeSensitiveData;

  /// When `true`, the [AnomalyDetector] is run and its findings are included
  /// in a dedicated section of the report.
  final bool detectAnomalies;

  /// Optional list of IP addresses to flag as black-listed during risk scoring.
  final List<String> blacklistedIps;

  /// Whether to throw [NoDataFoundException] when the collector returns zero
  /// entries. Defaults to `true`. Set to `false` to generate an empty report.
  final bool throwOnEmptyData;

  // ── Constructor ───────────────────────────────────────────────────────

  /// Creates a [ComplianceReporter].
  const ComplianceReporter({
    required this.collector,
    this.template,
    this.standard = ComplianceStandard.generic,
    this.enableDigitalSignature = false,
    this.enableWatermark = true,
    this.organizationName,
    this.organizationLogo,
    this.anonymizeSensitiveData = false,
    this.detectAnomalies = true,
    this.blacklistedIps = const [],
    this.throwOnEmptyData = true,
  });

  // ── Public API ────────────────────────────────────────────────────────

  /// Generates a compliance report for the given time range.
  ///
  /// **Parameters**
  /// - [from]   Start of the audit period (required).
  /// - [to]     End of the audit period (defaults to `DateTime.now()`).
  /// - [format] Output format: pdf / excel / html / both / all.
  /// - [config] Optional fine-grained configuration.
  ///
  /// **Returns** a [ReportResult] containing bytes and metadata.
  ///
  /// **Throws**
  /// - [InvalidDateRangeException] if `from` is after `to`, or the range
  ///   exceeds 10 years.
  /// - [NoDataFoundException] if the collector returns zero entries and
  ///   [throwOnEmptyData] is `true`.
  /// - [ComplianceException] on unexpected pipeline failures.
  Future<ReportResult> generate({
    required DateTime from,
    DateTime? to,
    ReportFormat format = ReportFormat.pdf,
    ReportConfig? config,
  }) async {
    final stopwatch = Stopwatch()..start();
    final effectiveTo = to ?? DateTime.now();
    final effectiveConfig = config ?? const ReportConfig();

    _log.info(
      'Starting report generation | '
      'standard=${standard.name} format=${format.name} '
      'from=${from.toIso8601String()} to=${effectiveTo.toIso8601String()}',
    );

    // ── Step 1: Validate date range ──────────────────────────────────────
    _validateDateRange(from, effectiveTo);

    // ── Step 2: Collect raw logs ─────────────────────────────────────────
    _log.fine('Collecting logs from ${collector.runtimeType}...');
    final rawLogs = await collector.collect(from: from, to: effectiveTo);
    _log.fine('Collected ${rawLogs.length} raw entries.');

    if (rawLogs.isEmpty && throwOnEmptyData) {
      throw NoDataFoundException(
        'No access log entries found between '
        '${from.toIso8601String()} and ${effectiveTo.toIso8601String()}. '
        'Verify your collector source or adjust the date range.',
      );
    }

    // ── Step 3: Process & filter ─────────────────────────────────────────
    final effectiveStandard =
        effectiveConfig.overrideStandard ?? standard;
    final shouldAnonymize = anonymizeSensitiveData ||
        effectiveStandard == ComplianceStandard.gdpr ||
        effectiveStandard == ComplianceStandard.hipaa;

    final processor = LogProcessor(
      anonymize: shouldAnonymize,
      standard: effectiveStandard,
      config: effectiveConfig,
    );
    final processedLogs = processor.process(rawLogs);
    _log.fine(
      'After processing/filtering: ${processedLogs.length} entries.',
    );

    // ── Step 4: Risk analysis ────────────────────────────────────────────
    final riskAnalyzer = RiskAnalyzer(
      standard: effectiveStandard,
      blacklistedIps: blacklistedIps,
    );
    final analyzedLogs = riskAnalyzer.analyze(processedLogs);

    // ── Step 5: Anomaly detection ────────────────────────────────────────
    final anomalies = detectAnomalies
        ? AnomalyDetector().detect(analyzedLogs)
        : <AnomalyReport>[];
    if (anomalies.isNotEmpty) {
      _log.warning(
        '${anomalies.length} anomalies detected — '
        'see report anomaly section for details.',
      );
    }

    // ── Step 6: Resolve template ─────────────────────────────────────────
    final effectiveTemplate = _resolveTemplate(effectiveStandard);

    // ── Step 7: Generate files ───────────────────────────────────────────
    Uint8List? pdfBytes;
    Uint8List? excelBytes;
    Uint8List? htmlBytes;

    if (_needsPdf(format)) {
      _log.fine('Generating PDF...');
      pdfBytes = await PdfGenerator(
        template: effectiveTemplate,
        standard: effectiveStandard,
        config: effectiveConfig,
      ).generate(
        logs: analyzedLogs,
        from: from,
        to: effectiveTo,
        anomalies: anomalies,
      );

      if (enableWatermark) {
        pdfBytes = await WatermarkService.apply(
          pdfBytes,
          text: 'CONFIDENTIAL — ${organizationName ?? ""}',
        );
      }
      if (enableDigitalSignature) {
        pdfBytes = await ReportSigner.sign(pdfBytes);
      }
      _log.fine(
        'PDF generated: ${(pdfBytes.lengthInBytes / 1024).toStringAsFixed(1)} KB',
      );
    }

    if (_needsExcel(format)) {
      _log.fine('Generating Excel...');
      excelBytes = await ExcelGenerator(
        standard: effectiveStandard,
        organizationName: organizationName ?? 'Organization',
      ).generate(
        logs: analyzedLogs,
        from: from,
        to: effectiveTo,
        anomalies: anomalies,
        config: effectiveConfig,
      );
      _log.fine(
        'Excel generated: ${(excelBytes.lengthInBytes / 1024).toStringAsFixed(1)} KB',
      );
    }

    if (_needsHtml(format)) {
      _log.fine('Generating HTML...');
      htmlBytes = await HtmlGenerator(
        organizationName: organizationName ?? 'Organization',
        standard: effectiveStandard,
      ).generate(
        logs: analyzedLogs,
        from: from,
        to: effectiveTo,
        anomalies: anomalies,
        config: effectiveConfig,
      );
    }

    // ── Step 8: Compute integrity hashes ────────────────────────────────
    final pdfHash = pdfBytes != null ? _sha256hex(pdfBytes) : '';
    final excelHash = excelBytes != null ? _sha256hex(excelBytes) : '';

    // ── Step 9: Build stats ──────────────────────────────────────────────
    final uniqueUsers = analyzedLogs.map((l) => l.userId).toSet().length;
    final uniqueIps = analyzedLogs.map((l) => l.ipAddress).toSet().length;
    final failedLogins = analyzedLogs
        .where((l) => l.status == LoginStatus.failed)
        .length;
    final riskBreakdown = <RiskLevel, int>{};
    for (final level in RiskLevel.values) {
      riskBreakdown[level] =
          analyzedLogs.where((l) => l.riskLevel == level).length;
    }

    stopwatch.stop();
    _log.info(
      'Report generated successfully in ${stopwatch.elapsedMilliseconds}ms '
      '| entries=${analyzedLogs.length} anomalies=${anomalies.length}',
    );

    return ReportResult(
      reportId: _uuid.v4(),
      pdfBytes: pdfBytes,
      excelBytes: excelBytes,
      htmlBytes: htmlBytes,
      format: format,
      standard: effectiveStandard,
      from: from,
      to: effectiveTo,
      generatedAt: DateTime.now(),
      generationDuration: stopwatch.elapsed,
      totalEntries: analyzedLogs.length,
      uniqueUsers: uniqueUsers,
      uniqueIps: uniqueIps,
      failedLogins: failedLogins,
      riskBreakdown: riskBreakdown,
      anomalies: anomalies,
      pdfHash: pdfHash,
      excelHash: excelHash,
    );
  }

  /// Convenience static method — creates a reporter and generates in one call.
  ///
  /// ```dart
  /// final result = await ComplianceReporter.quickGenerate(
  ///   collector: MemoryLogCollector(logs: logs),
  ///   from: 30.days.ago,
  /// );
  /// ```
  static Future<ReportResult> quickGenerate({
    required BaseLogCollector collector,
    required DateTime from,
    DateTime? to,
    ReportFormat format = ReportFormat.pdf,
    String? organizationName,
    ComplianceStandard standard = ComplianceStandard.generic,
  }) =>
      ComplianceReporter(
        collector: collector,
        organizationName: organizationName,
        standard: standard,
      ).generate(from: from, to: to, format: format);

  // ── Private helpers ───────────────────────────────────────────────────

  void _validateDateRange(DateTime from, DateTime to) {
    if (from.isAfter(to)) {
      throw InvalidDateRangeException(
        'The "from" date ($from) must be before the "to" date ($to).',
      );
    }
    if (to.difference(from).inDays > 3650) {
      throw InvalidDateRangeException(
        'Date range must not exceed 10 years (3650 days). '
        'Received ${to.difference(from).inDays} days.',
      );
    }
  }

  BaseTemplate _resolveTemplate(ComplianceStandard std) {
    if (template != null) return template!;
    return switch (std) {
      ComplianceStandard.gdpr || ComplianceStandard.hipaa =>
        GdprTemplate(
          organizationName: organizationName ?? 'Organization',
          logoPath: organizationLogo,
        ),
      ComplianceStandard.soc2 || ComplianceStandard.iso27001 =>
        Soc2Template(
          organizationName: organizationName ?? 'Organization',
          logoPath: organizationLogo,
        ),
      _ => CorporateTemplate(
          organizationName: organizationName ?? 'Organization',
          logoPath: organizationLogo,
        ),
    };
  }

  static bool _needsPdf(ReportFormat f) =>
      f == ReportFormat.pdf || f == ReportFormat.both || f == ReportFormat.all;

  static bool _needsExcel(ReportFormat f) =>
      f == ReportFormat.excel ||
      f == ReportFormat.both ||
      f == ReportFormat.all;

  static bool _needsHtml(ReportFormat f) =>
      f == ReportFormat.html || f == ReportFormat.all;

  static String _sha256hex(Uint8List bytes) =>
      sha256.convert(bytes).toString();
}
