# Getting Started

Generate a compliance report in 5 minutes.

---

## 1. Install

```yaml
dependencies:
  compliance_reporter: ^1.0.0
```

```bash
flutter pub get
# or
dart pub get
```

---

## 2. Prepare Access Logs

`ComplianceReporter` works with `AccessLog` objects. The simplest way is to construct them from your database records:

```dart
final logs = [
  AccessLog(
    id: 'log_001',
    userId: 'u_abc123',
    userName: 'Alice Martin',
    userEmail: 'alice@corp.com',
    userRole: 'admin',
    ipAddress: '203.0.113.5',
    country: 'US',
    loginAt: DateTime.parse('2024-01-15T09:23:00Z'),
    logoutAt: DateTime.parse('2024-01-15T17:45:00Z'),
    authMethod: 'mfa',
    status: LoginStatus.success,
    actions: [
      UserAction(
        action: 'EXPORT',
        resourceType: 'CustomerData',
        timestamp: DateTime.parse('2024-01-15T14:30:00Z'),
        isSensitive: true,
      ),
    ],
  ),
];
```

---

## 3. Configure the Reporter

```dart
final reporter = ComplianceReporter(
  // Supply logs from memory, file, database, or HTTP
  collector: MemoryLogCollector(logs: logs),

  // Your organisation name (appears in report headers)
  organizationName: 'Acme Corp',

  // Compliance framework to apply
  standard: ComplianceStandard.gdpr,

  // Optional features
  detectAnomalies: true,
  anonymizeSensitiveData: false,
  enableWatermark: true,
  enableDigitalSignature: false,
);
```

---

## 4. Generate a Report

### PDF

```dart
final result = await reporter.generate(
  from: DateTime.now().subtract(const Duration(days: 90)),
  format: ReportFormat.pdf,
);
await File('compliance_report.pdf').writeAsBytes(result.bytes);
print('Report: ${result.totalEntries} entries, ${result.uniqueUsers} users');
```

### Excel

```dart
final result = await reporter.generate(
  from: DateTime.now().subtract(const Duration(days: 90)),
  format: ReportFormat.excel,
);
await File('compliance_report.xlsx').writeAsBytes(result.bytes);
```

### HTML

```dart
final result = await reporter.generate(
  from: DateTime.now().subtract(const Duration(days: 90)),
  format: ReportFormat.html,
);
await File('compliance_report.html').writeAsString(
  String.fromCharCodes(result.bytes),
);
```

---

## 5. Save to Disk

Use `LocalExporter` to save the report file automatically:

```dart
final exporter = LocalExporter(outputDirectory: '/reports');
await exporter.export(result);
// Writes: /reports/compliance_report_2024-01-15.pdf
```

---

## 6. Read a Report Result

```dart
print('Format        : ${result.format.name}');
print('Entries       : ${result.totalEntries}');
print('Unique users  : ${result.uniqueUsers}');
print('Anomalies     : ${result.anomaliesDetected}');
print('High risk     : ${result.highRiskCount}');
print('Generated in  : ${result.generationDuration.inMilliseconds}ms');
print('Report ID     : ${result.reportId}');
```

---

## Next Steps

- [Log Collectors](collectors.md) — fetch logs from files, databases, or HTTP APIs
- [Configuration](configuration.md) — fine-grained control over filtering and thresholds
- [Compliance Standards](standards.md) — GDPR, SOC 2, ISO 27001, PCI-DSS, HIPAA
- [Examples](examples.md) — full runnable code samples
