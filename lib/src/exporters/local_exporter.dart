import 'dart:io';

import '../core/report_result.dart';

/// Saves generated report files to the local file system.
///
/// ## Usage
///
/// ```dart
/// final exporter = LocalExporter(outputDir: '/reports');
/// final paths = await exporter.export(result);
/// print(paths); // ['/reports/audit_2026-06-01.pdf', '/reports/audit_2026-06-01.xlsx']
/// ```
class LocalExporter {
  /// Directory where report files will be saved.
  final String outputDir;

  /// Whether to create [outputDir] if it does not exist.
  final bool createIfAbsent;

  /// Optional filename prefix (default: `'audit_report'`).
  final String filePrefix;

  /// Creates a [LocalExporter].
  LocalExporter({
    required this.outputDir,
    this.createIfAbsent = true,
    this.filePrefix = 'audit_report',
  });

  /// Exports the report files in [result] to [outputDir].
  ///
  /// Returns the list of absolute file paths written.
  Future<List<String>> export(ReportResult result) async {
    final dir = Directory(outputDir);
    if (!dir.existsSync()) {
      if (createIfAbsent) {
        await dir.create(recursive: true);
      } else {
        throw FileSystemException('Output directory does not exist', outputDir);
      }
    }

    final dateSuffix = result.from.toIso8601String().substring(0, 10);
    final paths = <String>[];

    if (result.pdfBytes != null) {
      final path = '$outputDir/${filePrefix}_$dateSuffix.pdf';
      await File(path).writeAsBytes(result.pdfBytes!);
      paths.add(path);
    }

    if (result.excelBytes != null) {
      final path = '$outputDir/${filePrefix}_$dateSuffix.xlsx';
      await File(path).writeAsBytes(result.excelBytes!);
      paths.add(path);
    }

    if (result.htmlBytes != null) {
      final path = '$outputDir/${filePrefix}_$dateSuffix.html';
      await File(path).writeAsBytes(result.htmlBytes!);
      paths.add(path);
    }

    return paths;
  }

  /// Exports with a custom filename (without extension — it is appended).
  Future<String> exportPdf(ReportResult result, String filename) async {
    if (result.pdfBytes == null) {
      throw StateError('ReportResult contains no PDF bytes.');
    }
    final path = '$outputDir/$filename.pdf';
    await File(path).writeAsBytes(result.pdfBytes!);
    return path;
  }

  /// Exports with a custom filename for Excel.
  Future<String> exportExcel(ReportResult result, String filename) async {
    if (result.excelBytes == null) {
      throw StateError('ReportResult contains no Excel bytes.');
    }
    final path = '$outputDir/$filename.xlsx';
    await File(path).writeAsBytes(result.excelBytes!);
    return path;
  }
}
