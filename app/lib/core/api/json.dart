/// Small helpers to read loosely typed JSON maps safely.
typedef Json = Map<String, dynamic>;

int? asIntOrNull(Object? v) => v is num ? v.toInt() : null;
int asInt(Object? v, [int fallback = 0]) => asIntOrNull(v) ?? fallback;
double asDouble(Object? v, [double fallback = 0]) =>
    v is num ? v.toDouble() : fallback;
String asString(Object? v, [String fallback = '']) =>
    v is String ? v : fallback;
String? asStringOrNull(Object? v) => v is String ? v : null;
bool asBool(Object? v, [bool fallback = false]) => v is bool ? v : fallback;

List<Json> asJsonList(Object? v) =>
    v is List ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : const [];

/// Extracts `items` from a list response `{"items": [...], "total": n}`.
List<Json> listItems(Object? body) =>
    body is Map ? asJsonList(body['items']) : asJsonList(body);

Json asJson(Object? v) => v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

/// RFC 3339 UTC timestamp without fractional seconds, e.g. `2026-11-13T20:15:00Z`.
String toRfc3339(DateTime t) {
  final u = t.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)}'
      'T${two(u.hour)}:${two(u.minute)}:${two(u.second)}Z';
}
