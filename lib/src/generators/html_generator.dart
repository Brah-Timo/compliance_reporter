import 'dart:typed_data';
import 'dart:convert';

import 'package:intl/intl.dart';

import '../core/report_config.dart';
import '../models/access_log.dart';
import '../models/compliance_standard.dart';
import '../models/risk_level.dart';
import '../processors/anomaly_detector.dart';
import 'base_report_generator.dart';

/// Generates a self-contained HTML compliance report.
///
/// The output is a **single HTML file** with:
/// - Inline Tailwind CSS (CDN) for styling
/// - Responsive layout (works in email clients and browsers)
/// - Colour-coded risk-level rows
/// - Anomaly alert boxes
/// - KPI stat cards
/// - Printable (print-friendly CSS included)
///
/// Ideal for:
/// - Embedding in automated email alerts
/// - Hosting on internal wikis / portals
/// - Quick browser-based preview before sending the PDF
class HtmlGenerator extends BaseReportGenerator {
  final String organizationName;
  final ComplianceStandard standard;

  static final _df = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final _sf = DateFormat('yyyy-MM-dd');

  /// Creates an [HtmlGenerator].
  HtmlGenerator({
    required this.organizationName,
    this.standard = ComplianceStandard.generic,
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
    final html = _buildHtml(logs, from, to, anomalies, cfg);
    return Uint8List.fromList(utf8.encode(html));
  }

  String _buildHtml(
    List<AccessLog> logs,
    DateTime from,
    DateTime to,
    List<AnomalyReport> anomalies,
    ReportConfig cfg,
  ) {
    final uniqueUsers = logs.map((l) => l.userId).toSet().length;
    final uniqueIps = logs.map((l) => l.ipAddress).toSet().length;
    final failed = logs.where((l) => l.status == LoginStatus.failed).length;
    final critical = logs.where((l) => l.riskLevel == RiskLevel.critical).length;

    final title = cfg.title ?? 'Compliance Audit Report';

    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$title — ${_sf.format(from)} → ${_sf.format(to)}</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <style>
    @media print {
      .no-print { display: none !important; }
      body { font-size: 11px; }
      table { page-break-inside: auto; }
      tr { page-break-inside: avoid; page-break-after: auto; }
    }
    .risk-critical { background-color: #FFEBEE; }
    .risk-high     { background-color: #FFF3E0; }
    .risk-medium   { background-color: #FFFDE7; }
    .risk-low      { background-color: #FFFFFF; }
  </style>
</head>
<body class="bg-gray-50 font-sans">

  <!-- Header -->
  <header class="bg-indigo-900 text-white px-8 py-6 print:bg-white print:text-black">
    <div class="max-w-7xl mx-auto flex justify-between items-start">
      <div>
        <p class="text-indigo-200 text-sm uppercase tracking-widest">${organizationName.toUpperCase()}</p>
        <h1 class="text-2xl font-bold mt-1">$title</h1>
        <p class="text-indigo-200 text-sm mt-1">
          ${standard.displayName} &bull;
          ${_sf.format(from)} → ${_sf.format(to)} &bull;
          ${to.difference(from).inDays} days
        </p>
      </div>
      <div class="text-right text-sm text-indigo-200">
        <p>Generated: ${_df.format(DateTime.now())}</p>
        <p class="mt-1 text-red-300 font-semibold">CONFIDENTIAL — AUDIT USE ONLY</p>
        ${cfg.referenceNumber != null ? '<p class="mt-1">Ref: ${cfg.referenceNumber}</p>' : ''}
      </div>
    </div>
  </header>

  <main class="max-w-7xl mx-auto px-8 py-8 space-y-8">

    <!-- KPI Cards -->
    <section>
      <h2 class="text-lg font-bold text-gray-800 mb-4 border-l-4 border-indigo-600 pl-3">Executive Summary</h2>
      <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
        ${_kpiCard('Total Entries', logs.length.toString(), 'bg-indigo-600')}
        ${_kpiCard('Unique Users', uniqueUsers.toString(), 'bg-green-600')}
        ${_kpiCard('Unique IPs', uniqueIps.toString(), 'bg-blue-600')}
        ${_kpiCard('Failed Logins', failed.toString(), failed > 0 ? 'bg-orange-500' : 'bg-gray-400')}
        ${_kpiCard('Anomalies', anomalies.length.toString(), anomalies.isNotEmpty ? 'bg-red-600' : 'bg-gray-400')}
        ${_kpiCard('Critical Risk', critical.toString(), critical > 0 ? 'bg-purple-700' : 'bg-gray-400')}
      </div>
    </section>

    <!-- Standard Banner -->
    ${standard.reference.isNotEmpty ? '''
    <section class="bg-blue-50 border border-blue-200 rounded-lg p-4 text-sm text-blue-800">
      <strong>Compliance Standard:</strong> ${standard.displayName} — ${standard.reference}
    </section>''' : ''}

    <!-- Anomaly Alerts -->
    ${anomalies.isNotEmpty ? _buildAnomalySection(anomalies) : ''}

    <!-- Full Access Log -->
    <section>
      <h2 class="text-lg font-bold text-gray-800 mb-4 border-l-4 border-indigo-600 pl-3">
        Full Access Log (${logs.length} entries)
      </h2>
      <div class="overflow-x-auto rounded-lg shadow">
        <table class="w-full text-xs text-left">
          <thead>
            <tr class="bg-indigo-900 text-white">
              <th class="px-3 py-2">#</th>
              <th class="px-3 py-2">User ID</th>
              <th class="px-3 py-2">Email</th>
              <th class="px-3 py-2">IP Address</th>
              <th class="px-3 py-2">Country</th>
              <th class="px-3 py-2">Login Time</th>
              <th class="px-3 py-2">Duration</th>
              <th class="px-3 py-2">Actions</th>
              <th class="px-3 py-2">Status</th>
              <th class="px-3 py-2">Risk</th>
            </tr>
          </thead>
          <tbody>
            ${_buildLogRows(logs)}
          </tbody>
        </table>
      </div>
    </section>

    <!-- Footer -->
    <footer class="text-xs text-gray-400 text-center border-t pt-4">
      Generated by <strong>compliance_reporter v1.0.0</strong> &bull;
      ${_df.format(DateTime.now())} &bull;
      Report ID: will-be-set-by-reporter
    </footer>

  </main>
</body>
</html>''';
  }

  String _kpiCard(String label, String value, String bgClass) =>
      '<div class="$bgClass text-white rounded-lg p-4 text-center shadow">'
      '<p class="text-3xl font-bold">$value</p>'
      '<p class="text-xs mt-1 opacity-80">$label</p>'
      '</div>';

  String _buildAnomalySection(List<AnomalyReport> anomalies) => '''
    <section>
      <h2 class="text-lg font-bold text-red-700 mb-4 border-l-4 border-red-500 pl-3">
        ⚠ Anomaly Findings (${anomalies.length})
      </h2>
      <div class="space-y-3">
        ${anomalies.map(_anomalyCard).join('\n')}
      </div>
    </section>''';

  String _anomalyCard(AnomalyReport r) {
    final bg = r.severity == RiskLevel.critical
        ? 'bg-red-50 border-red-400'
        : 'bg-orange-50 border-orange-400';
    return '<div class="border-l-4 $bg rounded p-4 text-sm">'
        '<div class="flex justify-between">'
        '<span class="font-bold text-gray-800">${r.severity.emoji} ${r.type.label}</span>'
        '<span class="text-gray-500 text-xs">${_sf.format(r.detectedAt)}</span>'
        '</div>'
        '<p class="mt-2 text-gray-700">${_esc(r.description)}</p>'
        '${r.userId != null ? '<p class="mt-1 text-xs text-gray-500">User: ${_esc(r.userId!)}</p>' : ''}'
        '</div>';
  }

  String _buildLogRows(List<AccessLog> logs) {
    final buf = StringBuffer();
    for (var i = 0; i < logs.length; i++) {
      final log = logs[i];
      final riskClass = 'risk-${log.riskLevel.name}';
      final dur = log.sessionDurationSeconds != null
          ? _fmtDur(log.sessionDurationSeconds!)
          : 'Active';
      buf.write('<tr class="$riskClass border-b border-gray-100 hover:brightness-95">');
      buf.write('<td class="px-3 py-1.5 text-gray-500">${i + 1}</td>');
      buf.write('<td class="px-3 py-1.5 font-mono text-xs">${_esc(log.userId)}</td>');
      buf.write('<td class="px-3 py-1.5">${_esc(log.userEmail ?? '—')}</td>');
      buf.write('<td class="px-3 py-1.5 font-mono">${_esc(log.ipAddress)}'
          '${log.isVpn ? ' <span class="text-yellow-600" title="VPN">🔒</span>' : ''}</td>');
      buf.write('<td class="px-3 py-1.5">${_esc(log.country ?? '—')}</td>');
      buf.write('<td class="px-3 py-1.5 whitespace-nowrap">${_df.format(log.loginAt)}</td>');
      buf.write('<td class="px-3 py-1.5">${_esc(dur)}</td>');
      buf.write('<td class="px-3 py-1.5 text-center">${log.actionCount}</td>');
      buf.write('<td class="px-3 py-1.5">${_esc(log.status.label)}</td>');
      buf.write('<td class="px-3 py-1.5 font-semibold" style="color:${log.riskLevel.colorHex}">'
          '${log.riskLevel.emoji} ${log.riskLevel.label}</td>');
      buf.write('</tr>');
    }
    return buf.toString();
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static String _fmtDur(int secs) {
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}
