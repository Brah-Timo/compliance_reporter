import 'compliance_exception.dart';

/// Thrown when the supplied date range is logically invalid.
///
/// Common causes:
/// - `from` is after `to`
/// - The range spans more than 10 years (3650 days)
/// - Either date is `null` when a value is required
class InvalidDateRangeException extends ComplianceException {
  /// Creates an [InvalidDateRangeException].
  const InvalidDateRangeException(String message)
      : super(message, code: 'INVALID_DATE_RANGE');
}
