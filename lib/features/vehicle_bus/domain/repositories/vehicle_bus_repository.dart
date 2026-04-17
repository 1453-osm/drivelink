import 'package:drivelink/features/vehicle_bus/domain/models/van_message.dart';
import 'package:drivelink/features/vehicle_bus/domain/models/vehicle_state.dart';

/// Contract for communicating with the vehicle VAN/CAN bus gateway.
abstract class VehicleBusRepository {
  /// Continuous stream of parsed [VehicleState] snapshots.
  Stream<VehicleState> get vehicleStateStream;

  /// Raw [VanMessage] stream for debugging / monitoring.
  Stream<VanMessage> get messageStream;

  /// Whether the serial connection is currently open.
  bool get isConnected;

  /// Open the serial connection to the ESP32 gateway.
  Future<void> connect();

  /// Gracefully close the serial connection.
  Future<void> disconnect();
}
