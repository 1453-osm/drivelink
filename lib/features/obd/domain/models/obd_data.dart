/// Live OBD-II sensor data aggregated from PID responses.
class ObdData {
  /// Engine RPM (0–8000 typical).
  final double? rpm;

  /// Vehicle speed in km/h.
  final double? speed;

  /// Engine coolant temperature in °C.
  final double? coolantTemp;

  /// Calculated engine load (0–100 %).
  final double? engineLoad;

  /// Throttle position (0–100 %).
  final double? throttle;

  /// Fuel consumption rate (L/h or g/s depending on vehicle).
  final double? fuelRate;

  /// Intake air temperature in °C.
  final double? intakeTemp;

  /// Intake manifold absolute pressure in kPa.
  final double? intakePressure;

  /// Control module voltage (battery) in V.
  final double? batteryVoltage;

  /// Set of PID codes (hex strings) the ECU reports as supported.
  final Set<String> supportedPids;

  const ObdData({
    this.rpm,
    this.speed,
    this.coolantTemp,
    this.engineLoad,
    this.throttle,
    this.fuelRate,
    this.intakeTemp,
    this.intakePressure,
    this.batteryVoltage,
    this.supportedPids = const {},
  });

  ObdData copyWith({
    double? rpm,
    double? speed,
    double? coolantTemp,
    double? engineLoad,
    double? throttle,
    double? fuelRate,
    double? intakeTemp,
    double? intakePressure,
    double? batteryVoltage,
    Set<String>? supportedPids,
  }) {
    return ObdData(
      rpm: rpm ?? this.rpm,
      speed: speed ?? this.speed,
      coolantTemp: coolantTemp ?? this.coolantTemp,
      engineLoad: engineLoad ?? this.engineLoad,
      throttle: throttle ?? this.throttle,
      fuelRate: fuelRate ?? this.fuelRate,
      intakeTemp: intakeTemp ?? this.intakeTemp,
      intakePressure: intakePressure ?? this.intakePressure,
      batteryVoltage: batteryVoltage ?? this.batteryVoltage,
      supportedPids: supportedPids ?? this.supportedPids,
    );
  }

  @override
  String toString() =>
      'ObdData(rpm: $rpm, speed: $speed, coolant: $coolantTemp, '
      'load: $engineLoad, throttle: $throttle, fuel: $fuelRate, '
      'intake: $intakeTemp/${intakePressure}kPa, batt: $batteryVoltage)';
}
