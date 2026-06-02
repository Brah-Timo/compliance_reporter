/// Severity level assigned to each [AccessLog] entry by [RiskAnalyzer].
enum RiskLevel {
  /// Completely normal activity — no action required.
  low,

  /// Warrants attention but is not immediately alarming.
  medium,

  /// Suspicious activity — investigation recommended.
  high,

  /// Immediate threat — urgent action required.
  critical;

  // ── Display ───────────────────────────────────────────────────────────

  /// Human-readable English label used in report cells.
  String get label => switch (this) {
        RiskLevel.low => 'Low',
        RiskLevel.medium => 'Medium',
        RiskLevel.high => 'High',
        RiskLevel.critical => 'Critical',
      };

  /// Short emoji indicator for quick scanning.
  String get emoji => switch (this) {
        RiskLevel.low => '✅',
        RiskLevel.medium => '🟡',
        RiskLevel.high => '🟠',
        RiskLevel.critical => '🔴',
      };

  // ── Colours ───────────────────────────────────────────────────────────

  /// Primary hex colour (text / border).
  String get colorHex => switch (this) {
        RiskLevel.low => '#2ECC71',
        RiskLevel.medium => '#F39C12',
        RiskLevel.high => '#E74C3C',
        RiskLevel.critical => '#8E44AD',
      };

  /// Light background tint for table rows.
  String get bgColorHex => switch (this) {
        RiskLevel.low => '#FFFFFF',
        RiskLevel.medium => '#FFFDE7',
        RiskLevel.high => '#FFF3E0',
        RiskLevel.critical => '#FFEBEE',
      };

  /// PDF PdfColor hex (same value, exposed for convenience).
  String get pdfColorHex => colorHex;

  // ── Comparison helpers ────────────────────────────────────────────────

  /// Returns `true` if this level is at least [other].
  bool isAtLeast(RiskLevel other) => index >= other.index;

  /// Returns the more severe of `this` and [other].
  RiskLevel max(RiskLevel other) =>
      index >= other.index ? this : other;

  // ── Score thresholds (used by RiskAnalyzer) ───────────────────────────

  /// The minimum numeric score required to reach this level.
  int get minScore => switch (this) {
        RiskLevel.low => 0,
        RiskLevel.medium => 15,
        RiskLevel.high => 30,
        RiskLevel.critical => 50,
      };

  /// Derives a [RiskLevel] from a raw numeric score.
  static RiskLevel fromScore(int score) {
    if (score >= 50) return RiskLevel.critical;
    if (score >= 30) return RiskLevel.high;
    if (score >= 15) return RiskLevel.medium;
    return RiskLevel.low;
  }
}
