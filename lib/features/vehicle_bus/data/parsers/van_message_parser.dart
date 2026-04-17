import 'dart:convert';

import 'package:drivelink/features/vehicle_bus/domain/models/van_message.dart';

/// Parses a raw JSON string from the ESP32 into a [VanMessage].
///
/// Two ESP32 message shapes are supported:
///
/// - Payload messages with a nested `data` object:
///   `{"type":"TEMP","data":{"external":22.5}}`
/// - Flat diagnostic messages where the fields live at the top level:
///   `{"type":"status","frames":12,"errors":0,"parsed":8,"raw":4}`
///   `{"type":"system","msg":"VAN Bus Reader v3.0 starting..."}`
class VanMessageParser {
  VanMessageParser._();

  /// Returns `null` when the line cannot be parsed.
  static VanMessage? parse(String line) {
    try {
      final json = jsonDecode(line);
      if (json is! Map<String, dynamic>) return null;

      final type = json['type'];
      if (type is! String || type.isEmpty) return null;

      final data = json['data'];
      late final Map<String, dynamic> payload;
      if (data is Map<String, dynamic>) {
        payload = data;
      } else {
        // Flat diagnostic messages: keep every top-level field except `type`
        // so status counters and system banners survive to the monitor.
        payload = <String, dynamic>{
          for (final entry in json.entries)
            if (entry.key != 'type') entry.key: entry.value,
        };
      }

      return VanMessage(
        type: type,
        data: payload,
        timestamp: DateTime.now(),
      );
    } catch (_) {
      // Malformed JSON — skip silently.
      return null;
    }
  }
}
