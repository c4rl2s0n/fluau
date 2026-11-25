/// Thrown when capability JSON cannot be decoded into the expected DTO.
class CapabilityDecodeException implements Exception {
  CapabilityDecodeException(this.message, {this.cause, this.raw});

  final String message;
  final Object? cause;
  final Object? raw;

  @override
  String toString() {
    final buf = StringBuffer('CapabilityDecodeException: $message');
    if (cause != null) buf.write(' ($cause)');
    return buf.toString();
  }
}

/// Helpers used by generated capability DTO `fromJson` / clients.
class CapabilityJson {
  CapabilityJson._();

  static Map<String, dynamic> asMap(Object? raw, {required String context}) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    throw CapabilityDecodeException(
      '$context: expected a JSON object',
      raw: raw,
    );
  }

  static T requireField<T>(
    Map<String, dynamic> json,
    String key, {
    required String context,
  }) {
    if (!json.containsKey(key) || json[key] == null) {
      throw CapabilityDecodeException(
        '$context: missing required field "$key"',
        raw: json,
      );
    }
    final v = json[key];
    if (v is T) return v;
    throw CapabilityDecodeException(
      '$context: field "$key" expected $T, got ${v.runtimeType}',
      raw: v,
    );
  }

  static T? optionalField<T>(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v == null) return null;
    if (v is T) return v;
    throw CapabilityDecodeException(
      'field "$key" expected $T?, got ${v.runtimeType}',
      raw: v,
    );
  }

  /// JSON numbers often arrive as [num]; coerce to [int].
  static int requireInt(
    Map<String, dynamic> json,
    String key, {
    required String context,
  }) {
    final v = requireField<Object>(json, key, context: context);
    if (v is int) return v;
    if (v is num) return v.toInt();
    throw CapabilityDecodeException(
      '$context: field "$key" expected int, got ${v.runtimeType}',
      raw: v,
    );
  }

  static int? optionalInt(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    throw CapabilityDecodeException(
      'field "$key" expected int?, got ${v.runtimeType}',
      raw: v,
    );
  }

  static double requireDouble(
    Map<String, dynamic> json,
    String key, {
    required String context,
  }) {
    final v = requireField<Object>(json, key, context: context);
    if (v is double) return v;
    if (v is num) return v.toDouble();
    throw CapabilityDecodeException(
      '$context: field "$key" expected double, got ${v.runtimeType}',
      raw: v,
    );
  }

  static double? optionalDouble(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    throw CapabilityDecodeException(
      'field "$key" expected double?, got ${v.runtimeType}',
      raw: v,
    );
  }
}
