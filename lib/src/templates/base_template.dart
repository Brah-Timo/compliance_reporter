/// Abstract base class for all PDF / report templates.
///
/// A template controls the visual identity of the report:
/// colours, the organisation name, logo path, and optional
/// legal-compliance boilerplate text.
///
/// Extend this class to create a fully custom brand template:
///
/// ```dart
/// class MyBrandTemplate extends BaseTemplate {
///   const MyBrandTemplate()
///       : super(
///           organizationName: 'My Company',
///           primaryColorHex: '#0D47A1',
///           secondaryColorHex: '#E3F2FD',
///           accentColorHex: '#B71C1C',
///         );
/// }
/// ```
abstract class BaseTemplate {
  /// Display name printed in the report header.
  final String organizationName;

  /// Path or URL to the organisation logo (PNG / JPEG).
  /// `null` renders no logo.
  final String? logoPath;

  /// Primary colour (hex) — used for section headings, table headers.
  final String primaryColorHex;

  /// Secondary colour (hex) — used for alternating row tints.
  final String secondaryColorHex;

  /// Accent colour (hex) — used for critical/warning highlights.
  final String accentColorHex;

  /// Optional multi-line legal disclaimer printed at the end of the report.
  final String? legalDisclaimer;

  /// Creates a [BaseTemplate].
  const BaseTemplate({
    required this.organizationName,
    this.logoPath,
    required this.primaryColorHex,
    required this.secondaryColorHex,
    required this.accentColorHex,
    this.legalDisclaimer,
  });
}
