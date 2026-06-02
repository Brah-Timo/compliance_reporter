# Architecture

## Component Overview

```
┌──────────────────────────────────────────────┐
│          Public API — ComplianceReporter      │
└──────────┬───────────────────────────────────┘
           │
     ┌─────▼─────────────────────────────────┐
     │          Processing Pipeline           │
     │  ┌────────────┐   ┌────────────────┐  │
     │  │ LogCollector│   │  LogProcessor  │  │
     │  │ (data in)  │──▶│  (filter+sort) │  │
     │  └────────────┘   └───────┬────────┘  │
     │                           │           │
     │  ┌────────────────────────▼─────────┐ │
     │  │  RiskAnalyzer  │  AnomalyDetector│ │
     │  └────────────────────────┬─────────┘ │
     └──────────────────────────┬────────────┘
                                │
     ┌──────────────────────────▼────────────┐
     │        Report Generation Layer         │
     │  PdfGenerator │ ExcelGenerator │ HTML  │
     └──────────────────────────┬────────────┘
                                │
     ┌──────────────────────────▼────────────┐
     │     Security & Export Layer            │
     │  Watermark │ Signer │ LocalExporter   │
     └───────────────────────────────────────┘
```

---

## Layer Descriptions

### Log Collector Layer

Responsible for fetching raw `AccessLog` data from any source:

| Collector | Source |
|---|---|
| `MemoryLogCollector` | In-memory `List<AccessLog>` |
| `FileLogCollector` | JSON / JSONL log files on disk |
| `DatabaseLogCollector` | SQLite, PostgreSQL, MySQL (via raw SQL) |
| `HttpLogCollector` | REST API endpoint with pagination support |

All collectors implement `BaseLogCollector`:
```dart
abstract class BaseLogCollector {
  Future<List<AccessLog>> collect({ required DateTime from, required DateTime to, ... });
  Future<int> count({ required DateTime from, required DateTime to });
  Future<bool> isAvailable();
}
```

### Processing Pipeline

**`LogProcessor`** filters, deduplicates, and sorts logs:
- Apply `ReportConfig` filters (user ID whitelist/blacklist, IP filter, min risk level)
- Remove entries outside the `[from, to]` window
- Optionally anonymise PII via `DataAnonymizer`
- Sort by `loginAt` descending

**`RiskAnalyzer`** assigns or validates `RiskLevel` for each entry:
- Factors: failed/blocked status, VPN usage, unusual hours, sensitive actions
- Returns updated `AccessLog` list with `riskLevel` set

**`AnomalyDetector`** runs pattern-matching algorithms:
- Brute-force detection (N failed logins within window)
- Impossible travel (two logins from distant countries within minutes)
- Off-hours access (logins outside configured business hours)
- New device / new country flags
- Returns `List<AnomalyReport>`

### Report Generation Layer

All generators implement `BaseReportGenerator`:

```dart
abstract class BaseReportGenerator {
  Future<Uint8List> generate({
    required List<AccessLog> logs,
    required DateTime from,
    required DateTime to,
    List<AnomalyReport> anomalies = const [],
    ReportConfig? config,
  });
}
```

**`PdfGenerator`** — multi-page PDF using the `pdf` package:
- 11 sections: executive summary, risk distribution, geographic breakdown, device breakdown, heatmap, anomalies, full log table, user stats, signature lines
- Configurable via `BaseTemplate` (Corporate, GDPR, SOC 2, or custom)

**`ExcelGenerator`** — 5-sheet XLSX workbook using the `excel` package:
- Dashboard (KPIs), Full Log, High Risk, Anomalies, User Statistics

**`HtmlGenerator`** — self-contained HTML with inline CSS:
- Single-page report suitable for web display or printing

### Security & Export Layer

**`WatermarkService`** — stamps CONFIDENTIAL or custom text on PDF pages.

**`ReportSigner`** — computes SHA-256 hash of report bytes and generates a digital signature manifest.

**`HashValidator`** — verifies report integrity by comparing stored hash against a freshly-computed one.

**`LocalExporter`** — writes report bytes to a local file system path with a timestamp-based filename.

**`EmailExporter`** — sends the report as an email attachment via SMTP.

**`CloudExporter`** — uploads the report to cloud storage (S3, GCS, Azure Blob).

---

## Data Flow — `generate(format: ReportFormat.pdf)`

```
1. collector.collect(from, to)     → List<AccessLog> (raw)
2. LogProcessor.process(logs)      → List<AccessLog> (filtered + sorted)
3. RiskAnalyzer.analyze(logs)      → List<AccessLog> (with riskLevel)
4. AnomalyDetector.detect(logs)    → List<AnomalyReport>
5. DataAnonymizer.anonymize(logs)  → List<AccessLog> (PII removed, optional)
6. PdfGenerator.generate(logs, anomalies) → Uint8List (PDF bytes)
7. WatermarkService.stamp(bytes)   → Uint8List (watermarked PDF)
8. ReportSigner.sign(bytes)        → SignatureManifest (optional)
9. Return ReportResult(bytes, metadata, stats)
```

---

## Extending the Library

### Custom Log Collector

```dart
class MyDbCollector extends BaseLogCollector {
  final Database db;
  MyDbCollector(this.db);

  @override
  Future<List<AccessLog>> collect({
    required DateTime from,
    required DateTime to,
    String? userId,
    String? ipAddress,
    int? limit,
    int? offset,
  }) async {
    final rows = await db.query(
      'SELECT * FROM access_logs WHERE login_at BETWEEN ? AND ?',
      [from.toIso8601String(), to.toIso8601String()],
    );
    return rows.map(AccessLog.fromMap).toList();
  }

  @override Future<int> count({required DateTime from, required DateTime to}) async => 0;
  @override Future<bool> isAvailable() async => true;
}
```

### Custom Template

```dart
class MyBrandTemplate extends BaseTemplate {
  const MyBrandTemplate()
      : super(
          organizationName: 'My Company',
          primaryColorHex: '#0D47A1',
          secondaryColorHex: '#E3F2FD',
          accentColorHex: '#B71C1C',
          legalDisclaimer: 'CONFIDENTIAL — Internal Use Only',
        );
}
```
