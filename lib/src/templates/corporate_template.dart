import 'base_template.dart';

/// A professional corporate template with a dark-blue / white palette.
///
/// Suitable for general enterprise audits, banking, SaaS, and
/// government organisations.
///
/// Primary:   #1A237E (deep navy blue)
/// Secondary: #E8EAF6 (lavender tint)
/// Accent:    #B71C1C (deep red)
class CorporateTemplate extends BaseTemplate {
  /// Creates a [CorporateTemplate].
  const CorporateTemplate({
    required super.organizationName,
    super.logoPath,
    super.legalDisclaimer =
        'This document is confidential and intended solely for '
        'authorised personnel. Unauthorised disclosure, reproduction, '
        'or distribution is strictly prohibited.',
  }) : super(
          primaryColorHex: '#1A237E',
          secondaryColorHex: '#E8EAF6',
          accentColorHex: '#B71C1C',
        );
}
