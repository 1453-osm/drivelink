import 'package:drivelink/features/obd/domain/models/dtc_code.dart';
import 'package:drivelink/features/obd/domain/models/obd_data.dart';

/// Contract for communicating with an OBD-II adapter (ELM327).
abstract class ObdRepository {
  /// Continuous stream of aggregated OBD sensor data.
  Stream<ObdData> get dataStream;

  /// Whether the ELM327 serial connection is currently open.
  bool get isConnected;

  /// Open the serial connection and initialise the ELM327 adapter.
  Future<void> connect();

  /// Gracefully close the serial connection and stop polling.
  Future<void> disconnect();

  /// Read stored diagnostic trouble codes from the ECU.
  Future<List<DtcCode>> readDtcCodes();

  /// Send "clear DTC" command to the ECU (Mode 04).
  Future<void> clearDtcCodes();
}
