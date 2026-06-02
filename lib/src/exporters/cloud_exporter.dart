import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/report_result.dart';

/// Uploads generated report files to cloud object storage.
///
/// Supports **AWS S3**, **Google Cloud Storage (GCS)**, and
/// **Azure Blob Storage** via their REST / presigned-URL APIs.
///
/// For AWS S3, you need a pre-generated presigned URL (generated
/// server-side with the AWS SDK). For GCS and Azure, the upload
/// goes directly to the JSON API using service-account credentials.
///
/// ## AWS S3 (presigned URL) example
///
/// ```dart
/// // Server-side: generate a presigned URL for PUT
/// final presignedUrl = await s3.generatePresignedUrl(...);
///
/// // Client-side: upload
/// final exporter = CloudExporter.s3Presigned(presignedUrl: presignedUrl);
/// final url = await exporter.uploadPdf(result);
/// ```
///
/// ## GCS (service-account JSON) example
///
/// ```dart
/// final exporter = CloudExporter.gcs(
///   bucketName: 'my-audit-reports',
///   serviceAccountToken: myToken,
/// );
/// final url = await exporter.upload(result);
/// ```
class CloudExporter {
  final _UploadStrategy _strategy;
  final String? _keyPrefix;

  CloudExporter._({
    required _UploadStrategy strategy,
    String? keyPrefix,
  })  : _strategy = strategy,
        _keyPrefix = keyPrefix;

  // ── Named constructors ────────────────────────────────────────────────

  /// Uploads to S3 via a server-generated **presigned PUT URL**.
  factory CloudExporter.s3Presigned({
    required String presignedUrl,
    String? keyPrefix,
  }) =>
      CloudExporter._(
        strategy: _PresignedUrlStrategy(presignedUrl),
        keyPrefix: keyPrefix,
      );

  /// Uploads to **Google Cloud Storage** using a service-account OAuth token.
  factory CloudExporter.gcs({
    required String bucketName,
    required String serviceAccountToken,
    String? keyPrefix,
  }) =>
      CloudExporter._(
        strategy: _GcsStrategy(
          bucketName: bucketName,
          token: serviceAccountToken,
        ),
        keyPrefix: keyPrefix,
      );

  /// Uploads to **Azure Blob Storage** using a SAS token URL.
  factory CloudExporter.azure({
    required String containerSasUrl,
    String? keyPrefix,
  }) =>
      CloudExporter._(
        strategy: _AzureStrategy(containerSasUrl),
        keyPrefix: keyPrefix,
      );

  // ── Upload ────────────────────────────────────────────────────────────

  /// Uploads all available files in [result] to cloud storage.
  ///
  /// Returns a map of `format → public URL` for each uploaded file.
  Future<Map<String, String>> upload(ReportResult result) async {
    final urls = <String, String>{};
    final dateSuffix = result.from.toIso8601String().substring(0, 10);
    final prefix = _keyPrefix != null ? '$_keyPrefix/' : '';

    if (result.pdfBytes != null) {
      final key = '${prefix}audit_report_$dateSuffix.pdf';
      final url = await _strategy.put(
        key: key,
        bytes: result.pdfBytes!,
        contentType: 'application/pdf',
      );
      urls['pdf'] = url;
    }

    if (result.excelBytes != null) {
      final key = '${prefix}audit_report_$dateSuffix.xlsx';
      final url = await _strategy.put(
        key: key,
        bytes: result.excelBytes!,
        contentType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      urls['excel'] = url;
    }

    if (result.htmlBytes != null) {
      final key = '${prefix}audit_report_$dateSuffix.html';
      final url = await _strategy.put(
        key: key,
        bytes: result.htmlBytes!,
        contentType: 'text/html',
      );
      urls['html'] = url;
    }

    return urls;
  }
}

// ── Upload strategies ─────────────────────────────────────────────────────

abstract class _UploadStrategy {
  Future<String> put({
    required String key,
    required Uint8List bytes,
    required String contentType,
  });
}

class _PresignedUrlStrategy extends _UploadStrategy {
  final String presignedUrl;
  _PresignedUrlStrategy(this.presignedUrl);

  @override
  Future<String> put({
    required String key,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final response = await http.put(
      Uri.parse(presignedUrl),
      headers: {'Content-Type': contentType},
      body: bytes,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'S3 presigned upload failed: HTTP ${response.statusCode}',
      );
    }
    // Extract the public URL (presigned URL minus query params)
    final uri = Uri.parse(presignedUrl);
    return '${uri.scheme}://${uri.host}${uri.path}';
  }
}

class _GcsStrategy extends _UploadStrategy {
  final String bucketName;
  final String token;

  _GcsStrategy({required this.bucketName, required this.token});

  @override
  Future<String> put({
    required String key,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final uri = Uri.parse(
      'https://storage.googleapis.com/upload/storage/v1/b/'
      '$bucketName/o?uploadType=media&name=${Uri.encodeComponent(key)}',
    );
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': contentType,
      },
      body: bytes,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'GCS upload failed: HTTP ${response.statusCode} — ${response.body}',
      );
    }
    final respJson = jsonDecode(response.body) as Map<String, dynamic>;
    final name = respJson['name'] as String? ?? key;
    return 'https://storage.googleapis.com/$bucketName/$name';
  }
}

class _AzureStrategy extends _UploadStrategy {
  final String containerSasUrl;
  _AzureStrategy(this.containerSasUrl);

  @override
  Future<String> put({
    required String key,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final sasUri = Uri.parse(containerSasUrl);
    final blobUri = sasUri.replace(
      path: '${sasUri.path}/$key',
    );

    final response = await http.put(
      blobUri,
      headers: {
        'x-ms-blob-type': 'BlockBlob',
        'Content-Type': contentType,
      },
      body: bytes,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Azure Blob upload failed: HTTP ${response.statusCode}',
      );
    }
    return '${sasUri.scheme}://${sasUri.host}${sasUri.path}/$key';
  }
}
