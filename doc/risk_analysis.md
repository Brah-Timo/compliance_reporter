# Risk Analysis

`compliance_reporter` ships a built-in **risk analyser** (`RiskAnalyzer`) that scores every `AccessLog` entry and aggregates session-level metrics into an overall report risk posture.

---

## Risk Levels

| Level      | Enum value           | Emoji | Meaning                                     |
|------------|----------------------|-------|---------------------------------------------|
| Low        | `RiskLevel.low`      | 🟢    | Normal activity, no indicators of concern   |
| Medium     | `RiskLevel.medium`   | 🟡    | Requires attention — review recommended     |
| High       | `RiskLevel.high`     | 🔴    | Significant risk — investigate promptly     |
| Critical   | `RiskLevel.critical` | ⛔    | Immediate action required                   |

The `RiskLevel` enum exposes helper getters:

```dart
final level = RiskLevel.high;
print(level.label);  // "High"
print(level.emoji);  // "🔴"
print(level.index);  // 2  (ordinal, 0=low … 3=critical)

// Comparison
if (log.riskLevel >= RiskLevel.high) { ... }
```

---

## How Scores Are Computed

`RiskAnalyzer.analyse(log)` examines multiple signals and returns the **maximum** across all active rules:

### 1. Authentication Failures
| Condition                            | Assigned risk |
|--------------------------------------|---------------|
| `status == SessionStatus.failure`    | `medium`      |
| ≥ 3 failures from same IP in window  | `high`        |
| ≥ 5 failures from same IP in window  | `critical`    |

### 2. Off-Hours Access
Access outside `ReportConfig.offHoursStart`–`offHoursEnd` (default 22:00–06:00):

| Condition                            | Assigned risk |
|--------------------------------------|---------------|
| Off-hours + success                  | `medium`      |
| Off-hours + failure                  | `high`        |

### 3. Geographic Signals
| Condition                                           | Assigned risk |
|-----------------------------------------------------|---------------|
| `isVpn == true`                                     | `medium`      |
| Country in `ReportConfig.highRiskCountries`         | `high`        |
| `isTorExitNode == true`                             | `critical`    |

### 4. Impossible Travel
Two logins from the same `userId` where the implied travel speed between `ipAddress` geo-locations exceeds `ReportConfig.impossibleTravelSpeedKmh` (default 900 km/h):

| Condition                            | Assigned risk |
|--------------------------------------|---------------|
| Speed > threshold                    | `critical`    |

### 5. Brute-Force Heuristic
Distinct failure events per `userId` within the analysis window:

| Failures  | Assigned risk |
|-----------|---------------|
| ≥ 5       | `high`        |
| ≥ 10      | `critical`    |

### 6. Session Anomalies
| Condition                                             | Assigned risk |
|-------------------------------------------------------|---------------|
| `actionCount == 0` with `status == success`           | `medium`      |
| `sessionDurationSeconds` > 86 400 (24 h)              | `medium`      |
| `actionCount` > 1 000 in single session               | `high`        |

---

## Aggregated Report Risk Score

After all entries are scored, `RiskAnalyzer.aggregateRisk(logs)` returns an `AggregateRiskScore`:

```dart
class AggregateRiskScore {
  final RiskLevel overall;         // max level across all logs
  final int criticalCount;
  final int highCount;
  final int mediumCount;
  final int lowCount;
  final double riskPercentage;     // (high + critical) / total * 100
  final List<String> topRiskUsers; // up to 5 userId with highest counts
  final List<String> topRiskIPs;   // up to 5 IPs with highest failure counts
}
```

### `overall` derivation

```
overall = critical  if criticalCount > 0
        = high      if highCount > 0
        = medium    if mediumCount > 0
        = low       otherwise
```

---

## Using `RiskAnalyzer` Directly

```dart
import 'package:compliance_reporter/compliance_reporter.dart';

void main() {
  final analyzer = RiskAnalyzer(
    config: ReportConfig(
      highRiskCountries: ['CN', 'RU', 'KP'],
      bruteForceThreshold: 5,
      impossibleTravelSpeedKmh: 900,
      offHoursStart: 22,
      offHoursEnd: 6,
    ),
  );

  final logs = <AccessLog>[/* ... */];

  // Score a single log
  for (final log in logs) {
    final level = analyzer.analyse(log);
    print('${log.id} → ${level.label}');
  }

  // Aggregate
  final score = analyzer.aggregateRisk(logs);
  print('Overall risk: ${score.overall.label}');
  print('Risk %: ${score.riskPercentage.toStringAsFixed(1)}%');
  print('Top risk users: ${score.topRiskUsers.join(', ')}');
}
```

---

## Configuring Risk Thresholds

All thresholds live in `ReportConfig`:

```dart
const config = ReportConfig(
  // Only include entries at or above this level in the report
  maxRiskThreshold: RiskLevel.medium,

  // Countries that automatically raise risk to "high"
  highRiskCountries: ['CN', 'RU', 'KP', 'IR'],

  // km/h above which two consecutive logins are "impossible travel"
  impossibleTravelSpeedKmh: 900,

  // Authentication failures per user/IP before brute-force flag
  bruteForceThreshold: 5,

  // Off-hours window (24h clock)
  offHoursStart: 22,   // 10 PM
  offHoursEnd: 6,      // 6 AM
);
```

---

## Risk Breakdown in Generated Reports

### PDF
- **Executive Summary** page shows colour-coded risk KPI boxes (critical / high / medium / low counts).
- **Full Access Log** table colour-codes each row by risk level.
- **High-Risk Entries** section lists only `high` and `critical` rows.

### Excel
- **Dashboard** sheet shows risk KPI boxes with conditional background colours.
- **High Risk Entries** sheet is pre-filtered to show only elevated entries.
- **Full Access Log** rows are colour-coded: red (`critical`), orange (`high`), yellow (`medium`), green (`low`).

### HTML
- Summary cards display risk counts with Bootstrap badge colours.
- Table rows carry CSS classes `risk-critical`, `risk-high`, `risk-medium`, `risk-low` for custom styling.

---

## Risk Model Extension

To customise scoring, subclass `RiskAnalyzer` and override `analyse`:

```dart
class MyRiskAnalyzer extends RiskAnalyzer {
  MyRiskAnalyzer({super.config});

  @override
  RiskLevel analyse(AccessLog log) {
    final base = super.analyse(log);
    // Promote any VPN access to high
    if (log.isVpn && base < RiskLevel.high) return RiskLevel.high;
    // Internal IPs are always low
    if (log.ipAddress.startsWith('10.')) return RiskLevel.low;
    return base;
  }
}
```

Then inject it via `ComplianceReporter`:

```dart
final reporter = ComplianceReporter(
  organizationName: 'Acme',
  standard: ComplianceStandard.soc2,
  riskAnalyzer: MyRiskAnalyzer(config: myConfig),
);
```

---

## See Also

- [Anomaly Detection](anomaly_detection.md)
- [Configuration](configuration.md)
- [Examples](examples.md)
- [API Reference](api_reference.md)
