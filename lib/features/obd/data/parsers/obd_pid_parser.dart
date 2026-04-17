import 'package:drivelink/features/obd/domain/models/obd_data.dart';
import 'package:drivelink/features/obd/domain/models/pid.dart';

/// Parses raw ELM327 hex responses into typed [ObdData] fields.
class ObdPidParser {
  ObdPidParser._();

  /// Parse a hex response string for a given [Pid] and fold it into
  /// the existing [ObdData], returning an updated copy.
  ///
  /// A typical response for RPM (010C) with spaces off looks like:
  /// `410C1A2B` — where 41 is the mode echo, 0C is the PID, 1A 2B are data.
  static ObdData apply(ObdData current, Pid pid, String response) {
    final bytes = _extractDataBytes(response, pid);
    if (bytes == null || bytes.length < pid.responseBytes) return current;

    final value = pid.parser(bytes);

    return switch (pid.code) {
      '010C' => current.copyWith(rpm: value),
      '010D' => current.copyWith(speed: value),
      '0105' => current.copyWith(coolantTemp: value),
      '0104' => current.copyWith(engineLoad: value),
      '0111' => current.copyWith(throttle: value),
      '015E' => current.copyWith(fuelRate: value),
      '010F' => current.copyWith(intakeTemp: value),
      '010B' => current.copyWith(intakePressure: value),
      '0142' => current.copyWith(batteryVoltage: value),
      _ => current,
    };
  }

  /// Extract the data bytes from a raw response.
  ///
  /// The ELM327 echoes the mode + PID first, e.g. "410C" for Mode 01 PID 0C.
  /// We strip the first two bytes (mode echo + pid) and parse the rest as
  /// pairs of hex digits.
  static List<int>? _extractDataBytes(String response, Pid pid) {
    // Remove spaces, "NO DATA", "ERROR" etc.
    final cleaned = response.replaceAll(' ', '').toUpperCase();
    if (cleaned.contains('NODATA') || cleaned.contains('ERROR')) return null;

    // The expected echo prefix: mode 41 + PID (without the leading "01").
    // e.g. PID code "010C" → echo "410C"
    final pidHex = pid.code.toUpperCase();
    final echoPrefix = '41${pidHex.substring(2)}';

    final startIndex = cleaned.indexOf(echoPrefix);
    if (startIndex < 0) return null;

    final dataStart = startIndex + echoPrefix.length;
    final dataHex = cleaned.substring(dataStart);

    if (dataHex.length < pid.responseBytes * 2) return null;

    final bytes = <int>[];
    for (var i = 0; i < pid.responseBytes * 2; i += 2) {
      final byteStr = dataHex.substring(i, i + 2);
      final value = int.tryParse(byteStr, radix: 16);
      if (value == null) return null;
      bytes.add(value);
    }

    return bytes;
  }

  /// Parse a supported-PIDs response into a set of hex PID codes.
  ///
  /// [baseRange] selects the PID range:
  ///   0x00 → query 0100, covers PIDs 01–20
  ///   0x20 → query 0120, covers PIDs 21–40
  ///   0x40 → query 0140, covers PIDs 41–60
  static Set<String> parseSupportedPids(String response,
      {int baseRange = 0x00}) {
    final cleaned = response.replaceAll(' ', '').toUpperCase();
    final rangeHex =
        baseRange.toRadixString(16).padLeft(2, '0').toUpperCase();
    final prefix = '41$rangeHex';
    final idx = cleaned.indexOf(prefix);
    if (idx < 0) return {};

    final dataHex = cleaned.substring(idx + prefix.length);
    if (dataHex.length < 8) return {};

    // 4 bytes = 32 bits, each bit represents 32 consecutive PIDs
    final supported = <String>{};
    for (var byteIdx = 0; byteIdx < 4; byteIdx++) {
      final byteStr = dataHex.substring(byteIdx * 2, byteIdx * 2 + 2);
      final byteVal = int.tryParse(byteStr, radix: 16) ?? 0;
      for (var bit = 7; bit >= 0; bit--) {
        if (byteVal & (1 << bit) != 0) {
          final pidNum = baseRange + byteIdx * 8 + (7 - bit) + 1;
          supported.add(
              '01${pidNum.toRadixString(16).padLeft(2, '0').toUpperCase()}');
        }
      }
    }

    return supported;
  }
}
