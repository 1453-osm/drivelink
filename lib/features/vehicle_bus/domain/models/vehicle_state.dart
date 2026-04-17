import 'package:drivelink/features/vehicle_bus/domain/models/steering_button.dart';
import 'package:drivelink/features/vehicle_bus/domain/models/van_message.dart';

/// Door open/close status for all four doors.
class DoorStatus {
  final bool frontLeft;
  final bool frontRight;
  final bool rearLeft;
  final bool rearRight;
  final bool trunk;

  const DoorStatus({
    this.frontLeft = false,
    this.frontRight = false,
    this.rearLeft = false,
    this.rearRight = false,
    this.trunk = false,
  });

  bool get allClosed =>
      !frontLeft && !frontRight && !rearLeft && !rearRight && !trunk;

  DoorStatus copyWith({
    bool? frontLeft,
    bool? frontRight,
    bool? rearLeft,
    bool? rearRight,
    bool? trunk,
  }) {
    return DoorStatus(
      frontLeft: frontLeft ?? this.frontLeft,
      frontRight: frontRight ?? this.frontRight,
      rearLeft: rearLeft ?? this.rearLeft,
      rearRight: rearRight ?? this.rearRight,
      trunk: trunk ?? this.trunk,
    );
  }

  @override
  String toString() =>
      'DoorStatus(FL:$frontLeft FR:$frontRight RL:$rearLeft RR:$rearRight T:$trunk)';
}

/// Distance readings from the parking sensors (in centimetres).
class ParkingSensors {
  final int leftCm;
  final int centerCm;
  final int rightCm;

  const ParkingSensors({
    this.leftCm = 255,
    this.centerCm = 255,
    this.rightCm = 255,
  });

  bool get allClear => leftCm == 255 && centerCm == 255 && rightCm == 255;

  ParkingSensors copyWith({int? leftCm, int? centerCm, int? rightCm}) {
    return ParkingSensors(
      leftCm: leftCm ?? this.leftCm,
      centerCm: centerCm ?? this.centerCm,
      rightCm: rightCm ?? this.rightCm,
    );
  }

  @override
  String toString() =>
      'ParkingSensors(L:${leftCm}cm C:${centerCm}cm R:${rightCm}cm)';
}

/// Climate / HVAC state from the VAN bus.
class ClimateState {
  final double tempSet;
  final bool acOn;
  final int fanSpeed;

  const ClimateState({
    this.tempSet = 0,
    this.acOn = false,
    this.fanSpeed = 0,
  });

  ClimateState copyWith({double? tempSet, bool? acOn, int? fanSpeed}) {
    return ClimateState(
      tempSet: tempSet ?? this.tempSet,
      acOn: acOn ?? this.acOn,
      fanSpeed: fanSpeed ?? this.fanSpeed,
    );
  }

  @override
  String toString() =>
      'Climate(set:$tempSet°C ac:$acOn fan:$fanSpeed)';
}

/// Aggregated vehicle state built from VAN bus messages.
class VehicleState {
  /// External temperature in Celsius (null = not yet received).
  final double? externalTemp;

  /// Vehicle speed in km/h from the VAN bus (null = not yet received).
  final double? speed;

  /// Engine RPM from the VAN bus (null = not yet received).
  final double? rpm;

  /// Door open/close state.
  final DoorStatus doorStatus;

  /// Rear parking-sensor distances.
  final ParkingSensors parkingSensors;

  /// Climate / HVAC state.
  final ClimateState climate;

  /// Vehicle Identification Number.
  final String? vin;

  /// The most recent steering-wheel button events.
  final List<SteeringEvent> steeringButtons;

  /// Raw messages kept for the debug monitor (newest first, capped).
  final List<VanMessage> rawMessages;

  const VehicleState({
    this.externalTemp,
    this.speed,
    this.rpm,
    this.doorStatus = const DoorStatus(),
    this.parkingSensors = const ParkingSensors(),
    this.climate = const ClimateState(),
    this.vin,
    this.steeringButtons = const [],
    this.rawMessages = const [],
  });

  VehicleState copyWith({
    double? externalTemp,
    double? speed,
    double? rpm,
    DoorStatus? doorStatus,
    ParkingSensors? parkingSensors,
    ClimateState? climate,
    String? vin,
    List<SteeringEvent>? steeringButtons,
    List<VanMessage>? rawMessages,
  }) {
    return VehicleState(
      externalTemp: externalTemp ?? this.externalTemp,
      speed: speed ?? this.speed,
      rpm: rpm ?? this.rpm,
      doorStatus: doorStatus ?? this.doorStatus,
      parkingSensors: parkingSensors ?? this.parkingSensors,
      climate: climate ?? this.climate,
      vin: vin ?? this.vin,
      steeringButtons: steeringButtons ?? this.steeringButtons,
      rawMessages: rawMessages ?? this.rawMessages,
    );
  }
}
