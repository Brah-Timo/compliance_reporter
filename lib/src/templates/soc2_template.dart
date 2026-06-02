import 'base_template.dart';

/// A template pre-configured for SOC 2 / ISO 27001 audit reports.
///
/// Uses a steel-blue palette with the AICPA SOC 2 and ISO 27001
/// legal statement in the footer disclaimer.
///
/// Primary:   #0D47A1 (deep blue)
/// Secondary: #E3F2FD (light blue tint)
/// Accent:    #E65100 (deep orange)
class Soc2Template extends BaseTemplate {
  /// Creates a [Soc2Template].
  const Soc2Template({
    required super.organizationName,
    super.logoPath,
  }) : super(
          primaryColorHex: '#0D47A1',
          secondaryColorHex: '#E3F2FD',
          accentColorHex: '#E65100',
          legalDisclaimer:
              'This report supports SOC 2 Type II and ISO/IEC 27001:2022 '
              'audit requirements. Access log data has been collected, '
              'processed, and formatted in accordance with AICPA Trust '
              'Services Criteria CC6 (Logical and Physical Access Controls) '
              'and CC7 (System Operations), as well as ISO 27001:2022 '
              'Annex A.9 Access Control. This document is for authorised '
              'auditor use only.',
        );
}
