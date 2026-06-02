# API Reference

Complete public API for Compliance Reporter 1.0.0.

---

## `ComplianceReporter`

The main entry point. Configure once and call `generate()`.

### Constructor

```dart
ComplianceReporter({
  required BaseLogCollector collector,
  String organizationName = 'Organization',
  ComplianceStandard standard = ComplianceStandard.generic,
  bool detectAnomalies = true,
  bool anonymizeSensitiveData = false,
  bool enableWatermark = false,
  bool enableDigitalSignature = false,
})
```

### `generate()`

```dart
Future<ReportResult> generate({
  required DateTime from,
  DateTime? to,           // defaults to DateTime.now()
  ReportFormat format = ReportFormat.pdf,
  ReportConfig? config,
})
```

Collects logs, runs anomaly detection and risk analysis, generates the report, and returns a `ReportResult`. Throws `InvalidDateRangeException` if `from > to`, `NoDataFoundException` if no logs are collected.

---

## `ReportResult`

| Field | Type | Description |
|---|---|---|
| `bytes` | `Uint8List` | Raw report bytes (PDF, XLSX, or HTML) |
| `format` | `ReportFormat` | The format that was generated |
| `reportId` | `String` | UUID v4 unique report identifier |
| `generatedAt` | `DateTime` | UTC generation timestamp |
| `generationDuration` | `Duration` | Wall-clock time to generate |
| `totalEntries` | `int` | Total log entries processed |
| `uniqueUsers` | `int` | Distinct user IDs in the logs |
| `highRiskCount` | `int` | Entries with `high` or `critical` risk |
| `anomaliesDetected` | `int` | Number of anomaly reports generated |
| `standard` | `ComplianceStandard` | Compliance standard applied |
| `metadata` | `ReportMetadata` | Organisation, period, analyst info |

---

## `ReportConfig`

Optional per-generation config passed to `generate(config: ...)`.

| Field | Type | Default | Description |
|---|---|---|---|
| `maxEntries` | `int?` | null | Truncate logs to this many entries |
| `minRiskLevel` | `RiskLevel` | `low` | Only include entries at or above this level |
| `includeAnomaliesOnly` | `bool` | `false` | Filter to anomalous entries only |
| `referenceNumber` | `String?` | null | Audit reference number (printed in header) |
| `requestedBy` | `String?` | null | Analyst name (printed in header) |
| `filterUserIds` | `List<String>` | `[]` | Include only these user IDs |
| `filterIpAddresses` | `List<String>` | `[]` | Include only these IP addresses |
| `excludeUserIds` | `List<String>` | `[]` | Exclude these user IDs |
| `timeZone` | `String` | `'UTC'` | Timezone label for date formatting |

---

## `AccessLog`

Represents one user session / access event.

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | `String` | ✓ | Unique log entry ID |
| `userId` | `String` | ✓ | User identifier |
| `ipAddress` | `String` | ✓ | Client IP address |
| `loginAt` | `DateTime` | ✓ | Session start timestamp |
| `userName` | `String?` | | Display name |
| `userEmail` | `String?` | | Email address |
| `userRole` | `String?` | | Role (admin, user, etc.) |
| `department` | `String?` | | Organisational department |
| `country` | `String?` | | ISO country code |
| `city` | `String?` | | City name |
| `isVpn` | `bool` | | True if request came via VPN/proxy |
| `deviceType` | `String?` | | Desktop / Mobile / Tablet / API |
| `operatingSystem` | `String?` | | OS name and version |
| `browser` | `String?` | | Browser name and version |
| `logoutAt` | `DateTime?` | | Session end timestamp (null = active) |
| `authMethod` | `String?` | | password / mfa / sso / api_key |
| `status` | `LoginStatus` | | success / failed / blocked |
| `actions` | `List<UserAction>` | | Actions performed during the session |
| `riskLevel` | `RiskLevel` | | Computed or manually set risk level |
| `hasAnomaly` | `bool` | | True if flagged by anomaly detector |
| `notes` | `String?` | | Free-text annotations |

---

## `UserAction`

One action performed within a session.

| Field | Type | Description |
|---|---|---|
| `action` | `String` | Action name: VIEW, EDIT, EXPORT, DELETE, etc. |
| `resourceType` | `String` | Type of resource affected |
| `timestamp` | `DateTime` | When the action occurred |
| `isSensitive` | `bool` | True for PII / financial / medical data access |
| `resourceId` | `String?` | Specific resource identifier |

---

## Enumerations

### `ReportFormat`
```dart
enum ReportFormat { pdf, excel, html }
```

### `ComplianceStandard`
```dart
enum ComplianceStandard { generic, gdpr, soc2, iso27001, pciDss, hipaa }
```

### `RiskLevel`
```dart
enum RiskLevel { low, medium, high, critical }
```

### `LoginStatus`
```dart
enum LoginStatus { success, failed, blocked }
```

---

## Exceptions

| Exception | When thrown |
|---|---|
| `ComplianceException` | General compliance processing error |
| `InvalidDateRangeException` | `from` is after `to` |
| `NoDataFoundException` | No logs collected in the date range |
| `ExportFailureException` | File system write failure in `LocalExporter` |
