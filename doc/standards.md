# Compliance Standards

`ComplianceReporter` supports five regulatory frameworks plus a generic mode. The selected standard affects the report title, section headings, legal references, and which KPIs are highlighted.

---

## Available Standards

### `ComplianceStandard.generic`

A neutral compliance report with no framework-specific language. Suitable for internal audits or custom compliance programmes.

```dart
ComplianceReporter(standard: ComplianceStandard.generic)
```

---

### `ComplianceStandard.gdpr`

**General Data Protection Regulation** (EU 2016/679)

Highlights:
- Lawful basis for data processing
- Personal data access and export logs
- Data subject request tracking
- Cross-border data transfer flags (non-EU countries)
- Breach detection readiness (anomaly section)

Reference: Articles 30, 32, 33, 35

```dart
ComplianceReporter(standard: ComplianceStandard.gdpr)
```

---

### `ComplianceStandard.soc2`

**SOC 2 Type II — Trust Services Criteria**

Highlights:
- Security, Availability, Confidentiality, Processing Integrity, Privacy
- Logical and physical access controls
- Change management activity
- Incident detection and response (anomaly section)

Reference: AICPA TSC 2017

```dart
ComplianceReporter(standard: ComplianceStandard.soc2)
```

---

### `ComplianceStandard.iso27001`

**ISO/IEC 27001:2022 — Information Security Management**

Highlights:
- Access control (Clause A.9)
- Cryptography (Clause A.10)
- Physical and environmental security
- Operations security (Clause A.12)
- Incident management (Clause A.16)

```dart
ComplianceReporter(standard: ComplianceStandard.iso27001)
```

---

### `ComplianceStandard.pciDss`

**PCI-DSS v4.0 — Payment Card Industry Data Security Standard**

Highlights:
- Cardholder data access monitoring (Requirement 10)
- Strong authentication enforcement (Requirement 8)
- Failed login monitoring
- Access to system components audit trail

Reference: PCI DSS v4.0 Requirements 7, 8, 10

```dart
ComplianceReporter(standard: ComplianceStandard.pciDss)
```

---

### `ComplianceStandard.hipaa`

**HIPAA — Health Insurance Portability and Accountability Act**

Highlights:
- ePHI access monitoring
- Workforce access controls
- Audit controls (§164.312(b))
- Transmission security
- Breach notification readiness

```dart
ComplianceReporter(standard: ComplianceStandard.hipaa)
```

---

## Accessing Standard Metadata

```dart
final std = ComplianceStandard.gdpr;
print(std.displayName);   // → 'GDPR — General Data Protection Regulation'
print(std.reference);     // → 'EU 2016/679 Articles 30, 32'
print(std.shortName);     // → 'GDPR'
```

---

## Template Binding

Each standard has a corresponding default PDF template:

| Standard | Default Template |
|---|---|
| `generic` | `CorporateTemplate` |
| `gdpr` | `GdprTemplate` |
| `soc2` | `Soc2Template` |
| `iso27001` | `CorporateTemplate` |
| `pciDss` | `CorporateTemplate` |
| `hipaa` | `CorporateTemplate` |

Override the template by passing a custom `PdfGenerator`:

```dart
final generator = PdfGenerator(
  template: MyBrandTemplate(),
  standard: ComplianceStandard.soc2,
);
```
