import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../core/report_config.dart';
import '../models/access_log.dart';
import '../models/compliance_standard.dart';
import '../models/risk_level.dart';
import '../processors/anomaly_detector.dart';
import 'base_report_generator.dart';

/// Generates a professional multi-sheet Excel (.xlsx) compliance report.
///
/// ## Workbook structure (5 sheets)
///
/// | Sheet | Name               | Contents                                   |
/// |-------|--------------------|--------------------------------------------|
/// | 1     | Dashboard          | KPI boxes, metadata, period summary        |
/// | 2     | Full Access Log    | All entries with 18 columns                |
/// | 3     | High Risk Entries  | Filtered: high + critical only             |
/// | 4     | Anomaly Detection  | All [AnomalyReport] findings               |
/// | 5     | User Statistics    | Aggregated per-user metrics                |
class ExcelGenerator extends BaseReportGenerator {
  final ComplianceStandard standard;
  final String organizationName;

  static final _df = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final _sfmt = DateFormat('yyyy-MM-dd');

  // ── Colour palette ────────────────────────────────────────────────────
  static final _hdrDark = ExcelColor.fromHexString('#1A237E');
  static final _hdrMid = ExcelColor.fromHexString('#37474F');
  static final _white = ExcelColor.fromHexString('#FFFFFF');
  static final _altRow = ExcelColor.fromHexString('#F5F5F5');
  static final _critBg = ExcelColor.fromHexString('#FFEBEE');
  static final _highBg = ExcelColor.fromHexString('#FFF3E0');
  static final _medBg = ExcelColor.fromHexString('#FFFDE7');
  static final _okGreen = ExcelColor.fromHexString('#E8F5E9');
  static final _alertRed = ExcelColor.fromHexString('#B71C1C');

  /// Creates an [ExcelGenerator].
  ExcelGenerator({
    this.standard = ComplianceStandard.generic,
    this.organizationName = 'Organization',
  });

  @override
  Future<Uint8List> generate({
    required List<AccessLog> logs,
    required DateTime from,
    required DateTime to,
    List<AnomalyReport> anomalies = const [],
    ReportConfig? config,
  }) async {
    final cfg = config ?? const ReportConfig();
    final excel = Excel.createExcel();

    // Remove the default "Sheet1"
    excel.delete('Sheet1');

    _buildDashboard(excel, logs, from, to, anomalies, cfg);
    _buildFullLogSheet(excel, logs);
    _buildHighRiskSheet(excel, logs);
    _buildAnomalySheet(excel, anomalies);
    _buildUserStatsSheet(excel, logs);

    final bytes = excel.encode();
    if (bytes == null) throw StateError('Excel encoding returned null.');
    return Uint8List.fromList(bytes);
  }

  // ── Sheet 1: Dashboard ────────────────────────────────────────────────

  void _buildDashboard(
    Excel excel,
    List<AccessLog> logs,
    DateTime from,
    DateTime to,
    List<AnomalyReport> anomalies,
    ReportConfig cfg,
  ) {
    final sheet = excel['Dashboard'];

    // Title
    _mergeWrite(sheet, 0, 0, 0, 7,
        '${organizationName.toUpperCase()} — COMPLIANCE AUDIT REPORT',
        bold: true,
        fontSize: 16,
        fontColor: _white,
        bgColor: _hdrDark);

    // Metadata block
    int r = 2;
    final meta = [
      ['Compliance Standard', standard.displayName],
      ['Report Period', '${_sfmt.format(from)}  →  ${_sfmt.format(to)}'],
      ['Period Length', '${to.difference(from).inDays} days'],
      ['Generated At', _df.format(DateTime.now())],
      ['Reference', standard.reference.isEmpty ? 'N/A' : standard.reference],
      if (cfg.referenceNumber != null)
        ['Audit Ref #', cfg.referenceNumber!],
      if (cfg.requestedBy != null)
        ['Requested By', cfg.requestedBy!],
    ];
    for (final row in meta) {
      _cell(sheet, r, 0, row[0], bold: true, bgColor: ExcelColor.fromHexString('#E3F2FD'));
      _cell(sheet, r, 1, row[1]);
      r++;
    }

    r++;

    // KPI Table header
    _cell(sheet, r, 0, 'Metric', bold: true, bgColor: _hdrMid, fontColor: _white);
    _cell(sheet, r, 1, 'Value', bold: true, bgColor: _hdrMid, fontColor: _white);
    _cell(sheet, r, 2, 'Status', bold: true, bgColor: _hdrMid, fontColor: _white);
    r++;

    final uniqueUsers = logs.map((l) => l.userId).toSet().length;
    final uniqueIps = logs.map((l) => l.ipAddress).toSet().length;
    final failed = logs.where((l) => l.status == LoginStatus.failed).length;
    final blocked = logs.where((l) => l.status == LoginStatus.blocked).length;
    final critical = logs.where((l) => l.riskLevel == RiskLevel.critical).length;
    final high = logs.where((l) => l.riskLevel == RiskLevel.high).length;
    final uniqueCountries = logs.map((l) => l.country ?? '?').toSet().length;
    final vpnLogins = logs.where((l) => l.isVpn).length;

    final kpis = [
      ['Total Access Log Entries', logs.length, logs.isNotEmpty ? '✓ OK' : '⚠ No Data', logs.isEmpty ? _critBg : _okGreen],
      ['Unique Users', uniqueUsers, '—', _white],
      ['Unique IP Addresses', uniqueIps, '—', _white],
      ['Countries', uniqueCountries, uniqueCountries > 10 ? '⚠ Review' : '✓ OK', uniqueCountries > 10 ? _medBg : _okGreen],
      ['VPN / Proxy Logins', vpnLogins, vpnLogins > 0 ? '⚠ Review' : '✓ OK', vpnLogins > 0 ? _medBg : _okGreen],
      ['Failed Login Attempts', failed, failed > 10 ? '🔴 Alert' : '✓ OK', failed > 10 ? _highBg : _okGreen],
      ['Blocked Login Attempts', blocked, blocked > 0 ? '🔴 Alert' : '✓ OK', blocked > 0 ? _critBg : _okGreen],
      ['High-Risk Entries', high, high > 0 ? '🟡 Review Required' : '✓ OK', high > 0 ? _highBg : _okGreen],
      ['Critical-Risk Entries', critical, critical > 0 ? '🔴 Immediate Action' : '✓ OK', critical > 0 ? _critBg : _okGreen],
      ['Anomalies Detected', anomalies.length, anomalies.isNotEmpty ? '🔴 Investigate' : '✓ OK', anomalies.isNotEmpty ? _critBg : _okGreen],
    ];

    for (final kpi in kpis) {
      final bg = kpi[3] as ExcelColor;
      _cell(sheet, r, 0, kpi[0] as String, bgColor: bg);
      _cell(sheet, r, 1, kpi[1].toString(), bgColor: bg);
      _cell(sheet, r, 2, kpi[2] as String, bgColor: bg,
          fontColor: (kpi[2] as String).startsWith('🔴') ? _alertRed : null);
      r++;
    }
  }

  // ── Sheet 2: Full Access Log ──────────────────────────────────────────

  void _buildFullLogSheet(Excel excel, List<AccessLog> logs) {
    final sheet = excel['Full Access Log'];

    final headers = [
      '#', 'Log ID', 'User ID', 'User Name', 'Email', 'Role', 'Department',
      'IP Address', 'Country', 'City', 'VPN', 'Device', 'OS', 'Browser',
      'Login Time', 'Logout Time', 'Duration (s)', 'Action Count',
      'Sensitive Actions', 'Auth Method', 'Login Status', 'Risk Level',
      'Anomaly Flag', 'Notes',
    ];

    // Write header row
    for (var c = 0; c < headers.length; c++) {
      _cell(sheet, 0, c, headers[c],
          bold: true, bgColor: _hdrDark, fontColor: _white);
    }

    // Write data rows
    for (var i = 0; i < logs.length; i++) {
      final log = logs[i];
      final bg = _riskBg(log.riskLevel);
      final rowIdx = i + 1;

      final sensitiveCount =
          log.actions.where((a) => a.isSensitive).length;

      final values = [
        (i + 1).toString(),
        log.id,
        log.userId,
        log.userName ?? '—',
        log.userEmail ?? '—',
        log.userRole ?? '—',
        log.department ?? '—',
        log.ipAddress,
        log.country ?? '—',
        log.city ?? '—',
        log.isVpn ? 'YES' : 'No',
        log.deviceType ?? '—',
        log.operatingSystem ?? '—',
        log.browser ?? '—',
        _df.format(log.loginAt),
        log.logoutAt != null ? _df.format(log.logoutAt!) : 'Active',
        log.sessionDurationSeconds?.toString() ?? '—',
        log.actionCount.toString(),
        sensitiveCount.toString(),
        log.authMethod ?? '—',
        log.status.label,
        '${log.riskLevel.emoji} ${log.riskLevel.label}',
        log.hasAnomaly ? 'YES ⚠' : 'No',
        log.notes ?? '—',
      ];

      for (var c = 0; c < values.length; c++) {
        _cell(sheet, rowIdx, c, values[c], bgColor: bg);
      }
    }
  }

  // ── Sheet 3: High Risk Entries ────────────────────────────────────────

  void _buildHighRiskSheet(Excel excel, List<AccessLog> logs) {
    final sheet = excel['High Risk Entries'];
    final highRisk = logs
        .where((l) =>
            l.riskLevel == RiskLevel.high ||
            l.riskLevel == RiskLevel.critical)
        .toList();

    if (highRisk.isEmpty) {
      _cell(sheet, 0, 0,
          '✓  No high-risk or critical entries found in this audit period.',
          bold: true, bgColor: _okGreen);
      return;
    }

    _mergeWrite(sheet, 0, 0, 0, 5,
        '⚠  HIGH RISK ENTRIES — ${highRisk.length} entries require immediate review',
        bold: true, fontColor: _alertRed);

    final headers = [
      '#', 'User ID', 'Email', 'IP', 'Country',
      'Login Time', 'Status', 'Risk', 'Notes',
    ];
    for (var c = 0; c < headers.length; c++) {
      _cell(sheet, 1, c, headers[c],
          bold: true, bgColor: _alertRed, fontColor: _white);
    }

    for (var i = 0; i < highRisk.length; i++) {
      final log = highRisk[i];
      final bg = log.riskLevel == RiskLevel.critical ? _critBg : _highBg;
      final values = [
        (i + 1).toString(),
        log.userId,
        log.userEmail ?? '—',
        log.ipAddress,
        log.country ?? '—',
        _df.format(log.loginAt),
        log.status.label,
        '${log.riskLevel.emoji} ${log.riskLevel.label}',
        log.notes ?? '—',
      ];
      for (var c = 0; c < values.length; c++) {
        _cell(sheet, i + 2, c, values[c], bgColor: bg);
      }
    }
  }

  // ── Sheet 4: Anomaly Detection ────────────────────────────────────────

  void _buildAnomalySheet(Excel excel, List<AnomalyReport> anomalies) {
    final sheet = excel['Anomaly Detection'];

    if (anomalies.isEmpty) {
      _cell(sheet, 0, 0,
          '✓  No anomalies detected during this audit period.',
          bold: true, bgColor: _okGreen);
      return;
    }

    _mergeWrite(sheet, 0, 0, 0, 5,
        '🔴  ANOMALY DETECTION REPORT — ${anomalies.length} findings',
        bold: true, fontColor: _alertRed);

    final headers = [
      '#', 'Anomaly Type', 'Severity', 'User ID',
      'Detected At', 'Affected Logs', 'Description',
    ];
    for (var c = 0; c < headers.length; c++) {
      _cell(sheet, 1, c, headers[c],
          bold: true, bgColor: _alertRed, fontColor: _white);
    }

    for (var i = 0; i < anomalies.length; i++) {
      final a = anomalies[i];
      final bg = a.severity == RiskLevel.critical ? _critBg : _highBg;
      final values = [
        (i + 1).toString(),
        a.type.label,
        '${a.severity.emoji} ${a.severity.label}',
        a.userId ?? '—',
        _df.format(a.detectedAt),
        a.affectedLogIds.take(5).join(', '),
        a.description,
      ];
      for (var c = 0; c < values.length; c++) {
        _cell(sheet, i + 2, c, values[c], bgColor: bg);
      }
    }
  }

  // ── Sheet 5: User Statistics ──────────────────────────────────────────

  void _buildUserStatsSheet(Excel excel, List<AccessLog> logs) {
    final sheet = excel['User Statistics'];

    _mergeWrite(sheet, 0, 0, 0, 7,
        'USER ACTIVITY STATISTICS — ${logs.map((l) => l.userId).toSet().length} unique users',
        bold: true, bgColor: _hdrDark, fontColor: _white);

    final headers = [
      'User ID', 'Email', 'Role', 'Total Logins',
      'Failures', 'Total Actions', 'Sensitive Actions',
      'Unique IPs', 'Countries', 'Avg Session (min)',
      'Max Risk Level', 'Anomaly Flag',
    ];
    for (var c = 0; c < headers.length; c++) {
      _cell(sheet, 1, c, headers[c],
          bold: true, bgColor: _hdrMid, fontColor: _white);
    }

    // Aggregate per user
    final map = <String, _ExcelUserStat>{};
    for (final log in logs) {
      map.putIfAbsent(
        log.userId,
        () => _ExcelUserStat(
          userId: log.userId,
          email: log.userEmail,
          role: log.userRole,
        ),
      );
      map[log.userId]!.consume(log);
    }

    final sorted = map.values.toList()
      ..sort((a, b) => b.loginCount.compareTo(a.loginCount));

    for (var i = 0; i < sorted.length; i++) {
      final u = sorted[i];
      final bg = u.hasAnomaly
          ? _critBg
          : u.maxRisk.isAtLeast(RiskLevel.high)
              ? _highBg
              : i % 2 == 0
                  ? _white
                  : _altRow;

      final avgMins = u.avgDurationSec > 0
          ? (u.avgDurationSec / 60).toStringAsFixed(1)
          : '—';

      final values = [
        u.userId,
        u.email ?? '—',
        u.role ?? '—',
        u.loginCount.toString(),
        u.failures.toString(),
        u.totalActions.toString(),
        u.sensitiveActions.toString(),
        u.ips.length.toString(),
        u.countries.length.toString(),
        avgMins,
        '${u.maxRisk.emoji} ${u.maxRisk.label}',
        u.hasAnomaly ? 'YES ⚠' : 'No',
      ];
      for (var c = 0; c < values.length; c++) {
        _cell(sheet, i + 2, c, values[c], bgColor: bg);
      }
    }
  }

  // ── Cell helpers ──────────────────────────────────────────────────────

  void _cell(
    Sheet sheet,
    int row,
    int col,
    String value, {
    bool bold = false,
    ExcelColor? bgColor,
    ExcelColor? fontColor,
    int? fontSize,
  }) {
    final cellIndex = CellIndex.indexByColumnRow(
      columnIndex: col,
      rowIndex: row,
    );
    final cell = sheet.cell(cellIndex);
    cell.value = TextCellValue(value);
    final style = CellStyle(bold: bold, fontSize: fontSize);
    if (bgColor != null) style.backgroundColorHex = bgColor;
    if (fontColor != null) style.fontColorHex = fontColor;
    cell.cellStyle = style;
  }

  void _mergeWrite(
    Sheet sheet,
    int r1,
    int c1,
    int r2,
    int c2,
    String value, {
    bool bold = false,
    ExcelColor? bgColor,
    ExcelColor? fontColor,
    int? fontSize,
  }) {
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: c1, rowIndex: r1),
      CellIndex.indexByColumnRow(columnIndex: c2, rowIndex: r2),
    );
    _cell(sheet, r1, c1, value,
        bold: bold,
        bgColor: bgColor,
        fontColor: fontColor,
        fontSize: fontSize);
  }

  static ExcelColor _riskBg(RiskLevel level) => switch (level) {
        RiskLevel.critical => ExcelColor.fromHexString('#FFEBEE'),
        RiskLevel.high => ExcelColor.fromHexString('#FFF3E0'),
        RiskLevel.medium => ExcelColor.fromHexString('#FFFDE7'),
        RiskLevel.low => ExcelColor.fromHexString('#FFFFFF'),
      };
}

// ── Internal aggregation class ────────────────────────────────────────────

class _ExcelUserStat {
  final String userId;
  final String? email;
  final String? role;

  int loginCount = 0;
  int failures = 0;
  int totalActions = 0;
  int sensitiveActions = 0;
  int totalDurationSec = 0;
  int durationCount = 0;
  bool hasAnomaly = false;
  RiskLevel maxRisk = RiskLevel.low;
  final Set<String> ips = {};
  final Set<String> countries = {};

  _ExcelUserStat({
    required this.userId,
    this.email,
    this.role,
  });

  double get avgDurationSec =>
      durationCount > 0 ? totalDurationSec / durationCount : 0;

  void consume(AccessLog log) {
    loginCount++;
    if (log.status == LoginStatus.failed) failures++;
    totalActions += log.actionCount;
    sensitiveActions += log.actions.where((a) => a.isSensitive).length;
    if (log.sessionDurationSeconds != null) {
      totalDurationSec += log.sessionDurationSeconds!;
      durationCount++;
    }
    if (log.hasAnomaly) hasAnomaly = true;
    maxRisk = maxRisk.max(log.riskLevel);
    ips.add(log.ipAddress);
    if (log.country != null) countries.add(log.country!);
  }
}
