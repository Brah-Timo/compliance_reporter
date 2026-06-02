import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Utility class for computing and verifying cryptographic hashes of
/// generated report files.
///
/// Used to create an immutable audit trail: after generating a report,
/// store its hash in your database. Before sharing the report, verify
/// the hash matches — proving the file has not been altered.
///
/// ## Usage
///
/// ```dart
/// // After generation
/// final hash = HashValidator.sha256hex(result.pdfBytes!);
/// await db.saveReportHash(result.reportId, hash);
///
/// // Before distribution
/// final isIntact = await HashValidator.verifyFile(pdfBytes, storedHash);
/// if (!isIntact) throw Exception('Report has been tampered with!');
/// ```
class HashValidator {
  HashValidator._();

  /// Computes the SHA-256 hex digest of [bytes].
  static String sha256hex(Uint8List bytes) =>
      sha256.convert(bytes).toString();

  /// Computes the MD5 hex digest of [bytes].
  ///
  /// ⚠️ MD5 is cryptographically weak — use [sha256hex] for security-critical
  /// applications. MD5 is included here for legacy system compatibility only.
  static String md5hex(Uint8List bytes) =>
      md5.convert(bytes).toString();

  /// Computes the SHA-512 hex digest of [bytes].
  static String sha512hex(Uint8List bytes) =>
      sha512.convert(bytes).toString();

  /// Returns `true` if [bytes] matches the expected [hash].
  ///
  /// [algorithm] defaults to `'sha256'`. Supported values:
  /// `'sha256'`, `'sha512'`, `'md5'`.
  static bool verify(
    Uint8List bytes,
    String hash, {
    String algorithm = 'sha256',
  }) {
    final computed = switch (algorithm.toLowerCase()) {
      'sha512' => sha512hex(bytes),
      'md5' => md5hex(bytes),
      _ => sha256hex(bytes),
    };
    return computed == hash.toLowerCase();
  }

  /// Returns a [ReportIntegrityRecord] with all three hashes computed at once.
  static ReportIntegrityRecord computeAll(Uint8List bytes) =>
      ReportIntegrityRecord(
        sha256: sha256hex(bytes),
        sha512: sha512hex(bytes),
        md5: md5hex(bytes),
        byteCount: bytes.lengthInBytes,
        computedAt: DateTime.now(),
      );
}

/// A bundle of integrity hashes for a generated report file.
class ReportIntegrityRecord {
  /// SHA-256 hex digest.
  final String sha256;

  /// SHA-512 hex digest.
  final String sha512;

  /// MD5 hex digest (legacy).
  final String md5;

  /// Total byte count of the original file.
  final int byteCount;

  /// When this record was computed.
  final DateTime computedAt;

  /// Creates a [ReportIntegrityRecord].
  const ReportIntegrityRecord({
    required this.sha256,
    required this.sha512,
    required this.md5,
    required this.byteCount,
    required this.computedAt,
  });

  /// Serialises to JSON (suitable for database storage).
  Map<String, dynamic> toJson() => {
        'sha256': sha256,
        'sha512': sha512,
        'md5': md5,
        'byteCount': byteCount,
        'computedAt': computedAt.toIso8601String(),
      };

  /// Deserialises from JSON.
  factory ReportIntegrityRecord.fromJson(Map<String, dynamic> json) =>
      ReportIntegrityRecord(
        sha256: json['sha256'] as String,
        sha512: json['sha512'] as String,
        md5: json['md5'] as String,
        byteCount: json['byteCount'] as int,
        computedAt: DateTime.parse(json['computedAt'] as String),
      );

  @override
  String toString() =>
      'IntegrityRecord(sha256=${sha256.substring(0, 12)}…, '
      'bytes=$byteCount, at=${computedAt.toIso8601String()})';
}
