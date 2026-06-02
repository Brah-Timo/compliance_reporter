import 'compliance_exception.dart';

/// Thrown when saving or transmitting a report file fails.
///
/// Common causes:
/// - Insufficient disk space or permissions (local export)
/// - Network timeout or authentication failure (email / cloud export)
/// - The report bytes are corrupt or empty
class ExportFailureException extends ComplianceException {
  /// Creates an [ExportFailureException].
  const ExportFailureException(String message, {dynamic cause})
      : super(message, code: 'EXPORT_FAILURE', cause: cause);
}
