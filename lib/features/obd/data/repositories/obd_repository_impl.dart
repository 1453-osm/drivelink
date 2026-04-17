import 'dart:async';

import 'package:drivelink/features/obd/data/datasources/elm327_serial_source.dart';
import 'package:drivelink/features/obd/data/parsers/dtc_parser.dart';
import 'package:drivelink/features/obd/data/parsers/obd_pid_parser.dart';
import 'package:drivelink/features/obd/domain/models/dtc_code.dart';
import 'package:drivelink/features/obd/domain/models/obd_data.dart';
import 'package:drivelink/features/obd/domain/models/pid.dart';
import 'package:drivelink/features/obd/domain/repositories/obd_repository.dart';

/// Concrete [ObdRepository] backed by an ELM327 USB serial adapter.
class ObdRepositoryImpl implements ObdRepository {
  ObdRepositoryImpl({Elm327SerialSource? serialSource})
      : _serial = serialSource ?? Elm327SerialSource();

  final Elm327SerialSource _serial;
  final _dataController = StreamController<ObdData>.broadcast();

  ObdData _data = const ObdData();

  // ── ObdRepository ─────────────────────────────────────────────────────

  @override
  Stream<ObdData> get dataStream => _dataController.stream;

  @override
  bool get isConnected => _serial.isConnected;

  /// Exposes the serial source's connection events for reactive UI.
  Stream<bool> get connectionStream => _serial.connectionStream;

  @override
  Future<void> connect() async {
    await _serial.connect();

    // Discover supported PIDs across all ranges (0100, 0120, 0140).
    final supported = await _querySupportedPids();
    if (supported.isNotEmpty) {
      _data = _data.copyWith(supportedPids: supported);
    }

    // Filter standard PIDs to those the ECU supports.
    // Fall back to querying everything if detection yields nothing useful.
    var pidsToQuery = supported.isNotEmpty
        ? Pid.standardPids
            .where((p) => supported.contains(p.code))
            .toList()
        : Pid.standardPids;

    if (pidsToQuery.isEmpty) {
      pidsToQuery = Pid.standardPids;
    }

    // Wire the PID-response callback → update data → push to stream.
    _serial.onPidResponse = (pid, response) {
      _data = ObdPidParser.apply(_data, pid, response);
      if (!_dataController.isClosed) {
        _dataController.add(_data);
      }
    };

    _serial.startPolling(pidsToQuery);
  }

  /// Query 0100 → 0120 → 0140 to discover all supported PIDs.
  ///
  /// Each range is only queried if the previous range's "next range"
  /// indicator PID (0x20, 0x40) is reported as supported.
  Future<Set<String>> _querySupportedPids() async {
    final all = <String>{};

    // Range 01–20 — first OBD query triggers protocol detection, so use
    // a long timeout (up to 12 s on some vehicles).
    final raw0100 = await _serial.sendCommand('0100',
        timeout: const Duration(seconds: 12));
    if (raw0100 != null) {
      all.addAll(
          ObdPidParser.parseSupportedPids(raw0100, baseRange: 0x00));
    }

    // Range 21–40 (only if PID 0x20 is supported)
    if (all.contains('0120')) {
      final raw0120 = await _serial.sendCommand('0120');
      if (raw0120 != null) {
        all.addAll(
            ObdPidParser.parseSupportedPids(raw0120, baseRange: 0x20));
      }
    }

    // Range 41–60 (only if PID 0x40 is supported)
    if (all.contains('0140')) {
      final raw0140 = await _serial.sendCommand('0140');
      if (raw0140 != null) {
        all.addAll(
            ObdPidParser.parseSupportedPids(raw0140, baseRange: 0x40));
      }
    }

    return all;
  }

  @override
  Future<void> disconnect() async {
    _serial.onPidResponse = null;
    await _serial.disconnect();
    _data = const ObdData();
  }

  @override
  Future<List<DtcCode>> readDtcCodes() async {
    final raw = await _serial.readDtcRaw();
    if (raw == null) return [];
    return DtcParser.parse(raw);
  }

  @override
  Future<void> clearDtcCodes() async {
    await _serial.clearDtcRaw();
  }

  /// Release resources. Call once on app dispose.
  Future<void> dispose() async {
    await disconnect();
    await _dataController.close();
    await _serial.dispose();
  }
}
