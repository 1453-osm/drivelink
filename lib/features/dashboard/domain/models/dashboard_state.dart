/// Holds real-time vehicle & connectivity data shown on the dashboard.
class DashboardState {
  const DashboardState({
    this.speed = 0,
    this.rpm = 0,
    this.coolantTemp = 0,
    this.externalTemp = 0,
    this.fuelConsumption = 0,
    this.tripDistance = 0,
    this.batteryVoltage = 0,
    this.vanConnected = false,
    this.obdConnected = false,
  });

  /// Current speed in km/h.
  final double speed;

  /// Engine revolutions per minute.
  final double rpm;

  /// Coolant temperature in Celsius.
  final double coolantTemp;

  /// External (ambient) temperature in Celsius.
  final double externalTemp;

  /// Instantaneous fuel consumption in L/100km.
  final double fuelConsumption;

  /// Trip distance in km since last reset.
  final double tripDistance;

  /// Vehicle battery voltage.
  final double batteryVoltage;

  /// Whether the VAN-bus adapter is connected.
  final bool vanConnected;

  /// Whether the OBD-II adapter is connected.
  final bool obdConnected;

  DashboardState copyWith({
    double? speed,
    double? rpm,
    double? coolantTemp,
    double? externalTemp,
    double? fuelConsumption,
    double? tripDistance,
    double? batteryVoltage,
    bool? vanConnected,
    bool? obdConnected,
  }) {
    return DashboardState(
      speed: speed ?? this.speed,
      rpm: rpm ?? this.rpm,
      coolantTemp: coolantTemp ?? this.coolantTemp,
      externalTemp: externalTemp ?? this.externalTemp,
      fuelConsumption: fuelConsumption ?? this.fuelConsumption,
      tripDistance: tripDistance ?? this.tripDistance,
      batteryVoltage: batteryVoltage ?? this.batteryVoltage,
      vanConnected: vanConnected ?? this.vanConnected,
      obdConnected: obdConnected ?? this.obdConnected,
    );
  }
}
