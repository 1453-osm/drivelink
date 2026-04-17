import 'package:drivelink/features/obd/domain/models/dtc_code.dart';

/// Parses raw ELM327 Mode 03 responses into [DtcCode] objects.
class DtcParser {
  DtcParser._();

  /// Parse the raw hex response from a "03" (read DTC) command.
  ///
  /// Mode 03 response format (with spaces stripped):
  /// `4300XXYY` — each pair of bytes encodes one DTC.
  /// Two bytes per code: first 2 bits = category, remaining 14 bits = number.
  static List<DtcCode> parse(String response) {
    final cleaned = response.replaceAll(' ', '').toUpperCase();
    if (cleaned.contains('NODATA') || cleaned.contains('ERROR')) return [];

    // Find "43" prefix (mode 03 echo)
    final idx = cleaned.indexOf('43');
    if (idx < 0) return [];

    // Data bytes start after "43"
    final data = cleaned.substring(idx + 2);

    final codes = <DtcCode>[];

    // Each DTC is 4 hex chars (2 bytes)
    for (var i = 0; i + 3 < data.length; i += 4) {
      final chunk = data.substring(i, i + 4);
      final dtc = _decodeDtc(chunk);
      if (dtc != null && dtc.code != 'P0000') {
        codes.add(dtc);
      }
    }

    return codes;
  }

  /// Decode a 4-hex-char DTC value.
  static DtcCode? _decodeDtc(String hex) {
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return null;

    // First 2 bits → category letter
    final categoryBits = (value >> 14) & 0x03;
    final categoryLetter = switch (categoryBits) {
      0 => 'P',
      1 => 'C',
      2 => 'B',
      3 => 'U',
      _ => 'P',
    };

    // Next 2 bits → second character (0–3)
    final secondChar = (value >> 12) & 0x03;

    // Remaining 12 bits → 3 hex digits
    final remainder = value & 0x0FFF;
    final code =
        '$categoryLetter$secondChar${remainder.toRadixString(16).padLeft(3, '0').toUpperCase()}';

    final description = _knownDtcDescriptions[code] ?? 'Unknown fault code';
    final severity = _guessSeverity(code);

    return DtcCode(code: code, description: description, severity: severity);
  }

  static DtcSeverity _guessSeverity(String code) {
    // Misfires and critical fuel/ignition issues
    if (code.startsWith('P03') || code.startsWith('P04')) {
      return DtcSeverity.critical;
    }
    // Emission-related
    if (code.startsWith('P01') || code.startsWith('P02')) {
      return DtcSeverity.warning;
    }
    return DtcSeverity.info;
  }

  /// Subset of well-known DTC descriptions.
  static const _knownDtcDescriptions = <String, String>{
    'P0100': 'Mass Air Flow Circuit Malfunction',
    'P0101': 'Mass Air Flow Circuit Range/Performance',
    'P0102': 'Mass Air Flow Circuit Low Input',
    'P0103': 'Mass Air Flow Circuit High Input',
    'P0110': 'Intake Air Temperature Circuit Malfunction',
    'P0115': 'Engine Coolant Temperature Circuit Malfunction',
    'P0120': 'Throttle Position Sensor Circuit Malfunction',
    'P0130': 'O2 Sensor Circuit Malfunction (Bank 1 Sensor 1)',
    'P0171': 'System Too Lean (Bank 1)',
    'P0172': 'System Too Rich (Bank 1)',
    'P0300': 'Random/Multiple Cylinder Misfire Detected',
    'P0301': 'Cylinder 1 Misfire Detected',
    'P0302': 'Cylinder 2 Misfire Detected',
    'P0303': 'Cylinder 3 Misfire Detected',
    'P0304': 'Cylinder 4 Misfire Detected',
    'P0335': 'Crankshaft Position Sensor Circuit Malfunction',
    'P0340': 'Camshaft Position Sensor Circuit Malfunction',
    'P0400': 'Exhaust Gas Recirculation Flow Malfunction',
    'P0420': 'Catalyst System Efficiency Below Threshold (Bank 1)',
    'P0440': 'Evaporative Emission Control System Malfunction',
    'P0500': 'Vehicle Speed Sensor Malfunction',
    'P0505': 'Idle Control System Malfunction',
    'P0600': 'Serial Communication Link Malfunction',
    'P0700': 'Transmission Control System Malfunction',
  };
}
