/// Base class for all exceptions thrown by the `compliance_reporter` package.
///
/// Catch this type to handle any package-level error:
///
/// ```dart
/// try {
///   final result = await reporter.generate(from: from);
/// } on ComplianceException catch (e) {
///   print('Report generation failed [${e.code}]: ${e.message}');
///   if (e.cause != null) print('Caused by: ${e.cause}');
/// }
/// ```
abstract class ComplianceException implements Exception {
  /// Human-readable description of the error.
  final String message;

  /// Machine-readable error code (e.g. `'INVALID_DATE_RANGE'`).
  final String? code;

  /// The underlying cause, if any.
  final dynamic cause;

  /// Creates a [ComplianceException].
  const ComplianceException(
    this.message, {
    this.code,
    this.cause,
  });

  @override
  String toString() {
    final buf = StringBuffer()
      ..write('ComplianceException')
      ..write(code != null ? '[$code]' : '')
      ..write(': ')
      ..write(message);
    if (cause != null) buf.write('\nCaused by: $cause');
    return buf.toString();
  }
}
