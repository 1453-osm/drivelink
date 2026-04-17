/// Represents a standard OBD-II Parameter ID.
class Pid {
  /// Hex code sent to the ECU (e.g. "010C" for RPM).
  final String code;

  /// Human-readable name.
  final String name;

  /// Engineering unit (e.g. "rpm", "km/h", "°C").
  final String unit;

  /// Expected minimum value.
  final double min;

  /// Expected maximum value.
  final double max;

  /// Number of data bytes in the response (A, B, …).
  final int responseBytes;

  /// Converts raw response bytes to a double value.
  final double Function(List<int> bytes) parser;

  const Pid({
    required this.code,
    required this.name,
    required this.unit,
    required this.min,
    required this.max,
    required this.responseBytes,
    required this.parser,
  });

  @override
  String toString() => 'Pid($code $name [$unit])';

  // ── Standard PIDs ────────────────────────────────────────────────────

  /// Engine RPM: (A*256 + B) / 4
  static final rpm = Pid(
    code: '010C',
    name: 'RPM',
    unit: 'rpm',
    min: 0,
    max: 8000,
    responseBytes: 2,
    parser: (b) => (b[0] * 256 + b[1]) / 4.0,
  );

  /// Vehicle speed: A km/h
  static final speed = Pid(
    code: '010D',
    name: 'Speed',
    unit: 'km/h',
    min: 0,
    max: 255,
    responseBytes: 1,
    parser: (b) => b[0].toDouble(),
  );

  /// Engine coolant temperature: A - 40  °C
  static final coolantTemp = Pid(
    code: '0105',
    name: 'Coolant Temp',
    unit: '°C',
    min: -40,
    max: 215,
    responseBytes: 1,
    parser: (b) => b[0] - 40.0,
  );

  /// Calculated engine load: A * 100 / 255  %
  static final engineLoad = Pid(
    code: '0104',
    name: 'Engine Load',
    unit: '%',
    min: 0,
    max: 100,
    responseBytes: 1,
    parser: (b) => b[0] * 100.0 / 255.0,
  );

  /// Throttle position: A * 100 / 255  %
  static final throttle = Pid(
    code: '0111',
    name: 'Throttle',
    unit: '%',
    min: 0,
    max: 100,
    responseBytes: 1,
    parser: (b) => b[0] * 100.0 / 255.0,
  );

  /// Engine fuel rate: (A*256 + B) / 20  L/h
  static final fuelRate = Pid(
    code: '015E',
    name: 'Fuel Rate',
    unit: 'L/h',
    min: 0,
    max: 3276.75,
    responseBytes: 2,
    parser: (b) => (b[0] * 256 + b[1]) / 20.0,
  );

  /// Intake air temperature: A - 40  °C
  static final intakeTemp = Pid(
    code: '010F',
    name: 'Intake Temp',
    unit: '°C',
    min: -40,
    max: 215,
    responseBytes: 1,
    parser: (b) => b[0] - 40.0,
  );

  /// Intake manifold absolute pressure: A  kPa
  static final intakePressure = Pid(
    code: '010B',
    name: 'Intake Pressure',
    unit: 'kPa',
    min: 0,
    max: 255,
    responseBytes: 1,
    parser: (b) => b[0].toDouble(),
  );

  /// Control module voltage: (A*256 + B) / 1000  V
  static final batteryVoltage = Pid(
    code: '0142',
    name: 'Battery Voltage',
    unit: 'V',
    min: 0,
    max: 65.535,
    responseBytes: 2,
    parser: (b) => (b[0] * 256 + b[1]) / 1000.0,
  );

  /// PIDs queried in the normal round-robin cycle.
  static final List<Pid> standardPids = [
    rpm,
    speed,
    coolantTemp,
    engineLoad,
    throttle,
    fuelRate,
    intakeTemp,
    intakePressure,
    batteryVoltage,
  ];

  /// Lookup a PID by its hex code.
  static Pid? fromCode(String code) {
    final upper = code.toUpperCase();
    for (final pid in standardPids) {
      if (pid.code == upper) return pid;
    }
    return null;
  }
}
