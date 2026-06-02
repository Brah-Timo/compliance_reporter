# Examples

Runnable code samples demonstrating common `compliance_reporter` use-cases.

---

## 1. Minimal — Generate a PDF Report from In-Memory Logs

```dart
import 'package:compliance_reporter/compliance_reporter.dart';

Future<void> main() async {
  // 1. Create a reporter
  final reporter = ComplianceReporter(
    organizationName: 'Acme Corp',
    standard: ComplianceStandard.generic,
  );

  // 2. Add an in-memory collector with sample logs
  final collector = MemoryLogCollector();
  collector.addAll([
    AccessLog(
      id: '001',
      userId: 'u1',
      userEmail: 'alice@acme.com',
      ipAddress: '203.0.113.10',
      loginAt: DateTime.now().subtract(const Duration(hours: 2)),
      status: SessionStatus.success,
      riskLevel: RiskLevel.low,
      actionCount: 12,
    ),
    AccessLog(
      id: '002',
      userId: 'u2',
      userEmail: 'bob@acme.com',
      ipAddress: '198.51.100.99',
      loginAt: DateTime.now().subtract(const Duration(hours: 1)),
      status: SessionStatus.failure,
      riskLevel: RiskLevel.high,
      actionCount: 0,
    ),
  ]);
  reporter.addCollector(collector);

  // 3. Generate
  final result = await reporter.generate(
    from: DateTime.now().subtract(const Duration(days: 7)),
    to: DateTime.now(),
    formats: [ReportFormat.pdf],
  );

  // 4. Save locally
  final exporter = LocalExporter(outputDir: './reports');
  final paths = await exporter.export(result);
  print('PDF saved to: ${paths.first}');
}
```

---

## 2. GDPR Compliance Report — PDF + Excel + HTML

```dart
import 'package:compliance_reporter/compliance_reporter.dart';

Future<void> main() async {
  final reporter = ComplianceReporter(
    organizationName: 'EU DataCo GmbH',
    standard: ComplianceStandard.gdpr,
  );

  // File-based collector — reads JSON lines from disk
  reporter.addCollector(
    FileLogCollector(filePath: '/var/log/access/access-2025-06.jsonl'),
  );

  final config = ReportConfig(
    includeAnomalyDetection: true,
    anonymizeUserData: true,           // GDPR: hash PII in report
    maxRiskThreshold: RiskLevel.medium, // only medium+ events
    reportTitle: 'GDPR Monthly Access Review',
  );

  final result = await reporter.generate(
    from: DateTime(2025, 6, 1),
    to: DateTime(2025, 6, 30, 23, 59, 59),
    formats: [ReportFormat.pdf, ReportFormat.excel, ReportFormat.html],
    config: config,
  );

  final exporter = LocalExporter(outputDir: '/reports/gdpr/2025-06');
  final paths = await exporter.export(result);

  for (final p in paths) {
    print('Exported: $p');
  }
}
```

---

## 3. HTTP Collector — Pull Logs from a REST API

```dart
import 'package:compliance_reporter/compliance_reporter.dart';

Future<void> main() async {
  final reporter = ComplianceReporter(
    organizationName: 'SaaS Platform Inc.',
    standard: ComplianceStandard.soc2,
  );

  // HTTP collector — fetches paginated logs from your SIEM/API
  reporter.addCollector(
    HttpLogCollector(
      baseUrl: 'https://api.internal/v1/audit-logs',
      headers: {'Authorization': 'Bearer ${const String.fromEnvironment('API_TOKEN')}'},
      pageSize: 500,
    ),
  );

  final result = await reporter.generate(
    from: DateTime.now().subtract(const Duration(days: 30)),
    to: DateTime.now(),
    formats: [ReportFormat.pdf],
  );

  // Email the report
  final emailer = EmailExporter(
    smtpHost: 'smtp.internal',
    smtpPort: 587,
    username: 'reports@saasplatform.com',
    password: const String.fromEnvironment('SMTP_PASS'),
    recipients: ['ciso@saasplatform.com', 'compliance@saasplatform.com'],
    subject: 'SOC 2 Monthly Access Report',
  );
  await emailer.export(result);
  print('Report emailed.');
}
```

---

## 4. Database Collector — Read from SQLite / PostgreSQL

```dart
import 'package:compliance_reporter/compliance_reporter.dart';
import 'package:sqlite3/sqlite3.dart'; // your DB driver

Future<void> main() async {
  final reporter = ComplianceReporter(
    organizationName: 'FinServ Ltd',
    standard: ComplianceStandard.pciDss,
  );

  // Implement DatabaseLogCollector to query your schema
  reporter.addCollector(
    DatabaseLogCollector(
      queryLogs: (from, to) async {
        final db = sqlite3.open('/data/audit.db');
        final rows = db.select(
          'SELECT * FROM access_log WHERE login_at BETWEEN ? AND ? ORDER BY login_at',
          [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
        );
        return rows.map((r) => AccessLog.fromJson(Map<String, dynamic>.from(r))).toList();
      },
    ),
  );

  final result = await reporter.generate(
    from: DateTime(2025, 5, 1),
    to: DateTime(2025, 5, 31),
    formats: [ReportFormat.excel],
  );

  final exporter = LocalExporter(outputDir: './reports');
  await exporter.export(result);
}
```

---

## 5. Anomaly Detection — Alert on High-Risk Behaviour

```dart
import 'package:compliance_reporter/compliance_reporter.dart';

Future<void> main() async {
  final reporter = ComplianceReporter(
    organizationName: 'TechStartup',
    standard: ComplianceStandard.iso27001,
  );

  reporter.addCollector(
    FileLogCollector(filePath: 'logs/access.json'),
  );

  final result = await reporter.generate(
    from: DateTime.now().subtract(const Duration(hours: 24)),
    to: DateTime.now(),
    formats: [ReportFormat.pdf],
    config: const ReportConfig(
      includeAnomalyDetection: true,
      bruteForceThreshold: 5,           // 5 failures → brute force
      impossibleTravelSpeedKmh: 900,    // 900 km/h max
      offHoursStart: 22,                // 10 PM
      offHoursEnd: 6,                   // 6 AM
    ),
  );

  // Inspect anomalies before export
  if (result.anomalyReports.isNotEmpty) {
    print('⚠️  ${result.anomalyReports.length} anomalies detected:');
    for (final a in result.anomalyReports) {
      print('  [${a.severity.label}] ${a.type}: ${a.description}');
    }
  }

  final exporter = LocalExporter(outputDir: './reports');
  await exporter.export(result);
}
```

---

## 6. Digital Signature + Integrity Hashing

```dart
import 'package:compliance_reporter/compliance_reporter.dart';

Future<void> main() async {
  final reporter = ComplianceReporter(
    organizationName: 'Regulated Corp',
    standard: ComplianceStandard.hipaa,
  );
  reporter.addCollector(MemoryLogCollector()..addAll(await _loadLogs()));

  final result = await reporter.generate(
    from: DateTime(2025, 1, 1),
    to: DateTime(2025, 3, 31),
    formats: [ReportFormat.pdf],
    config: ReportConfig(
      signReport: true,
      signerName: 'Dr. Jane Smith',
      signerTitle: 'Chief Compliance Officer',
    ),
  );

  // Verify integrity after export
  final exporter = LocalExporter(outputDir: './reports');
  final paths = await exporter.export(result);

  final validator = HashValidator();
  for (final path in paths) {
    final record = await validator.computeFile(path);
    print('SHA-256 ${record.sha256}  ${record.byteCount} bytes');
  }
}

Future<List<AccessLog>> _loadLogs() async => []; // your data source
```

---

## 7. Multiple Collectors — Merge Logs from Several Sources

```dart
import 'package:compliance_reporter/compliance_reporter.dart';

Future<void> main() async {
  final reporter = ComplianceReporter(
    organizationName: 'Enterprise Inc.',
    standard: ComplianceStandard.soc2,
  );

  // Combine on-prem + cloud + legacy sources
  reporter
    ..addCollector(FileLogCollector(filePath: '/logs/onprem/access.jsonl'))
    ..addCollector(
      HttpLogCollector(
        baseUrl: 'https://cloud-api.example.com/logs',
        headers: {'X-API-Key': 'secret'},
      ),
    )
    ..addCollector(MemoryLogCollector()..addAll(await _legacyLogs()));

  final result = await reporter.generate(
    from: DateTime.now().subtract(const Duration(days: 90)),
    to: DateTime.now(),
    formats: [ReportFormat.pdf, ReportFormat.excel],
  );

  final exporter = LocalExporter(outputDir: './quarterly-reports');
  final paths = await exporter.export(result);
  print('Generated ${paths.length} files.');
}

Future<List<AccessLog>> _legacyLogs() async => [];
```

---

## 8. Cloud Export — Upload to S3 / GCS

```dart
import 'package:compliance_reporter/compliance_reporter.dart';

Future<void> main() async {
  final reporter = ComplianceReporter(
    organizationName: 'CloudNative Co.',
    standard: ComplianceStandard.generic,
  );
  reporter.addCollector(FileLogCollector(filePath: 'logs/access.json'));

  final result = await reporter.generate(
    from: DateTime.now().subtract(const Duration(days: 30)),
    to: DateTime.now(),
    formats: [ReportFormat.pdf],
  );

  // Upload to S3-compatible storage
  final cloudExporter = CloudExporter(
    endpoint: 'https://s3.amazonaws.com',
    bucket: 'compliance-reports',
    prefix: 'reports/2025/06/',
    accessKey: const String.fromEnvironment('AWS_ACCESS_KEY'),
    secretKey: const String.fromEnvironment('AWS_SECRET_KEY'),
  );
  final urls = await cloudExporter.export(result);
  print('Uploaded to: ${urls.join(', ')}');
}
```

---

## 9. Custom `AccessLog.fromJson` Parser

If your API returns a non-standard schema, supply a `customParser`:

```dart
reporter.addCollector(
  HttpLogCollector(
    baseUrl: 'https://legacy-siem.example.com/api/events',
    headers: {'Authorization': 'Basic $credentials'},
    customParser: (json) => AccessLog(
      id: json['event_id'] as String,
      userId: json['actor_id'] as String,
      userEmail: json['actor_email'] as String?,
      ipAddress: json['source_ip'] as String,
      loginAt: DateTime.parse(json['occurred_at'] as String),
      status: (json['result'] == 'allowed')
          ? SessionStatus.success
          : SessionStatus.failure,
      riskLevel: RiskLevel.fromLabel(json['severity'] as String? ?? 'low'),
      actionCount: (json['actions'] as List?)?.length ?? 0,
    ),
  ),
);
```

---

## 10. Flutter Integration — Generate and Display a Report In-App

```dart
// In your Flutter widget:
import 'package:compliance_reporter/compliance_reporter.dart';
import 'package:printing/printing.dart';

Future<void> _generateAndPreview(BuildContext context) async {
  final reporter = ComplianceReporter(
    organizationName: 'My App',
    standard: ComplianceStandard.generic,
  );
  reporter.addCollector(MemoryLogCollector()..addAll(_localLogs));

  final result = await reporter.generate(
    from: DateTime.now().subtract(const Duration(days: 7)),
    to: DateTime.now(),
    formats: [ReportFormat.pdf],
  );

  // Use the `printing` package for in-app preview / print
  await Printing.layoutPdf(
    onLayout: (_) async => result.pdfBytes!,
    name: result.metadata.reportId,
  );
}
```

---

## See Also

- [Getting Started](getting_started.md)
- [API Reference](api_reference.md)
- [Configuration](configuration.md)
- [Anomaly Detection](anomaly_detection.md)
- [Risk Analysis](risk_analysis.md)
- [Generators](generators.md)
