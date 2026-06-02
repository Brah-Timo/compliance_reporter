import 'dart:typed_data';

import '../core/report_config.dart';
import '../models/access_log.dart';
import '../processors/anomaly_detector.dart';

/// Abstract base class for all report generators.
abstract class BaseReportGenerator {
  /// Generates the report and returns the raw bytes.
  Future<Uint8List> generate({
    required List<AccessLog> logs,
    required DateTime from,
    required DateTime to,
    List<AnomalyReport> anomalies,
    ReportConfig? config,
  });
}
