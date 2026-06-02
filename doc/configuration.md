# Configuration

`ReportConfig` provides fine-grained control over how a report is generated. Pass it to `generate()`:

```dart
final result = await reporter.generate(
  from: from,
  format: ReportFormat.pdf,
  config: ReportConfig(
    maxEntries: 5000,
    minRiskLevel: RiskLevel.medium,
    referenceNumber: 'AUDIT-2024-001',
    requestedBy: 'Chief Information Security Officer',
  ),
);
```

---

## All Fields

### Filtering

| Field | Type | Default | Description |
|---|---|---|---|
| `maxEntries` | `int?` | null | Truncate to this many entries (sorted by risk, then time) |
| `minRiskLevel` | `RiskLevel` | `low` | Only include entries at or above this risk level |
| `includeAnomaliesOnly` | `bool` | `false` | Restrict output to anomalous entries only |
| `filterUserIds` | `List<String>` | `[]` | Whitelist — include only these user IDs |
| `filterIpAddresses` | `List<String>` | `[]` | Whitelist — include only these IP addresses |
| `excludeUserIds` | `List<String>` | `[]` | Blacklist — exclude these user IDs |
| `filterCountries` | `List<String>` | `[]` | Whitelist — include only these ISO country codes |
| `filterStatuses` | `List<LoginStatus>` | `[]` | Include only these login statuses |

### Report Metadata

| Field | Type | Default | Description |
|---|---|---|---|
| `referenceNumber` | `String?` | null | Audit reference ID (printed in header) |
| `requestedBy` | `String?` | null | Analyst / requester name |
| `classification` | `String?` | null | Document classification (e.g. CONFIDENTIAL) |
| `timeZone` | `String` | `'UTC'` | Timezone label for date/time display |

### Anomaly Thresholds

| Field | Type | Default | Description |
|---|---|---|---|
| `anomalyBruteForceThreshold` | `int` | `5` | Failed logins within window to trigger brute-force alert |
| `anomalyBruteForceWindowMinutes` | `int` | `15` | Brute-force detection rolling window (minutes) |
| `anomalyImpossibleTravelMinKm` | `double` | `1000` | Minimum inter-login distance for impossible-travel flag (km) |
| `anomalyImpossibleTravelMaxHours` | `double` | `2` | Maximum hours between logins for impossible-travel check |

### Risk Scoring

| Field | Type | Default | Description |
|---|---|---|---|
| `riskWeightVpn` | `double` | `0.3` | Weight added to risk score for VPN logins |
| `riskWeightFailedAuth` | `double` | `0.5` | Weight for failed authentication attempts |
| `riskWeightSensitiveAction` | `double` | `0.4` | Weight per sensitive action in session |
| `riskWeightNewCountry` | `double` | `0.2` | Weight for first-time country login |

### Business Hours (for Off-Hours Detection)

| Field | Type | Default | Description |
|---|---|---|---|
| `businessHoursStartHour` | `int` | `8` | Start of business hours (0-23) |
| `businessHoursEndHour` | `int` | `20` | End of business hours (0-23) |

---

## Examples

### Executive summary only (high risk + anomalies)

```dart
ReportConfig(
  minRiskLevel: RiskLevel.high,
  includeAnomaliesOnly: false,
  maxEntries: 500,
  referenceNumber: 'EXEC-Q1-2024',
  requestedBy: 'CISO',
  classification: 'STRICTLY CONFIDENTIAL',
)
```

### Deep forensic audit (all entries, all risk levels)

```dart
ReportConfig(
  minRiskLevel: RiskLevel.low,
  maxEntries: 50000,
  timeZone: 'Europe/Paris',
)
```

### Single user investigation

```dart
ReportConfig(
  filterUserIds: ['u_alice123'],
  minRiskLevel: RiskLevel.low,
  referenceNumber: 'INVESTIGATION-2024-007',
)
```

### PCI-DSS scope: payment team only

```dart
ReportConfig(
  filterUserIds: paymentTeamUserIds,
  minRiskLevel: RiskLevel.low,
  referenceNumber: 'PCI-Q2-2024',
  riskWeightSensitiveAction: 0.6,  // tighter scoring for card data access
)
```
