# Compliance Reporter — Documentation

A production-grade Dart/Flutter package for generating legal-grade compliance audit reports in PDF, Excel, and HTML formats. Covers GDPR, SOC 2, ISO 27001, PCI-DSS, and HIPAA. Pure Dart — works on Flutter (iOS / Android / Web / Desktop) and standalone Dart backends.

---

## Documentation Index

| Document | Description |
|---|---|
| [Getting Started](getting_started.md) | Install, configure and generate your first report in 5 minutes |
| [API Reference](api_reference.md) | Full public API: `ComplianceReporter`, `ReportConfig`, models, exceptions |
| [Architecture](architecture.md) | Component overview, data-flow, and design decisions |
| [Configuration](configuration.md) | Every `ReportConfig` field explained with examples |
| [Log Collectors](collectors.md) | Memory, File, Database, and HTTP log collectors |
| [Report Generators](generators.md) | PDF, Excel, and HTML generators |
| [Anomaly Detection](anomaly_detection.md) | Detecting brute force, impossible travel, off-hours access |
| [Risk Analysis](risk_analysis.md) | Risk scoring, thresholds, and `RiskLevel` enum |
| [Compliance Standards](standards.md) | GDPR, SOC 2, ISO 27001, PCI-DSS, HIPAA profiles |
| [Examples](examples.md) | Runnable end-to-end code samples |

---

## Quick Start

```dart
import 'package:compliance_reporter/compliance_reporter.dart';

final reporter = ComplianceReporter(
  collector: MemoryLogCollector(logs: accessLogs),
  organizationName: 'Acme Corp',
  standard: ComplianceStandard.gdpr,
);

final result = await reporter.generate(
  from: DateTime.now().subtract(const Duration(days: 30)),
  format: ReportFormat.pdf,
);

// result.bytes — the raw PDF bytes
// result.totalEntries — number of logs processed
// result.anomaliesDetected — number of anomalies found
```

---

## Package Information

- **Version**: 1.0.0
- **Dart SDK**: ≥ 3.0.0
- **License**: MIT
- **Repository**: https://github.com/your-org/compliance_reporter
