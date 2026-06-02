/// # compliance_reporter
///
/// A production-grade Dart package for generating automated, legal-grade
/// compliance audit reports in **PDF** and **Excel** formats.
///
/// Covers user access logs, IP addresses, session durations, activity
/// trails, risk scoring, anomaly detection, and digital signatures.
/// Compliant with **GDPR**, **SOC 2**, **ISO 27001**, **PCI-DSS**, and
/// **HIPAA** standards out of the box.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:compliance_reporter/compliance_reporter.dart';
///
/// final reporter = ComplianceReporter(
///   collector: MemoryLogCollector(logs: myAccessLogs),
///   organizationName: 'Acme Corp',
///   standard: ComplianceStandard.soc2,
/// );
///
/// final result = await reporter.generate(
///   from: DateTime.now() - 90.days,
///   format: ReportFormat.pdf,
/// );
///
/// await result.savePdfToFile('/reports/audit_q2_2026.pdf');
/// print(result); // → ComplianceReport { totalEntries: 4821, ... }
/// ```
///
/// ## Advanced Usage
///
/// ```dart
/// final reporter = ComplianceReporter(
///   collector: HttpLogCollector(
///     baseUrl: 'https://api.myapp.com/audit-logs',
///     headers: {'Authorization': 'Bearer $token'},
///   ),
///   standard: ComplianceStandard.gdpr,
///   enableDigitalSignature: true,
///   anonymizeSensitiveData: true,
/// );
///
/// final result = await reporter.generate(
///   from: 3.months.ago,
///   format: ReportFormat.both,  // PDF + Excel
/// );
/// ```
library compliance_reporter;

// ── Core ──────────────────────────────────────────────────────────────────
export 'src/core/compliance_reporter.dart';
export 'src/core/report_config.dart';
export 'src/core/report_result.dart';

// ── Models ────────────────────────────────────────────────────────────────
export 'src/models/access_log.dart';
export 'src/models/user_session.dart';
export 'src/models/report_format.dart';
export 'src/models/compliance_standard.dart';
export 'src/models/risk_level.dart';
export 'src/models/report_metadata.dart';

// ── Collectors ────────────────────────────────────────────────────────────
export 'src/collectors/base_log_collector.dart';
export 'src/collectors/memory_log_collector.dart';
export 'src/collectors/file_log_collector.dart';
export 'src/collectors/database_log_collector.dart';
export 'src/collectors/http_log_collector.dart';

// ── Processors ────────────────────────────────────────────────────────────
export 'src/processors/log_processor.dart';
export 'src/processors/risk_analyzer.dart';
export 'src/processors/anomaly_detector.dart';
export 'src/processors/data_anonymizer.dart';

// ── Generators ────────────────────────────────────────────────────────────
export 'src/generators/pdf_generator.dart';
export 'src/generators/excel_generator.dart';
export 'src/generators/html_generator.dart';

// ── Templates ─────────────────────────────────────────────────────────────
export 'src/templates/base_template.dart';
export 'src/templates/corporate_template.dart';
export 'src/templates/minimal_template.dart';
export 'src/templates/gdpr_template.dart';
export 'src/templates/soc2_template.dart';

// ── Security ──────────────────────────────────────────────────────────────
export 'src/security/report_signer.dart';
export 'src/security/watermark_service.dart';
export 'src/security/hash_validator.dart';

// ── Exporters ─────────────────────────────────────────────────────────────
export 'src/exporters/local_exporter.dart';
export 'src/exporters/email_exporter.dart';
export 'src/exporters/cloud_exporter.dart';

// ── Extensions ────────────────────────────────────────────────────────────
export 'src/extensions/datetime_extensions.dart';
export 'src/extensions/duration_extensions.dart';
export 'src/extensions/string_extensions.dart';

// ── Exceptions ────────────────────────────────────────────────────────────
export 'src/exceptions/compliance_exception.dart';
export 'src/exceptions/invalid_date_range_exception.dart';
export 'src/exceptions/no_data_found_exception.dart';
export 'src/exceptions/export_failure_exception.dart';
