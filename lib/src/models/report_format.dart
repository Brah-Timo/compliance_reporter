/// Specifies which file format(s) [ComplianceReporter] should produce.
enum ReportFormat {
  /// Portable Document Format — best for printing and formal submissions.
  pdf,

  /// Microsoft Excel (.xlsx) — best for filtering, sorting, and analysis.
  excel,

  /// Standalone HTML — best for embedding in emails or internal portals.
  html,

  /// PDF **and** Excel together in one [ReportResult].
  both,

  /// PDF, Excel **and** HTML in one [ReportResult].
  all;

  /// Human-readable display label.
  String get label => switch (this) {
        ReportFormat.pdf => 'PDF',
        ReportFormat.excel => 'Excel (.xlsx)',
        ReportFormat.html => 'HTML',
        ReportFormat.both => 'PDF + Excel',
        ReportFormat.all => 'PDF + Excel + HTML',
      };

  /// Typical MIME types emitted for this format.
  List<String> get mimeTypes => switch (this) {
        ReportFormat.pdf => ['application/pdf'],
        ReportFormat.excel => [
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ],
        ReportFormat.html => ['text/html'],
        ReportFormat.both => [
            'application/pdf',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ],
        ReportFormat.all => [
            'application/pdf',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'text/html',
          ],
      };
}
