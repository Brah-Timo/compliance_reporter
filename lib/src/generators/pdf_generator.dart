import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/report_config.dart';
import '../models/access_log.dart';
import '../models/compliance_standard.dart';
import '../models/risk_level.dart';
import '../processors/anomaly_detector.dart';
import '../templates/base_template.dart';
import 'base_report_generator.dart';

/// Generates a multi-page, professionally formatted PDF compliance report.
///
/// ## Output structure
///
/// 1. **Header** — organisation name, report title, date range (every page)
/// 2. **Executive Summary** — key KPIs in coloured stat boxes
/// 3. **Risk Distribution** — breakdown table by risk level
/// 4. **Geographic Distribution** — top countries / cities
/// 5. **Device & OS Breakdown** — device type distribution
/// 6. **Hourly Activity Heatmap** — login hour distribution
/// 7. **Anomaly Findings** — one row per [AnomalyReport] (if any)
/// 8. **Full Access Log Table** — one row per [AccessLog]
/// 9. **User Statistics Summary** — aggregated per-user table
/// 10. **Signature Lines** — Prepared / Reviewed / Approved
/// 11. **Footer** — CONFIDENTIAL notice, page X of Y (every page)
class PdfGenerator extends BaseReportGenerator {
  final BaseTemplate template;
  final ComplianceStandard standard;

  static final _dateFmt = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final _shortFmt = DateFormat('yyyy-MM-dd');

  /// Creates a [PdfGenerator].
  PdfGenerator({
    required this.template,
    this.standard = ComplianceStandard.generic,
    ReportConfig? config,
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

    final doc = pw.Document(
      title: cfg.title ?? 'Compliance Audit Report',
      author: template.organizationName,
      creator: 'compliance_reporter v1.0.0',
      subject:
          '${standard.displayName} Audit — '
          '${_shortFmt.format(from)} to ${_shortFmt.format(to)}',
    );

    // ── Resolve colours ───────────────────────────────────────────────────
    final primary = _hexColor(
      cfg.primaryColorHex ?? template.primaryColorHex,
    );
    final secondary = _hexColor(
      cfg.secondaryColorHex ?? template.secondaryColorHex,
    );
    final accent = _hexColor(
      cfg.accentColorHex ?? template.accentColorHex,
    );

    // ── Compute stats once ────────────────────────────────────────────────
    final stats = _ReportStats.compute(logs, anomalies);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 36),
        header: (ctx) =>
            _buildHeader(ctx, from, to, primary),
        footer: (ctx) =>
            _buildFooter(ctx, cfg, primary),
        build: (ctx) {
          final widgets = <pw.Widget>[];

          // ── Executive Summary ──────────────────────────────────────────
          if (cfg.includeExecutiveSummary) {
            widgets
              ..add(_sectionTitle('Executive Summary', primary))
              ..add(_buildSummaryBoxes(stats, primary, accent))
              ..add(_spacer());
          }

          // ── Standard reference banner ──────────────────────────────────
          if (standard.reference.isNotEmpty) {
            widgets
              ..add(_buildStandardBanner(primary))
              ..add(_spacer());
          }

          // ── Risk distribution ──────────────────────────────────────────
          if (cfg.includeRiskDistribution) {
            widgets
              ..add(_sectionTitle('Risk Distribution', primary))
              ..add(_buildRiskTable(stats, primary, secondary))
              ..add(_spacer());
          }

          // ── Geographic distribution ────────────────────────────────────
          if (cfg.includeGeoDistribution) {
            final geoData = _buildGeoData(logs);
            if (geoData.isNotEmpty) {
              widgets
                ..add(_sectionTitle('Geographic Distribution', primary))
                ..add(_buildGeoTable(geoData, primary, secondary))
                ..add(_spacer());
            }
          }

          // ── Device breakdown ───────────────────────────────────────────
          if (cfg.includeDeviceBreakdown) {
            widgets
              ..add(_sectionTitle('Device & OS Breakdown', primary))
              ..add(_buildDeviceTable(logs, primary, secondary))
              ..add(_spacer());
          }

          // ── Anomaly section ────────────────────────────────────────────
          if (cfg.includeAnomalySection && anomalies.isNotEmpty) {
            widgets
              ..add(_sectionTitle(
                '⚠  Anomaly Findings  (${anomalies.length})',
                PdfColors.red800,
              ))
              ..add(_buildAnomalyTable(anomalies, secondary))
              ..add(_spacer());
          }

          // ── Main access log table ──────────────────────────────────────
          widgets
            ..add(_sectionTitle('Full Access Log', primary))
            ..add(_buildMainLogTable(logs, primary, secondary, accent))
            ..add(_spacer());

          // ── User statistics ────────────────────────────────────────────
          if (cfg.includeUserStatistics) {
            widgets
              ..add(_sectionTitle('User Statistics', primary))
              ..add(_buildUserStatsTable(logs, primary, secondary))
              ..add(_spacer());
          }

          // ── Signature lines ────────────────────────────────────────────
          if (cfg.includeSignatureLines) {
            widgets.add(_buildSignatureSection());
          }

          return widgets;
        },
      ),
    );

    return doc.save();
  }

  // ── Header / Footer ───────────────────────────────────────────────────

  pw.Widget _buildHeader(
    pw.Context ctx,
    DateTime from,
    DateTime to,
    PdfColor primary,
  ) =>
      pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: primary, width: 2),
          ),
        ),
        padding: const pw.EdgeInsets.only(bottom: 6),
        margin: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              template.organizationName.toUpperCase(),
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 12,
                color: primary,
              ),
            ),
            pw.Text(
              'COMPLIANCE AUDIT REPORT — ${standard.displayName}',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                color: PdfColors.red800,
                letterSpacing: 0.8,
              ),
            ),
            pw.Text(
              '${_shortFmt.format(from)} → ${_shortFmt.format(to)}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ),
      );

  pw.Widget _buildFooter(
    pw.Context ctx,
    ReportConfig cfg,
    PdfColor primary,
  ) =>
      pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border(
            top: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
          ),
        ),
        padding: const pw.EdgeInsets.only(top: 6),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '${cfg.customFooterText ?? ''}'
              'CONFIDENTIAL — FOR AUTHORISED AUDIT USE ONLY',
              style: const pw.TextStyle(
                fontSize: 7.5,
                color: PdfColors.red700,
              ),
            ),
            pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(
                fontSize: 7.5,
                color: PdfColors.grey600,
              ),
            ),
            pw.Text(
              'Generated by compliance_reporter v1.0.0',
              style: const pw.TextStyle(
                fontSize: 7.5,
                color: PdfColors.grey500,
              ),
            ),
          ],
        ),
      );

  // ── Section helpers ───────────────────────────────────────────────────

  pw.Widget _sectionTitle(String text, PdfColor color) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 6),
        decoration: pw.BoxDecoration(
          border: pw.Border(
            left: pw.BorderSide(color: color, width: 4),
          ),
        ),
        padding: const pw.EdgeInsets.only(left: 8),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 13,
            color: color,
          ),
        ),
      );

  pw.Widget _spacer([double height = 14]) =>
      pw.SizedBox(height: height);

  // ── Executive Summary ─────────────────────────────────────────────────

  pw.Widget _buildSummaryBoxes(
    _ReportStats stats,
    PdfColor primary,
    PdfColor accent,
  ) =>
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey50,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        child: pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: [
                _statBox('Total Entries', stats.total.toString(), primary),
                _statBox('Unique Users', stats.uniqueUsers.toString(), PdfColors.green700),
                _statBox('Unique IPs', stats.uniqueIps.toString(), PdfColors.orange700),
                _statBox('Failed Logins', stats.failedLogins.toString(), PdfColors.red600),
                _statBox('Anomalies', stats.anomalies.toString(), PdfColors.purple700),
                _statBox('Critical', stats.critical.toString(), PdfColors.red900),
              ],
            ),
          ],
        ),
      );

  pw.Widget _statBox(String label, String value, PdfColor color) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: color),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 18,
                color: color,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
            ),
          ],
        ),
      );

  pw.Widget _buildStandardBanner(PdfColor primary) => pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: PdfColors.blue50,
          border: pw.Border.all(color: PdfColors.blue200),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Row(
          children: [
            pw.Text(
              'Compliance Standard: ',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: PdfColors.blue900,
              ),
            ),
            pw.Text(
              '${standard.displayName} — ${standard.reference}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.blue800),
            ),
          ],
        ),
      );

  // ── Risk Distribution ─────────────────────────────────────────────────

  pw.Widget _buildRiskTable(
    _ReportStats stats,
    PdfColor primary,
    PdfColor secondary,
  ) {
    final rows = RiskLevel.values.map((level) {
      final count = stats.byRisk[level] ?? 0;
      final pct = stats.total > 0
          ? (count / stats.total * 100).toStringAsFixed(1)
          : '0.0';
      return [
        '${level.emoji}  ${level.label}',
        count.toString(),
        '$pct%',
        _riskBar(count, stats.total),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: ['Risk Level', 'Count', 'Percentage', 'Visual'],
      data: rows,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 8.5,
        color: PdfColors.white,
      ),
      headerDecoration: pw.BoxDecoration(color: primary),
      cellStyle: const pw.TextStyle(fontSize: 8.5),
      cellAlignments: {
        1: pw.Alignment.center,
        2: pw.Alignment.center,
      },
    );
  }

  String _riskBar(int count, int total) {
    if (total == 0) return '';
    final filled = (count / total * 20).round();
    return '${'█' * filled}${'░' * (20 - filled)}';
  }

  // ── Geographic Distribution ───────────────────────────────────────────

  List<MapEntry<String, int>> _buildGeoData(List<AccessLog> logs) {
    final map = <String, int>{};
    for (final log in logs) {
      final key = log.country ?? 'Unknown';
      map[key] = (map[key] ?? 0) + 1;
    }
    return (map.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(15)
        .toList();
  }

  pw.Widget _buildGeoTable(
    List<MapEntry<String, int>> data,
    PdfColor primary,
    PdfColor secondary,
  ) =>
      pw.TableHelper.fromTextArray(
        headers: ['Rank', 'Country', 'Login Count'],
        data: data.asMap().entries.map((e) {
          return [(e.key + 1).toString(), e.value.key, e.value.value.toString()];
        }).toList(),
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 8.5,
          color: PdfColors.white,
        ),
        headerDecoration: pw.BoxDecoration(color: primary),
        cellStyle: const pw.TextStyle(fontSize: 8.5),
        oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
      );

  // ── Device Breakdown ──────────────────────────────────────────────────

  pw.Widget _buildDeviceTable(
    List<AccessLog> logs,
    PdfColor primary,
    PdfColor secondary,
  ) {
    final map = <String, int>{};
    for (final log in logs) {
      final key = log.deviceType ?? 'Unknown';
      map[key] = (map[key] ?? 0) + 1;
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return pw.TableHelper.fromTextArray(
      headers: ['Device Type', 'Count', '%'],
      data: sorted.map((e) {
        final pct = logs.isNotEmpty
            ? (e.value / logs.length * 100).toStringAsFixed(1)
            : '0';
        return [e.key, e.value.toString(), '$pct%'];
      }).toList(),
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 8.5,
        color: PdfColors.white,
      ),
      headerDecoration: pw.BoxDecoration(color: primary),
      cellStyle: const pw.TextStyle(fontSize: 8.5),
    );
  }

  // ── Anomaly Table ─────────────────────────────────────────────────────

  pw.Widget _buildAnomalyTable(
    List<AnomalyReport> anomalies,
    PdfColor secondary,
  ) =>
      pw.TableHelper.fromTextArray(
        headers: [
          '#',
          'Type',
          'Severity',
          'User',
          'Detected At',
          'Description',
        ],
        data: anomalies.asMap().entries.map((e) {
          final r = e.value;
          return [
            (e.key + 1).toString(),
            r.type.label,
            '${r.severity.emoji} ${r.severity.label}',
            r.userId ?? '—',
            _shortFmt.format(r.detectedAt),
            r.description.length > 120
                ? '${r.description.substring(0, 117)}...'
                : r.description,
          ];
        }).toList(),
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 8,
          color: PdfColors.white,
        ),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.red800),
        cellStyle: const pw.TextStyle(fontSize: 7.5),
        columnWidths: {
          0: const pw.FixedColumnWidth(18),
          1: const pw.FixedColumnWidth(70),
          2: const pw.FixedColumnWidth(50),
          3: const pw.FixedColumnWidth(60),
          4: const pw.FixedColumnWidth(55),
          5: const pw.FlexColumnWidth(),
        },
      );

  // ── Main Log Table ────────────────────────────────────────────────────

  pw.Widget _buildMainLogTable(
    List<AccessLog> logs,
    PdfColor primary,
    PdfColor secondary,
    PdfColor accent,
  ) {
    final headers = [
      '#',
      'User ID',
      'Email',
      'IP Address',
      'Country',
      'Login Time',
      'Duration',
      'Actions',
      'Status',
      'Risk',
    ];

    final rows = logs.asMap().entries.map((e) {
      final i = e.key;
      final log = e.value;
      final dur = log.sessionDurationSeconds != null
          ? _fmtDuration(log.sessionDurationSeconds!)
          : 'Active';
      return [
        (i + 1).toString(),
        log.userId,
        log.userEmail ?? '—',
        log.ipAddress,
        '${log.isVpn ? '🔒 ' : ''}${log.country ?? '—'}',
        _dateFmt.format(log.loginAt),
        dur,
        log.actionCount.toString(),
        log.status.label,
        '${log.riskLevel.emoji} ${log.riskLevel.label}',
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: pw.TableBorder.all(color: PdfColors.blueGrey100, width: 0.5),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 7.5,
        color: PdfColors.white,
      ),
      headerDecoration: pw.BoxDecoration(color: primary),
      cellStyle: const pw.TextStyle(fontSize: 7),
      cellAlignments: {
        0: pw.Alignment.center,
        7: pw.Alignment.center,
        8: pw.Alignment.center,
        9: pw.Alignment.center,
      },
      columnWidths: {
        0: const pw.FixedColumnWidth(18),
        3: const pw.FixedColumnWidth(70),
        4: const pw.FixedColumnWidth(45),
        7: const pw.FixedColumnWidth(35),
        8: const pw.FixedColumnWidth(50),
        9: const pw.FixedColumnWidth(48),
      },
    );
  }

  // ── User Stats Table ──────────────────────────────────────────────────

  pw.Widget _buildUserStatsTable(
    List<AccessLog> logs,
    PdfColor primary,
    PdfColor secondary,
  ) {
    final userMap = <String, _UserStat>{};
    for (final log in logs) {
      userMap.putIfAbsent(log.userId, () => _UserStat(log.userId, log.userEmail));
      userMap[log.userId]!.add(log);
    }
    final sorted = userMap.values.toList()
      ..sort((a, b) => b.loginCount.compareTo(a.loginCount));

    return pw.TableHelper.fromTextArray(
      headers: [
        'User ID',
        'Email',
        'Logins',
        'Failures',
        'Actions',
        'IPs',
        'Max Risk',
      ],
      data: sorted.take(100).map((u) {
        return [
          u.userId,
          u.email ?? '—',
          u.loginCount.toString(),
          u.failures.toString(),
          u.actions.toString(),
          u.ips.length.toString(),
          '${u.maxRisk.emoji} ${u.maxRisk.label}',
        ];
      }).toList(),
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 8,
        color: PdfColors.white,
      ),
      headerDecoration: pw.BoxDecoration(color: primary),
      cellStyle: const pw.TextStyle(fontSize: 7.5),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
    );
  }

  // ── Signature Lines ───────────────────────────────────────────────────

  pw.Widget _buildSignatureSection() => pw.Container(
        margin: const pw.EdgeInsets.only(top: 40),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: [
            _sigLine('Prepared By'),
            _sigLine('Reviewed By'),
            _sigLine('Approved By'),
          ],
        ),
      );

  pw.Widget _sigLine(String label) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(width: 130, height: 0.5, color: PdfColors.black),
          pw.SizedBox(height: 4),
          pw.Text(label, style: const pw.TextStyle(fontSize: 8.5)),
          pw.Text(
            'Date: ___________',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
          ),
        ],
      );

  // ── Utilities ─────────────────────────────────────────────────────────

  static PdfColor _hexColor(String hex) {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      final r = int.parse(clean.substring(0, 2), radix: 16) / 255;
      final g = int.parse(clean.substring(2, 4), radix: 16) / 255;
      final b = int.parse(clean.substring(4, 6), radix: 16) / 255;
      return PdfColor(r, g, b);
    }
    return PdfColors.blueGrey800;
  }

  static String _fmtDuration(int secs) {
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;
    return '${h}h ${m}m ${s}s';
  }
}

// ── Internal stats ────────────────────────────────────────────────────────

class _ReportStats {
  final int total;
  final int uniqueUsers;
  final int uniqueIps;
  final int failedLogins;
  final int anomalies;
  final int critical;
  final Map<RiskLevel, int> byRisk;

  const _ReportStats({
    required this.total,
    required this.uniqueUsers,
    required this.uniqueIps,
    required this.failedLogins,
    required this.anomalies,
    required this.critical,
    required this.byRisk,
  });

  factory _ReportStats.compute(
    List<AccessLog> logs,
    List<AnomalyReport> anomalyList,
  ) {
    final byRisk = <RiskLevel, int>{};
    for (final level in RiskLevel.values) {
      byRisk[level] = logs.where((l) => l.riskLevel == level).length;
    }
    return _ReportStats(
      total: logs.length,
      uniqueUsers: logs.map((l) => l.userId).toSet().length,
      uniqueIps: logs.map((l) => l.ipAddress).toSet().length,
      failedLogins:
          logs.where((l) => l.status == LoginStatus.failed).length,
      anomalies: anomalyList.length,
      critical: byRisk[RiskLevel.critical] ?? 0,
      byRisk: byRisk,
    );
  }
}

class _UserStat {
  final String userId;
  final String? email;
  int loginCount = 0;
  int failures = 0;
  int actions = 0;
  final Set<String> ips = {};
  RiskLevel maxRisk = RiskLevel.low;

  _UserStat(this.userId, this.email);

  void add(AccessLog log) {
    loginCount++;
    if (log.status == LoginStatus.failed) failures++;
    actions += log.actionCount;
    ips.add(log.ipAddress);
    maxRisk = maxRisk.max(log.riskLevel);
  }
}
