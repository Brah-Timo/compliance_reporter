# Anomaly Detection

`AnomalyDetector` runs a set of pattern-matching algorithms over the processed access logs to identify suspicious behaviour.

---

## Enabling Detection

Anomaly detection is enabled by default. Disable it by passing `detectAnomalies: false`:

```dart
final reporter = ComplianceReporter(
  collector: collector,
  detectAnomalies: true, // default
);
```

---

## Detection Algorithms

### 1. Brute-Force Detection

Flags a user who has N or more failed login attempts within a rolling time window.

**Default thresholds:**
- ≥ 5 failures in 15 minutes → `AnomalyType.bruteForce`, severity `high`
- ≥ 10 failures in 5 minutes → severity `critical`

### 2. Impossible Travel

Flags two successful logins from geographically distant IP addresses within a timeframe that makes physical travel impossible.

**Algorithm:**
- Compute approximate distance between two consecutive login countries
- If distance > 1000 km and time delta < 2 hours → flag as `AnomalyType.impossibleTravel`, severity `critical`

### 3. Off-Hours Access

Flags logins outside configured business hours (default: 08:00–20:00 local time).

```dart
// Configure via ReportConfig
final config = ReportConfig(
  businessHoursStart: const TimeOfDay(hour: 8, minute: 0),
  businessHoursEnd:   const TimeOfDay(hour: 20, minute: 0),
);
```

### 4. New Country Login

Flags a user logging in from a country they have never logged in from before (within the audit period).

### 5. Shared IP Address

Flags when more than N distinct users log in from the same IP address within the window — potential shared-credentials or NAT attack.

### 6. Privilege Escalation Pattern

Flags sessions where a user with a non-admin role performs admin-level sensitive actions.

---

## `AnomalyReport`

Each detected anomaly is represented as:

```dart
class AnomalyReport {
  final AnomalyType type;
  final RiskLevel severity;
  final String? userId;
  final DateTime detectedAt;
  final List<String> affectedLogIds;  // log IDs that triggered the detection
  final String description;           // human-readable summary
}
```

---

## `AnomalyType` Enum

```dart
enum AnomalyType {
  bruteForce,
  impossibleTravel,
  offHoursAccess,
  newCountryLogin,
  sharedIpAddress,
  privilegeEscalation,
  unusualSessionDuration,
}
```

---

## Accessing Anomaly Results

```dart
final result = await reporter.generate(...);

// Total anomaly count
print('Anomalies: ${result.anomaliesDetected}');

// Detailed anomaly data (not in ReportResult — query separately)
final anomalies = await detector.detect(logs);
for (final a in anomalies) {
  print('[${a.severity.name}] ${a.type.label}: ${a.description}');
  print('  User: ${a.userId ?? "multiple"} | At: ${a.detectedAt}');
  print('  Affected logs: ${a.affectedLogIds.take(5).join(", ")}');
}
```

---

## Customising Thresholds via `ReportConfig`

```dart
final config = ReportConfig(
  anomalyBruteForceThreshold: 10,          // failures to trigger
  anomalyBruteForcWindowMinutes: 10,        // window in minutes
  anomalyImpossibleTravelMinKm: 500,        // minimum distance threshold
  anomalyImpossibleTravelMaxHours: 3,       // max hours between logins
);

final result = await reporter.generate(
  from: from,
  format: ReportFormat.pdf,
  config: config,
);
```
