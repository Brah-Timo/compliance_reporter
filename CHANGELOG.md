# Changelog

All notable changes to `compliance_reporter` are documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] — 2026-06-01

### Added

#### Core
- `ComplianceReporter` — main orchestration class with 8-step pipeline
- `ReportConfig` — 30+ fine-grained options with 4 preset factories
  (`full`, `highRiskOnly`, `gdprMinimal`, `soc2Audit`)
- `ReportResult` — immutable result with bytes, metadata, integrity hashes,
  and risk breakdown map
- `ComplianceReporter.quickGenerate()` static shortcut method

#### Models
- `AccessLog` — 25-field model with JSON serialisation, `anonymized()`,
  `withRisk()`, and `fromJson()`
- `UserSession` — per-user aggregate computed from `AccessLog` lists
- `ReportFormat` enum — `pdf`, `excel`, `html`, `both`, `all`
- `ComplianceStandard` enum — `generic`, `gdpr`, `soc2`, `iso27001`,
  `pciDss`, `hipaa`, `custom`
- `RiskLevel` enum — `low`, `medium`, `high`, `critical` with colour hex,
  emoji, and score-based factory
- `ReportMetadata` — serialisable report registry record

#### Collectors
- `MemoryLogCollector` — in-memory list with full filter support
- `FileLogCollector` — reads `.json`, `.jsonl`, `.ndjson`, `.csv` files
- `HttpLogCollector` — REST API client with retry logic, custom parsers,
  and envelope unwrapping
- `DatabaseLogCollector` — callback-based bridge for any SQL/NoSQL driver

#### Processors
- `LogProcessor` — deduplication, filtering, normalisation, sorting
- `RiskAnalyzer` — 10-rule scoring engine with per-log notes
- `AnomalyDetector` — 6 detectors: impossible travel, brute force,
  credential stuffing, concurrent sessions, data exfiltration,
  off-hours admin access
- `DataAnonymizer` — GDPR/HIPAA PII masking with SHA-256 pseudonymisation

#### Generators
- `PdfGenerator` — multi-page A4 PDF with 10 sections, colour-coded rows,
  stat boxes, signature lines
- `ExcelGenerator` — 5-sheet .xlsx workbook with KPI dashboard,
  full log, high-risk filter, anomaly sheet, user statistics
- `HtmlGenerator` — self-contained Tailwind CSS HTML report
- `BaseReportGenerator` — abstract base for custom generators

#### Templates
- `CorporateTemplate` — deep navy / white (default)
- `MinimalTemplate` — slate grey / light
- `GdprTemplate` — forest green with GDPR Art. 30 disclaimer
- `Soc2Template` — steel blue with SOC 2 / ISO 27001 disclaimer

#### Security
- `ReportSigner` — HMAC-SHA256 sign + verify
- `WatermarkService` — diagonal "CONFIDENTIAL" watermark
- `HashValidator` — SHA-256, SHA-512, MD5 digest utilities + `ReportIntegrityRecord`

#### Exporters
- `LocalExporter` — save to disk with auto-directory creation
- `EmailExporter` — SendGrid, Mailgun, custom REST API adapters
- `CloudExporter` — AWS S3 (presigned URL), GCS, Azure Blob Storage

#### Extensions
- `IntDurationExtensions` — `90.days`, `3.months`, `1.year`, `2.weeks`, …
- `DurationAgoExtensions` — `.ago`, `.fromNow`, `.readable`
- `DateTimeComplianceExtensions` — `operator -/+`, `startOfDay`, `endOfDay`,
  `startOfMonth`, `endOfMonth`, `isBetween`, `daysUntil`
- `StringComplianceExtensions` — `isIpv4`, `isEmail`, `truncate`, `toLabel`

#### Exceptions
- `ComplianceException` — abstract base
- `InvalidDateRangeException`
- `NoDataFoundException`
- `ExportFailureException`

#### Testing
- 50+ unit tests across all processors, collectors, and extensions
- Full integration test suite covering the complete generation pipeline
- JSON fixture with 5 realistic sample access logs including edge cases
  (impossible travel, after-hours admin, VPN login, sensitive actions)

#### Documentation
- Comprehensive `///` DartDoc on every public API
- `README.md` with quick-start, advanced usage, pricing, and ROI analysis
- Full example Flutter application (`example/`)

---

## [Unreleased]

### Planned for v1.1.0
- `ScheduledReporter` — automatic weekly/monthly report delivery via cron
- `DashboardWidget` — Flutter widget showing live compliance KPIs
- `StreamLogCollector` — real-time log ingestion from Dart streams

### Planned for v1.2.0
- Custom PDF template builder (visual editor)
- Multi-language report output (AR, FR, DE, ES, ZH)
- Webhook delivery option for automated report routing

### Planned for v2.0.0
- ML-based anomaly detection (Isolation Forest algorithm)
- SIEM feed export (Splunk, IBM QRadar compatible)
- Signed PDF (X.509 / PKCS#7) via platform channels
