/// The regulatory / security framework that governs report content.
///
/// Each value activates specific field sets, anonymisation rules,
/// section headings, and compliance statements in the generated report.
enum ComplianceStandard {
  /// No specific standard — includes all fields, no forced anonymisation.
  generic,

  /// EU General Data Protection Regulation (GDPR).
  ///
  /// Activates automatic PII anonymisation, adds data-processing statements,
  /// and maps fields to GDPR Article 30 record-keeping requirements.
  gdpr,

  /// Service Organization Controls 2 (SOC 2).
  ///
  /// Focuses on availability, security, and confidentiality criteria.
  /// Adds security-control columns and an access-review checklist.
  soc2,

  /// ISO/IEC 27001:2022 — Information Security Management.
  ///
  /// Structures the report around Annex A.9 (Access Control) controls.
  iso27001,

  /// Payment Card Industry Data Security Standard (PCI-DSS).
  ///
  /// Activates cardholder-data masking and PCI-DSS Requirement 10
  /// log-format compliance.
  pciDss,

  /// Health Insurance Portability and Accountability Act (HIPAA).
  ///
  /// Activates Protected Health Information (PHI) masking and adds the
  /// HIPAA audit-log fields required by 45 CFR §164.312(b).
  hipaa,

  /// A user-defined standard — behaviour driven entirely by [ReportConfig].
  custom;

  /// Short display name used in report headers.
  String get displayName => switch (this) {
        ComplianceStandard.generic => 'Generic',
        ComplianceStandard.gdpr => 'GDPR',
        ComplianceStandard.soc2 => 'SOC 2',
        ComplianceStandard.iso27001 => 'ISO/IEC 27001:2022',
        ComplianceStandard.pciDss => 'PCI-DSS',
        ComplianceStandard.hipaa => 'HIPAA',
        ComplianceStandard.custom => 'Custom',
      };

  /// Whether PII must be masked under this standard.
  bool get requiresAnonymisation => switch (this) {
        ComplianceStandard.gdpr ||
        ComplianceStandard.hipaa ||
        ComplianceStandard.pciDss =>
          true,
        _ => false,
      };

  /// Official reference document or regulation clause.
  String get reference => switch (this) {
        ComplianceStandard.gdpr => 'GDPR Art. 30 — Records of processing',
        ComplianceStandard.soc2 => 'AICPA SOC 2 — CC6 / CC7',
        ComplianceStandard.iso27001 => 'ISO 27001:2022 — A.9 Access Control',
        ComplianceStandard.pciDss => 'PCI-DSS v4.0 — Requirement 10',
        ComplianceStandard.hipaa => 'HIPAA 45 CFR §164.312(b)',
        _ => '',
      };
}
