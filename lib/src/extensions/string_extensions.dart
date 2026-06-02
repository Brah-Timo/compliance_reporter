/// Utility extensions on [String] used throughout the package.
extension StringComplianceExtensions on String {
  /// Returns `true` if the string looks like a valid IPv4 address.
  bool get isIpv4 => RegExp(
        r'^(\d{1,3}\.){3}\d{1,3}$',
      ).hasMatch(this) &&
      split('.').every((p) => int.parse(p) <= 255);

  /// Returns `true` if the string looks like a valid IPv6 address.
  bool get isIpv6 => contains(':') && split(':').length >= 4;

  /// Returns `true` if the string looks like an email address.
  bool get isEmail =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(this);

  /// Truncates the string to [maxLength] characters, appending [ellipsis].
  String truncate(int maxLength, {String ellipsis = '…'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - ellipsis.length)}$ellipsis';
  }

  /// Converts `'snake_case'` or `'camelCase'` to a human-readable label.
  ///
  /// ```dart
  /// 'user_id'.toLabel()        // → 'User Id'
  /// 'loginStatus'.toLabel()   // → 'Login Status'
  /// ```
  String toLabel() {
    // camelCase → words
    final withSpaces = replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (m) => '${m[1]} ${m[2]}',
    );
    // snake_case → words
    return withSpaces
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  /// Returns the string with its first character uppercased.
  String get capitalised =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  /// Returns a safe filename version of the string (removes unsafe chars).
  String toSafeFilename() =>
      replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
}
