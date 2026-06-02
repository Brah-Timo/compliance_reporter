# Report Generators

Three output formats are supported: PDF, Excel (XLSX), and HTML.

---

## PDF Generator (`PdfGenerator`)

Produces a multi-page, professionally formatted PDF using the `pdf` package.

### Structure (11 sections)

1. **Header** — organisation name, report title, date range (every page)
2. **Executive Summary** — key KPIs in coloured stat boxes
3. **Risk Distribution** — breakdown table by risk level
4. **Geographic Distribution** — top countries / cities
5. **Device & OS Breakdown** — device type distribution
6. **Hourly Activity Heatmap** — login hour distribution
7. **Anomaly Findings** — one row per `AnomalyReport` (if any)
8. **Full Access Log Table** — one row per `AccessLog`
9. **User Statistics Summary** — aggregated per-user table
10. **Signature Lines** — Prepared / Reviewed / Approved
11. **Footer** — CONFIDENTIAL notice, page X of Y (every page)

### Usage

```dart
final generator = PdfGenerator(
  template: CorporateTemplate(organizationName: 'Acme Corp'),
  standard: ComplianceStandard.soc2,
);

final bytes = await generator.generate(
  logs: processedLogs,
  from: from,
  to: to,
  anomalies: anomalyReports,
  config: reportConfig,
);
```

### Templates

| Template | Description |
|---|---|
| `CorporateTemplate` | Dark blue header, professional style |
| `GdprTemplate` | EU flag colours, GDPR boilerplate |
| `Soc2Template` | Trust Services Criteria branding |

---

## Excel Generator (`ExcelGenerator`)

Produces a 5-sheet XLSX workbook using the `excel` package.

### Sheet Structure

| Sheet # | Name | Contents |
|---|---|---|
| 1 | Dashboard | KPI boxes, metadata, period summary |
| 2 | Full Access Log | All entries with 24 columns |
| 3 | High Risk Entries | Filtered to high + critical only |
| 4 | Anomaly Detection | All `AnomalyReport` findings |
| 5 | User Statistics | Aggregated per-user metrics |

### Usage

```dart
final generator = ExcelGenerator(
  standard: ComplianceStandard.gdpr,
  organizationName: 'Acme Corp',
);

final bytes = await generator.generate(
  logs: processedLogs,
  from: from,
  to: to,
  anomalies: anomalyReports,
);

await File('report.xlsx').writeAsBytes(bytes);
```

### Colour Coding

| Risk Level | Background |
|---|---|
| `critical` | `#FFEBEE` (light red) |
| `high` | `#FFF3E0` (light orange) |
| `medium` | `#FFFDE7` (light yellow) |
| `low` | `#FFFFFF` (white) |

---

## HTML Generator (`HtmlGenerator`)

Produces a self-contained HTML file with inline CSS — no external dependencies.

### Features

- Responsive layout
- Colour-coded risk rows
- Interactive table (sorted by risk level)
- Print-optimised CSS (`@media print`)

### Usage

```dart
final generator = HtmlGenerator(
  organizationName: 'Acme Corp',
  standard: ComplianceStandard.iso27001,
);

final bytes = await generator.generate(
  logs: processedLogs,
  from: from,
  to: to,
  anomalies: anomalyReports,
);

await File('report.html').writeAsBytes(bytes);
```

---

## Choosing a Format

| Use Case | Recommended Format |
|---|---|
| Executive presentation, printing, archiving | PDF |
| Data analysis, pivot tables, filtering | Excel |
| Web display, email-friendly sharing | HTML |
| Regulatory submission | PDF (digitally signed) |
| Further programmatic processing | Excel |
