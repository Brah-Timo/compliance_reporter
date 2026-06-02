import 'base_template.dart';

/// A clean, minimal template with a grey / white palette.
///
/// Suitable for internal technical audits, developer teams, and
/// quick ad-hoc reports where branding is secondary to readability.
///
/// Primary:   #37474F (dark grey)
/// Secondary: #F5F5F5 (light grey)
/// Accent:    #E64A19 (deep orange)
class MinimalTemplate extends BaseTemplate {
  /// Creates a [MinimalTemplate].
  const MinimalTemplate({
    required super.organizationName,
    super.logoPath,
  }) : super(
          primaryColorHex: '#37474F',
          secondaryColorHex: '#F5F5F5',
          accentColorHex: '#E64A19',
          legalDisclaimer: null,
        );
}
