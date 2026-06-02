/// Convenience extensions on [int] that create [Duration] values,
/// and extensions on [Duration] that produce past/future [DateTime]s.
///
/// ## Examples
///
/// ```dart
/// // Integer → Duration
/// 90.days       // Duration(days: 90)
/// 3.hours       // Duration(hours: 3)
/// 2.weeks       // Duration(days: 14)
/// 3.months      // Duration(days: 90)  (approximate)
/// 1.year        // Duration(days: 365) (approximate)
///
/// // Duration → DateTime in the past / future
/// 90.days.ago   // DateTime 90 days before now
/// 30.days.fromNow   // DateTime 30 days from now
///
/// // Combined
/// final from = 3.months.ago;
/// final to   = DateTime.now();
/// ```
extension IntDurationExtensions on int {
  /// Creates a [Duration] of this many days.
  Duration get days => Duration(days: this);

  /// Creates a [Duration] of this many hours.
  Duration get hours => Duration(hours: this);

  /// Creates a [Duration] of this many minutes.
  Duration get minutes => Duration(minutes: this);

  /// Creates a [Duration] of this many seconds.
  Duration get seconds => Duration(seconds: this);

  /// Creates a [Duration] of this many milliseconds.
  Duration get milliseconds => Duration(milliseconds: this);

  /// Creates a [Duration] of this many weeks (7 days each).
  Duration get weeks => Duration(days: this * 7);

  /// Creates an **approximate** [Duration] of this many months (30 days each).
  Duration get months => Duration(days: this * 30);

  /// Creates an **approximate** [Duration] of this many years (365 days each).
  Duration get years => Duration(days: this * 365);
}

/// Extensions on [Duration] that return [DateTime] offsets from now.
extension DurationAgoExtensions on Duration {
  /// The [DateTime] this duration **before** the current moment.
  ///
  /// ```dart
  /// 90.days.ago   // → DateTime.now().subtract(Duration(days: 90))
  /// ```
  DateTime get ago => DateTime.now().subtract(this);

  /// The [DateTime] this duration **after** the current moment.
  ///
  /// ```dart
  /// 30.days.fromNow   // → DateTime.now().add(Duration(days: 30))
  /// ```
  DateTime get fromNow => DateTime.now().add(this);

  /// Human-readable English summary (e.g. `'2h 15m 03s'`).
  String get readable {
    final h = inHours;
    final m = inMinutes.remainder(60);
    final s = inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}
