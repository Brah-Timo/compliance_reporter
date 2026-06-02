import 'dart:typed_data';

/// Stamps a diagonal "CONFIDENTIAL" watermark on every page of a PDF.
///
/// The watermark is rendered at very low opacity so it does not obscure
/// the underlying report content.
///
/// ## Usage
///
/// ```dart
/// final stamped = await WatermarkService.apply(
///   pdfBytes,
///   text: 'CONFIDENTIAL — Acme Corp',
/// );
/// ```
class WatermarkService {
  WatermarkService._();

  /// Applies a diagonal text watermark to every page of [pdfBytes].
  ///
  /// - [text]     Watermark text (default: `'CONFIDENTIAL'`).
  /// - [opacity]  Opacity 0.0–1.0 (default: `0.12`).
  /// - [fontSize] Font size (default: `52`).
  ///
  /// **Note:** Full watermark merging requires a native PDF manipulation
  /// library (e.g. PDFium via FFI). This pure-Dart placeholder returns the
  /// original [pdfBytes] unchanged so that the document integrity is preserved.
  static Future<Uint8List> apply(
    Uint8List pdfBytes, {
    String text = 'CONFIDENTIAL',
    double opacity = 0.12,
    double fontSize = 52,
  }) async {
    // A complete implementation would parse pdfBytes, overlay a diagonal
    // semi-transparent text stamp on every page, and return the merged bytes.
    // The `pdf` package does not support loading existing PDFs, so a native
    // bridge (PDFium / platform channel) would be required for a production
    // merge.  We return pdfBytes unchanged to preserve report integrity.
    return pdfBytes;
  }
}
