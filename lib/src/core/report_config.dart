import '../models/compliance_standard.dart';
import '../models/risk_level.dart';

/// Advanced configuration for a compliance report generation run.
///
/// Passed optionally to [ComplianceReporter.generate]. Provides
/// fine-grained control over filtering, thresholds, branding, and
/// output behaviour without altering the reporter's base settings.
///
/// ```dart
/// final config = ReportConfig(
///   title: 'Q2-2026 Security Audit',
///   includeOnlyRiskLevels: {RiskLevel.high, RiskLevel.critical},
///   maxEntriesPerPage: 40,
///   includeExecutiveSummary: true,
///   includeAnomalySection: true,
///   includeUserStatistics: true,
///   filterByCountries: ['US', 'DE', 'GB'],
/// );
/// ```
class ReportConfig {
  // ── Meta ──────────────────────────────────────────────────────────────

  /// Custom title printed on the report cover / header.
  final String? title;

  /// Free-form subtitle or reference number for the audit.
  final String? subtitle;

  /// Reference / ticket number used by the auditor (e.g. "AUDIT-2026-Q2").
  final String? referenceNumber;

  /// Name of the person or team who requested the report.
  final String? requestedBy;

  // ── Filtering ─────────────────────────────────────────────────────────

  /// When non-null, only logs matching these user IDs are included.
  final Set<String>? filterByUserIds;

  /// When non-null, only logs matching these IP addresses are included.
  final Set<String>? filterByIpAddresses;

  /// When non-null, only logs from these country codes are included.
  final Set<String>? filterByCountries;

  /// When non-null, only logs matching these user roles are included.
  final Set<String>? filterByRoles;

  /// When non-null, only logs with these risk levels are included.
  final Set<RiskLevel>? includeOnlyRiskLevels;

  /// When non-null, logs from these IP addresses are excluded.
  final Set<String>? excludeIpAddresses;

  /// Exclude entries whose [AccessLog.status] is `success` (show only failures).
  final bool showFailuresOnly;

  /// Include only logs that have at least one anomaly flag.
  final bool showAnomaliesOnly;

  // ── Pagination & layout ───────────────────────────────────────────────

  /// Maximum number of log entries per page in the PDF table.
  final int maxEntriesPerPage;

  /// Maximum total entries written to the Excel "Full Access Log" sheet.
  /// `0` means unlimited.
  final int maxTotalEntries;

  // ── Sections ──────────────────────────────────────────────────────────

  /// Include the executive-summary section at the top of the report.
  final bool includeExecutiveSummary;

  /// Include the risk-distribution section (pie / table).
  final bool includeRiskDistribution;

  /// Include the anomaly-detection section.
  final bool includeAnomalySection;

  /// Include the per-user statistics section.
  final bool includeUserStatistics;

  /// Include the geographic distribution section (top countries / cities).
  final bool includeGeoDistribution;

  /// Include the device / OS breakdown section.
  final bool includeDeviceBreakdown;

  /// Include the hourly activity heatmap section.
  final bool includeActivityHeatmap;

  /// Include the signature lines at the end of the PDF.
  final bool includeSignatureLines;

  // ── Branding ──────────────────────────────────────────────────────────

  /// Primary hex colour used for table headers and headings (e.g. "#1A237E").
  final String? primaryColorHex;

  /// Secondary hex colour used for alternating rows (e.g. "#E8EAF6").
  final String? secondaryColorHex;

  /// Accent hex colour used for risk highlights (e.g. "#B71C1C").
  final String? accentColorHex;

  // ── Behaviour ─────────────────────────────────────────────────────────

  /// Compliance standard governing field selection and anonymisation rules.
  final ComplianceStandard? overrideStandard;

  /// When true, the report is sorted by risk level (critical first).
  final bool sortByRiskDescending;

  /// Custom footer text appended after the standard "CONFIDENTIAL" notice.
  final String? customFooterText;

  // ── Constructor ───────────────────────────────────────────────────────

  /// Creates a [ReportConfig] with sensible defaults.
  const ReportConfig({
    this.title,
    this.subtitle,
    this.referenceNumber,
    this.requestedBy,
    this.filterByUserIds,
    this.filterByIpAddresses,
    this.filterByCountries,
    this.filterByRoles,
    this.includeOnlyRiskLevels,
    this.excludeIpAddresses,
    this.showFailuresOnly = false,
    this.showAnomaliesOnly = false,
    this.maxEntriesPerPage = 50,
    this.maxTotalEntries = 0,
    this.includeExecutiveSummary = true,
    this.includeRiskDistribution = true,
    this.includeAnomalySection = true,
    this.includeUserStatistics = true,
    this.includeGeoDistribution = true,
    this.includeDeviceBreakdown = true,
    this.includeActivityHeatmap = true,
    this.includeSignatureLines = true,
    this.primaryColorHex,
    this.secondaryColorHex,
    this.accentColorHex,
    this.overrideStandard,
    this.sortByRiskDescending = true,
    this.customFooterText,
  });

  /// A preset for quick internal audits — all sections on, no filtering.
  factory ReportConfig.full() => const ReportConfig();

  /// A preset that shows only high-risk and critical entries.
  factory ReportConfig.highRiskOnly() => const ReportConfig(
        includeOnlyRiskLevels: {RiskLevel.high, RiskLevel.critical},
        includeExecutiveSummary: true,
        includeAnomalySection: true,
        includeUserStatistics: false,
        includeDeviceBreakdown: false,
        includeActivityHeatmap: false,
      );

  /// A preset for GDPR data-subject access requests — minimal PII visible.
  factory ReportConfig.gdprMinimal() => const ReportConfig(
        includeGeoDistribution: false,
        includeDeviceBreakdown: false,
        includeActivityHeatmap: false,
        includeSignatureLines: true,
        overrideStandard: ComplianceStandard.gdpr,
      );

  /// A preset optimised for SOC 2 auditors.
  factory ReportConfig.soc2Audit() => const ReportConfig(
        overrideStandard: ComplianceStandard.soc2,
        includeExecutiveSummary: true,
        includeRiskDistribution: true,
        includeAnomalySection: true,
        includeUserStatistics: true,
        includeActivityHeatmap: true,
        includeSignatureLines: true,
        sortByRiskDescending: true,
      );

  /// Creates a copy of this config with specific fields overridden.
  ReportConfig copyWith({
    String? title,
    String? subtitle,
    String? referenceNumber,
    String? requestedBy,
    Set<String>? filterByUserIds,
    Set<String>? filterByIpAddresses,
    Set<String>? filterByCountries,
    Set<String>? filterByRoles,
    Set<RiskLevel>? includeOnlyRiskLevels,
    Set<String>? excludeIpAddresses,
    bool? showFailuresOnly,
    bool? showAnomaliesOnly,
    int? maxEntriesPerPage,
    int? maxTotalEntries,
    bool? includeExecutiveSummary,
    bool? includeRiskDistribution,
    bool? includeAnomalySection,
    bool? includeUserStatistics,
    bool? includeGeoDistribution,
    bool? includeDeviceBreakdown,
    bool? includeActivityHeatmap,
    bool? includeSignatureLines,
    String? primaryColorHex,
    String? secondaryColorHex,
    String? accentColorHex,
    ComplianceStandard? overrideStandard,
    bool? sortByRiskDescending,
    String? customFooterText,
  }) =>
      ReportConfig(
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        referenceNumber: referenceNumber ?? this.referenceNumber,
        requestedBy: requestedBy ?? this.requestedBy,
        filterByUserIds: filterByUserIds ?? this.filterByUserIds,
        filterByIpAddresses: filterByIpAddresses ?? this.filterByIpAddresses,
        filterByCountries: filterByCountries ?? this.filterByCountries,
        filterByRoles: filterByRoles ?? this.filterByRoles,
        includeOnlyRiskLevels:
            includeOnlyRiskLevels ?? this.includeOnlyRiskLevels,
        excludeIpAddresses: excludeIpAddresses ?? this.excludeIpAddresses,
        showFailuresOnly: showFailuresOnly ?? this.showFailuresOnly,
        showAnomaliesOnly: showAnomaliesOnly ?? this.showAnomaliesOnly,
        maxEntriesPerPage: maxEntriesPerPage ?? this.maxEntriesPerPage,
        maxTotalEntries: maxTotalEntries ?? this.maxTotalEntries,
        includeExecutiveSummary:
            includeExecutiveSummary ?? this.includeExecutiveSummary,
        includeRiskDistribution:
            includeRiskDistribution ?? this.includeRiskDistribution,
        includeAnomalySection:
            includeAnomalySection ?? this.includeAnomalySection,
        includeUserStatistics:
            includeUserStatistics ?? this.includeUserStatistics,
        includeGeoDistribution:
            includeGeoDistribution ?? this.includeGeoDistribution,
        includeDeviceBreakdown:
            includeDeviceBreakdown ?? this.includeDeviceBreakdown,
        includeActivityHeatmap:
            includeActivityHeatmap ?? this.includeActivityHeatmap,
        includeSignatureLines:
            includeSignatureLines ?? this.includeSignatureLines,
        primaryColorHex: primaryColorHex ?? this.primaryColorHex,
        secondaryColorHex: secondaryColorHex ?? this.secondaryColorHex,
        accentColorHex: accentColorHex ?? this.accentColorHex,
        overrideStandard: overrideStandard ?? this.overrideStandard,
        sortByRiskDescending: sortByRiskDescending ?? this.sortByRiskDescending,
        customFooterText: customFooterText ?? this.customFooterText,
      );

  @override
  String toString() => 'ReportConfig('
      'title: $title, '
      'standard: $overrideStandard, '
      'filters: {users:${filterByUserIds?.length}, ips:${filterByIpAddresses?.length}, '
      'countries:${filterByCountries?.length}}'
      ')';
}
