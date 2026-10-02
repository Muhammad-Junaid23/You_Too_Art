/// Utility functions for safe JSON parsing.
/// Used by all model classes to deserialize Supabase responses.
library;

/// Parses a [DateTime] from a JSON value.
/// Returns `null` if the value is null or not a valid date string.
DateTime? parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// Serializes a [DateTime] to an ISO 8601 string.
/// Returns `null` if the input is null.
String? serializeDateTime(DateTime? value) {
  return value?.toUtc().toIso8601String();
}

/// Safely parses a [String] from a JSON value.
/// Returns [defaultValue] if the value is null.
String parseString(dynamic value, {String defaultValue = ''}) {
  if (value == null) return defaultValue;
  return value.toString();
}

/// Safely parses a [bool] from a JSON value.
/// Returns [defaultValue] if the value is null or not a bool.
bool parseBool(dynamic value, {bool defaultValue = false}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is int) return value != 0;
  if (value is String) return value.toLowerCase() == 'true';
  return defaultValue;
}

/// Safely parses an [int] from a JSON value.
/// Returns [defaultValue] if the value is null or not parsable.
int parseInt(dynamic value, {int defaultValue = 0}) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? defaultValue;
  return defaultValue;
}

/// Safely parses a [double] from a JSON value.
/// Returns [defaultValue] if the value is null or not parsable.
double parseDouble(dynamic value, {double defaultValue = 0.0}) {
  if (value == null) return defaultValue;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? defaultValue;
  return defaultValue;
}
