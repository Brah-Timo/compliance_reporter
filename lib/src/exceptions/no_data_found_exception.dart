import 'compliance_exception.dart';

/// Thrown when the collector returns zero entries for the specified
/// period and [ComplianceReporter.throwOnEmptyData] is `true`.
///
/// Possible causes:
/// - The date range is correct but no activity occurred in that period.
/// - The collector is pointing at the wrong data source.
/// - The API / database is not returning data for the given filters.
class NoDataFoundException extends ComplianceException {
  /// Creates a [NoDataFoundException].
  const NoDataFoundException(String message)
      : super(message, code: 'NO_DATA_FOUND');
}
