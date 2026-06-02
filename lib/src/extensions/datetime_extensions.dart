/// Convenience extensions on [DateTime] for writing expressive,
/// readable time-range expressions in compliance report code.
///
/// ## Examples
///
/// ```dart
/// // Subtract a Duration
/// final from = DateTime.now() - 90.days;
///
/// // Add a Duration
/// final deadline = DateTime.now() + 30.days;
///
/// // Start / end of day
/// final startOfToday = DateTime.now().startOfDay;
/// final endOfToday   = DateTime.now().endOfDay;
///
/// // Start of month / year
/// final monthStart = DateTime.now().startOfMonth;
/// final yearStart  = DateTime.now().startOfYear;
///
/// // Range check
/// if (someDate.isBetween(from, to)) { ... }
/// ```
extension DateTimeComplianceExtensions on DateTime {
  /// Subtracts a [Duration] from this [DateTime].
  ///
  /// ```dart
  /// DateTime.now() - 90.days   // 90 days ago
  /// ```
  DateTime operator -(Duration duration) => subtract(duration);

  /// Adds a [Duration] to this [DateTime].
  ///
  /// ```dart
  /// DateTime.now() + 30.days   // 30 days in the future
  /// ```
  DateTime operator +(Duration duration) => add(duration);

  /// Midnight (00:00:00.000) on this calendar day.
  DateTime get startOfDay => DateTime(year, month, day);

  /// One millisecond before midnight on this calendar day (23:59:59.999).
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999);

  /// First moment of the current calendar month.
  DateTime get startOfMonth => DateTime(year, month);

  /// Last moment of the current calendar month.
  DateTime get endOfMonth =>
      DateTime(year, month + 1, 1).subtract(const Duration(milliseconds: 1));

  /// First moment of the current calendar year.
  DateTime get startOfYear => DateTime(year);

  /// Last moment of the current calendar year.
  DateTime get endOfYear =>
      DateTime(year + 1, 1, 1).subtract(const Duration(milliseconds: 1));

  /// First moment of the current ISO week (Monday).
  DateTime get startOfWeek {
    final d = weekday; // 1=Mon … 7=Sun
    return DateTime(year, month, day - (d - 1));
  }

  /// Last moment of the current ISO week (Sunday).
  DateTime get endOfWeek {
    final d = weekday;
    return DateTime(year, month, day + (7 - d), 23, 59, 59, 999);
  }

  /// Returns `true` if this date falls within [start] and [end] (inclusive).
  bool isBetween(DateTime start, DateTime end) =>
      !isBefore(start) && !isAfter(end);

  /// Returns the number of whole calendar days until [other].
  ///
  /// Calendar-day boundaries are used so that the result is independent of
  /// the time-of-day component of either date.  For example, the distance
  /// from `2026-06-15 14:30` to `2026-07-15 00:00` is **30** calendar days,
  /// not 29 (which `difference().inDays` would return due to truncation).
  int daysUntil(DateTime other) =>
      DateTime(other.year, other.month, other.day)
          .difference(DateTime(year, month, day))
          .inDays;

  /// Returns the number of whole calendar months between this date and [other].
  int monthsUntil(DateTime other) =>
      (other.year - year) * 12 + (other.month - month);

  /// Returns a [DateTime] at the same time on the same day, but in UTC.
  DateTime toUtcDay() => DateTime.utc(year, month, day);
}
