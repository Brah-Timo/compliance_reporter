import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Appends a tamper-evident digital signature to a PDF document.
///
/// The signature is a HMAC-SHA256 digest of the PDF bytes, encoded as
/// a JSON trailer block appended after the `%%EOF` marker.
///
/// ## Verification
///
/// To verify a signed PDF, call [ReportSigner.verify].
///
/// ## Important
///
/// This is a **lightweight software signature** suitable for internal
/// audit trails. It is **not** a cryptographic X.509 / PKCS#7 PDF
/// signature (which requires a hardware key or CA certificate).
/// For legally binding e-signatures, integrate a service such as
/// DocuSign or GlobalSign.
class ReportSigner {
  /// The HMAC key used to sign reports.
  ///
  /// In production, load this from a secure secret store (e.g.
  /// environment variable, platform keychain, AWS Secrets Manager).
  static const String _defaultKey = 'compliance_reporter_default_key';

  /// Appends a HMAC-SHA256 signature trailer to [pdfBytes].
  ///
  /// Returns the modified byte array. The original PDF content is
  /// unchanged; only a binary-safe JSON trailer is appended.
  static Future<Uint8List> sign(
    Uint8List pdfBytes, {
    String? signingKey,
  }) async {
    final key = utf8.encode(signingKey ?? _defaultKey);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(pdfBytes);

    final trailer = {
      'signatureAlgorithm': 'HMAC-SHA256',
      'digest': digest.toString(),
      'signedAt': DateTime.now().toUtc().toIso8601String(),
      'signerIdentity': 'compliance_reporter v1.0.0',
    };

    final trailerBytes = utf8.encode(
      '\n%%CR_SIGNATURE_TRAILER%%\n${jsonEncode(trailer)}\n%%END_SIGNATURE%%\n',
    );

    final combined = Uint8List(pdfBytes.length + trailerBytes.length);
    combined.setAll(0, pdfBytes);
    combined.setAll(pdfBytes.length, trailerBytes);
    return combined;
  }

  /// Verifies that [signedPdfBytes] has not been tampered with.
  ///
  /// Returns `true` if the signature is valid, `false` otherwise.
  static Future<bool> verify(
    Uint8List signedPdfBytes, {
    String? signingKey,
  }) async {
    try {
      final content = utf8.decode(signedPdfBytes, allowMalformed: true);
      final trailerStart = content.indexOf('%%CR_SIGNATURE_TRAILER%%');
      if (trailerStart < 0) return false;

      final jsonStart = content.indexOf('{', trailerStart);
      final jsonEnd = content.indexOf('}', jsonStart) + 1;
      if (jsonStart < 0 || jsonEnd <= jsonStart) return false;

      final trailerJson =
          jsonDecode(content.substring(jsonStart, jsonEnd)) as Map<String, dynamic>;
      final storedDigest = trailerJson['digest'] as String?;
      if (storedDigest == null) return false;

      // Re-hash the original PDF (everything before the trailer)
      final originalBytes = signedPdfBytes.sublist(0, trailerStart);
      final key = utf8.encode(signingKey ?? _defaultKey);
      final hmac = Hmac(sha256, key);
      final computedDigest = hmac.convert(originalBytes).toString();

      return computedDigest == storedDigest;
    } catch (_) {
      return false;
    }
  }
}
