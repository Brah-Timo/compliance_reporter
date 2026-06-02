import 'compliance_standard.dart';
import 'report_format.dart';

/// Lightweight metadata object describing a previously generated report.
///
/// Useful for audit trail logging, report registries, and email
/// notification systems where you need to reference a report without
/// holding its bytes in memory.
class ReportMetadata {
  /// Unique report ID (UUID v4).
  final String reportId;

  /// Compliance standard the report was generated against.
  final ComplianceStandard standard;

  /// Output format(s) generated.
  final ReportFormat format;

  /// The organisation name printed on the report.
  final String organizationName;

  /// Start of the audit period.
  final DateTime from;

  /// End of the audit period.
  final DateTime to;

  /// When generation completed.
  final DateTime generatedAt;

  /// Wall-clock generation time.
  final Duration generationDuration;

  /// Total number of log entries included.
  final int totalEntries;

  /// Number of anomalies detected.
  final int anomaliesDetected;

  /// SHA-256 digest of the PDF (empty if no PDF was generated).
  final String pdfHash;

  /// SHA-256 digest of the Excel file (empty if no Excel was generated).
  final String excelHash;

  /// PDF file size in bytes (0 if not generated).
  final int pdfSizeBytes;

  /// Excel file size in bytes (0 if not generated).
  final int excelSizeBytes;

  /// Creates a [ReportMetadata] instance.
  const ReportMetadata({
    required this.reportId,
    required this.standard,
    required this.format,
    required this.organizationName,
    required this.from,
    required this.to,
    required this.generatedAt,
    required this.generationDuration,
    required this.totalEntries,
    this.anomaliesDetected = 0,
    this.pdfHash = '',
    this.excelHash = '',
    this.pdfSizeBytes = 0,
    this.excelSizeBytes = 0,
  });

  /// Serialises to a JSON map (suitable for database storage).
  Map<String, dynamic> toJson() => {
        'reportId': reportId,
        'standard': standard.name,
        'format': format.name,
        'organizationName': organizationName,
        'from': from.toIso8601String(),
        'to': to.toIso8601String(),
        'generatedAt': generatedAt.toIso8601String(),
        'generationMs': generationDuration.inMilliseconds,
        'totalEntries': totalEntries,
        'anomaliesDetected': anomaliesDetected,
        'pdfHash': pdfHash,
        'excelHash': excelHash,
        'pdfSizeBytes': pdfSizeBytes,
        'excelSizeBytes': excelSizeBytes,
      };

  /// Deserialises from a JSON map.
  factory ReportMetadata.fromJson(Map<String, dynamic> json) =>
      ReportMetadata(
        reportId: json['reportId'] as String,
        standard: ComplianceStandard.values.firstWhere(
          (e) => e.name == json['standard'],
          orElse: () => ComplianceStandard.generic,
        ),
        format: ReportFormat.values.firstWhere(
          (e) => e.name == json['format'],
          orElse: () => ReportFormat.pdf,
        ),
        organizationName: json['organizationName'] as String,
        from: DateTime.parse(json['from'] as String),
        to: DateTime.parse(json['to'] as String),
        generatedAt: DateTime.parse(json['generatedAt'] as String),
        generationDuration: Duration(
          milliseconds: json['generationMs'] as int? ?? 0,
        ),
        totalEntries: json['totalEntries'] as int,
        anomaliesDetected: json['anomaliesDetected'] as int? ?? 0,
        pdfHash: json['pdfHash'] as String? ?? '',
        excelHash: json['excelHash'] as String? ?? '',
        pdfSizeBytes: json['pdfSizeBytes'] as int? ?? 0,
        excelSizeBytes: json['excelSizeBytes'] as int? ?? 0,
      );

  @override
  String toString() =>
      'ReportMetadata(id=$reportId, standard=${standard.name}, '
      'entries=$totalEntries, generated=${generatedAt.toIso8601String()})';
}
