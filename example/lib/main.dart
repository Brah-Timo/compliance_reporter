import 'package:flutter/material.dart';
import 'package:compliance_reporter/compliance_reporter.dart';

void main() => runApp(const ComplianceReporterDemoApp());

/// Root widget for the compliance_reporter demo application.
class ComplianceReporterDemoApp extends StatelessWidget {
  const ComplianceReporterDemoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Compliance Reporter Demo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A237E)),
          useMaterial3: true,
        ),
        home: const ReportGeneratorScreen(),
      );
}

/// Main screen — lets the user pick standard, format, and date range,
/// then generates the report and shows timing + metadata.
class ReportGeneratorScreen extends StatefulWidget {
  const ReportGeneratorScreen({super.key});

  @override
  State<ReportGeneratorScreen> createState() => _ReportGeneratorScreenState();
}

class _ReportGeneratorScreenState extends State<ReportGeneratorScreen> {
  // ── State ─────────────────────────────────────────────────────────────

  bool _isGenerating = false;
  ReportResult? _lastResult;
  String _statusMessage = 'Ready — configure options and tap Generate.';
  bool _hasError = false;

  ReportFormat _selectedFormat = ReportFormat.pdf;
  ComplianceStandard _selectedStandard = ComplianceStandard.generic;
  int _daysBack = 90;
  bool _detectAnomalies = true;
  bool _anonymize = false;
  bool _signReport = false;

  // ── Sample data ───────────────────────────────────────────────────────

  List<AccessLog> get _sampleLogs => List.generate(200, (i) {
        final base = DateTime.now().subtract(Duration(days: i % _daysBack));
        return AccessLog(
          id: 'log_$i',
          userId: 'user_${i % 25}',
          userName: 'Demo User ${i % 25}',
          userEmail: 'user${i % 25}@demo.io',
          userRole: i % 15 == 0 ? 'admin' : 'user',
          department: ['Engineering', 'Finance', 'Operations', 'HR'][i % 4],
          ipAddress:
              '${10 + (i % 200)}.${i % 100}.${i % 50}.${i % 30}',
          country: ['US', 'GB', 'DE', 'AE', 'SG', 'RU'][i % 6],
          isVpn: i % 20 == 0,
          deviceType:
              ['Desktop', 'Mobile', 'Tablet', 'API'][i % 4],
          operatingSystem: ['Windows 11', 'macOS 14', 'iOS 17', 'Android 14'][i % 4],
          browser: ['Chrome 124', 'Firefox 125', 'Safari 17', 'Edge 124'][i % 4],
          loginAt: base,
          logoutAt: i % 8 != 0
              ? base.add(Duration(minutes: 30 + (i % 300)))
              : null,
          authMethod: i % 15 == 0 ? 'password' : 'mfa',
          status: i % 12 == 0
              ? LoginStatus.failed
              : i % 40 == 0
                  ? LoginStatus.blocked
                  : LoginStatus.success,
          actions: List.generate(
            i % 15,
            (j) => UserAction(
              action: ['VIEW', 'EDIT', 'EXPORT', 'DELETE', 'DOWNLOAD'][j % 5],
              resourceType: 'Document',
              timestamp: base.add(Duration(minutes: j * 5)),
              isSensitive: j % 5 >= 3,
            ),
          ),
        );
      });

  // ── Generate ──────────────────────────────────────────────────────────

  Future<void> _generate() async {
    setState(() {
      _isGenerating = true;
      _hasError = false;
      _statusMessage = 'Generating report…';
    });

    try {
      final reporter = ComplianceReporter(
        collector: MemoryLogCollector(logs: _sampleLogs),
        organizationName: 'Demo Corporation',
        standard: _selectedStandard,
        enableWatermark: true,
        enableDigitalSignature: _signReport,
        anonymizeSensitiveData: _anonymize,
        detectAnomalies: _detectAnomalies,
      );

      final result = await reporter.generate(
        from: _daysBack.days.ago,
        format: _selectedFormat,
      );

      setState(() {
        _lastResult = result;
        _isGenerating = false;
        _hasError = false;
        _statusMessage = '✅ Generated in '
            '${result.generationDuration.inMilliseconds}ms\n'
            '${result.totalEntries} entries  •  '
            '${result.uniqueUsers} users  •  '
            '${result.anomaliesDetected} anomalies detected';
      });
    } on ComplianceException catch (e) {
      setState(() {
        _isGenerating = false;
        _hasError = true;
        _statusMessage = '❌ ${e.code}: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _hasError = true;
        _statusMessage = '❌ Unexpected error: $e';
      });
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: Colors.white,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('compliance_reporter  Demo'),
              Text(
                'Automated Legal-Grade Audit Reports',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Config Card ──────────────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Report Configuration',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),

                      // Date range
                      Text(
                        'Period: last $_daysBack days',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Slider(
                        value: _daysBack.toDouble(),
                        min: 7,
                        max: 365,
                        divisions: 50,
                        label: '$_daysBack days',
                        onChanged: _isGenerating
                            ? null
                            : (v) => setState(() => _daysBack = v.toInt()),
                      ),

                      const SizedBox(height: 8),

                      // Format
                      Wrap(
                        spacing: 8,
                        children: [
                          const Text('Format:'),
                          ...ReportFormat.values.take(4).map(
                                (f) => ChoiceChip(
                                  label: Text(f.label),
                                  selected: _selectedFormat == f,
                                  onSelected: _isGenerating
                                      ? null
                                      : (_) => setState(() => _selectedFormat = f),
                                ),
                              ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Standard
                      Wrap(
                        spacing: 8,
                        children: [
                          const Text('Standard:'),
                          ...ComplianceStandard.values.take(5).map(
                                (s) => ChoiceChip(
                                  label: Text(s.displayName),
                                  selected: _selectedStandard == s,
                                  onSelected: _isGenerating
                                      ? null
                                      : (_) =>
                                          setState(() => _selectedStandard = s),
                                ),
                              ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Toggles
                      Wrap(
                        spacing: 16,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: _detectAnomalies,
                                onChanged: _isGenerating
                                    ? null
                                    : (v) =>
                                        setState(() => _detectAnomalies = v),
                              ),
                              const Text('Detect Anomalies'),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: _anonymize,
                                onChanged: _isGenerating
                                    ? null
                                    : (v) => setState(() => _anonymize = v),
                              ),
                              const Text('Anonymise PII'),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: _signReport,
                                onChanged: _isGenerating
                                    ? null
                                    : (v) => setState(() => _signReport = v),
                              ),
                              const Text('Digital Signature'),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Generate Button ───────────────────────────────────────────
              FilledButton.icon(
                onPressed: _isGenerating ? null : _generate,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.description_outlined),
                label: Text(
                  _isGenerating ? 'Generating…' : 'Generate Compliance Report',
                  style: const TextStyle(fontSize: 16),
                ),
              ),

              const SizedBox(height: 16),

              // ── Status Card ───────────────────────────────────────────────
              if (_statusMessage.isNotEmpty)
                Card(
                  color: _hasError
                      ? Colors.red.shade50
                      : _lastResult != null
                          ? Colors.green.shade50
                          : Colors.grey.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _statusMessage,
                      style: TextStyle(
                        color: _hasError ? Colors.red.shade800 : null,
                      ),
                    ),
                  ),
                ),

              // ── Result Metadata ───────────────────────────────────────────
              if (_lastResult != null) ...[
                const SizedBox(height: 16),
                _ReportMetadataCard(result: _lastResult!),
              ],
            ],
          ),
        ),
      );
}

/// Displays the metadata of the last generated report.
class _ReportMetadataCard extends StatelessWidget {
  final ReportResult result;

  const _ReportMetadataCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report Details',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _row('Report ID', result.reportId.substring(0, 18) + '…'),
            _row('Standard', result.standard.displayName),
            _row('Entries', result.totalEntries.toString()),
            _row('Unique Users', result.uniqueUsers.toString()),
            _row('Unique IPs', result.uniqueIps.toString()),
            _row('Failed Logins', result.failedLogins.toString()),
            _row('Anomalies', result.anomaliesDetected.toString()),
            _row('Generation Time',
                '${result.generationDuration.inMilliseconds}ms'),
            if (result.pdfSizeKb != null)
              _row('PDF Size', '${result.pdfSizeKb!.toStringAsFixed(1)} KB'),
            if (result.excelSizeKb != null)
              _row('Excel Size', '${result.excelSizeKb!.toStringAsFixed(1)} KB'),
            const SizedBox(height: 8),
            // Risk breakdown
            Text(
              'Risk Breakdown',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            ...RiskLevel.values.map(
              (level) => _riskRow(level, result.riskBreakdown[level] ?? 0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 140,
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      );

  Widget _riskRow(RiskLevel level, int count) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              child: Row(
                children: [
                  Text(level.emoji),
                  const SizedBox(width: 4),
                  Text(
                    level.label,
                    style: TextStyle(
                      color: Color(
                        int.parse(
                              level.colorHex.replaceAll('#', ''),
                              radix: 16,
                            ) |
                            0xFF000000,
                      ),
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              count.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
}
