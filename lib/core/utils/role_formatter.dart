/// Central utility to ensure category and role strings are formatted with
/// 100% visual consistency everywhere across the You Too Art app.
class RoleFormatter {
  /// Canonical delimiter for separating multiple artist categories.
  static const String categorySeparator = ' • ';

  /// Formats any raw role string (e.g. "producer, art_director", "director, writer",
  /// "actor • model • director", "production_house") into a clean, capitalized,
  /// bullet-delimited category string: "Producer • Art Director".
  static String format(String? rawRole, {String separator = categorySeparator}) {
    if (rawRole == null || rawRole.trim().isEmpty || rawRole.trim().toLowerCase() == 'unset') {
      return '';
    }

    final trimmed = rawRole.trim();
    final lower = trimmed.toLowerCase();

    if (lower == 'production_house' ||
        lower == 'production house' ||
        (lower.contains('production') && lower.contains('house')) ||
        (lower.contains('studio') && !lower.contains('art'))) {
      return 'Production House';
    }

    // Split on comma, bullet, pipe, slash, or newline
    final parts = trimmed
        .split(RegExp(r'[,•|/\n]+'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty);

    final formattedRoles = <String>[];
    for (final part in parts) {
      final words = part
          .split(RegExp(r'[_ ]+'))
          .where((w) => w.isNotEmpty)
          .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
          .join(' ');
      if (words.isNotEmpty && !formattedRoles.contains(words)) {
        formattedRoles.add(words);
      }
    }

    if (formattedRoles.isEmpty) return trimmed;
    return formattedRoles.join(separator);
  }
}
