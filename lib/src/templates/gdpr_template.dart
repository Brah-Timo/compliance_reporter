import 'base_template.dart';

/// A template pre-configured for GDPR-compliant audit reports.
///
/// Uses a green / teal palette to signal data-protection compliance.
/// Includes the standard GDPR Article 30 legal disclaimer.
///
/// Primary:   #1B5E20 (forest green)
/// Secondary: #E8F5E9 (mint tint)
/// Accent:    #B71C1C (deep red)
class GdprTemplate extends BaseTemplate {
  /// Creates a [GdprTemplate].
  const GdprTemplate({
    required super.organizationName,
    super.logoPath,
  }) : super(
          primaryColorHex: '#1B5E20',
          secondaryColorHex: '#E8F5E9',
          accentColorHex: '#B71C1C',
          legalDisclaimer:
              'This report has been generated in accordance with GDPR '
              'Article 30 (Records of Processing Activities). Personal data '
              'contained herein has been pseudonymised where required. '
              'This document must be retained for a minimum of 3 years and '
              'made available to supervisory authorities upon request.',
        );
}
