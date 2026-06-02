import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/report_result.dart';

/// Sends generated report files as email attachments via a REST mail API.
///
/// Works with any transactional email provider that exposes a JSON API.
/// Pre-built support for **SendGrid** and **Mailgun**.
/// For other providers, use [EmailExporter.custom] with a custom payload builder.
///
/// ## SendGrid example
///
/// ```dart
/// final exporter = EmailExporter.sendgrid(
///   apiKey: Platform.environment['SENDGRID_API_KEY']!,
///   from: 'audit@mycompany.com',
///   to: ['ciso@mycompany.com', 'auditor@external.com'],
///   subject: 'Q2-2026 Compliance Report',
/// );
///
/// await exporter.send(result);
/// ```
class EmailExporter {
  final String _apiUrl;
  final Map<String, String> _headers;
  final String from;
  final List<String> to;
  final String subject;
  final String body;
  final Map<String, dynamic> Function(ReportResult, List<_Attachment>)?
      _payloadBuilder;

  EmailExporter._({
    required String apiUrl,
    required Map<String, String> headers,
    required this.from,
    required this.to,
    required this.subject,
    required this.body,
    Map<String, dynamic> Function(ReportResult, List<_Attachment>)?
        payloadBuilder,
  })  : _apiUrl = apiUrl,
        _headers = headers,
        _payloadBuilder = payloadBuilder;

  // ── Named constructors ────────────────────────────────────────────────

  /// Configures the exporter for the **SendGrid** v3 API.
  factory EmailExporter.sendgrid({
    required String apiKey,
    required String from,
    required List<String> to,
    String subject = 'Compliance Audit Report',
    String body =
        'Please find the attached compliance audit report.',
  }) =>
      EmailExporter._(
        apiUrl: 'https://api.sendgrid.com/v3/mail/send',
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        from: from,
        to: to,
        subject: subject,
        body: body,
        payloadBuilder: (result, attachments) => {
          'personalizations': [
            {
              'to': to.map((e) => {'email': e}).toList(),
              'subject': subject,
            },
          ],
          'from': {'email': from},
          'content': [
            {'type': 'text/plain', 'value': body},
          ],
          'attachments': attachments
              .map((a) => {
                    'content': a.base64Content,
                    'filename': a.filename,
                    'type': a.mimeType,
                    'disposition': 'attachment',
                  })
              .toList(),
        },
      );

  /// Configures the exporter for the **Mailgun** v3 API (multipart/form-data
  /// style is not used here — we use the JSON endpoint instead).
  factory EmailExporter.mailgun({
    required String apiKey,
    required String domain,
    required String from,
    required List<String> to,
    String subject = 'Compliance Audit Report',
    String body = 'Please find the attached compliance audit report.',
  }) =>
      EmailExporter._(
        apiUrl: 'https://api.mailgun.net/v3/$domain/messages',
        headers: {
          'Authorization':
              'Basic ${base64Encode(utf8.encode('api:$apiKey'))}',
          'Content-Type': 'application/json',
        },
        from: from,
        to: to,
        subject: subject,
        body: body,
      );

  /// Configures the exporter for a fully **custom** REST API.
  factory EmailExporter.custom({
    required String apiUrl,
    required Map<String, String> headers,
    required String from,
    required List<String> to,
    required String subject,
    String body = '',
    required Map<String, dynamic> Function(ReportResult, List<_Attachment>)
        payloadBuilder,
  }) =>
      EmailExporter._(
        apiUrl: apiUrl,
        headers: headers,
        from: from,
        to: to,
        subject: subject,
        body: body,
        payloadBuilder: payloadBuilder,
      );

  // ── Send ──────────────────────────────────────────────────────────────

  /// Sends the report(s) in [result] as email attachments.
  ///
  /// Returns `true` on success (2xx response), `false` otherwise.
  Future<bool> send(ReportResult result) async {
    final attachments = <_Attachment>[];

    if (result.pdfBytes != null) {
      attachments.add(_Attachment(
        filename: 'audit_report_${result.from.toIso8601String().substring(0, 10)}.pdf',
        mimeType: 'application/pdf',
        bytes: result.pdfBytes!,
      ));
    }

    if (result.excelBytes != null) {
      attachments.add(_Attachment(
        filename: 'audit_report_${result.from.toIso8601String().substring(0, 10)}.xlsx',
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        bytes: result.excelBytes!,
      ));
    }

    if (attachments.isEmpty) return false;

    final payload = _payloadBuilder != null
        ? _payloadBuilder!(result, attachments)
        : _defaultPayload(result, attachments);

    final response = await http
        .post(
          Uri.parse(_apiUrl),
          headers: _headers,
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 30));

    return response.statusCode >= 200 && response.statusCode < 300;
  }

  Map<String, dynamic> _defaultPayload(
    ReportResult result,
    List<_Attachment> attachments,
  ) =>
      {
        'from': from,
        'to': to,
        'subject': subject,
        'text': body,
        'attachments': attachments
            .map((a) => {'name': a.filename, 'data': a.base64Content})
            .toList(),
      };
}

class _Attachment {
  final String filename;
  final String mimeType;
  final Uint8List bytes;

  _Attachment({
    required this.filename,
    required this.mimeType,
    required this.bytes,
  });

  String get base64Content => base64Encode(bytes);
}
