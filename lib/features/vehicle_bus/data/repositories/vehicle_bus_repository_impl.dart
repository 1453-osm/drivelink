import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:drivelink/features/vehicle_bus/data/datasources/esp32_serial_source.dart';
import 'package:drivelink/features/vehicle_bus/data/parsers/peugeot_206_parser.dart';
import 'package:drivelink/features/vehicle_bus/domain/models/van_message.dart';
import 'package:drivelink/features/vehicle_bus/domain/models/vehicle_state.dart';
import 'package:drivelink/features/vehicle_bus/domain/repositories/vehicle_bus_repository.dart';

/// Concrete [VehicleBusRepository] backed by the ESP32 USB serial gateway.
///
/// Each incoming [VanMessage] is folded into the running [VehicleState]
/// via the Peugeot 206 parser (swap the parser for other vehicles).
class VehicleBusRepositoryImpl implements VehicleBusRepository {
  VehicleBusRepositoryImpl({Esp32SerialSource? serialSource})
      : _serial = serialSource ?? Esp32SerialSource();

  final Esp32SerialSource _serial;

  final _stateController = StreamController<VehicleState>.broadcast();
  final _messageController = StreamController<VanMessage>.broadcast();
  StreamSubscription<VanMessage>? _sub;
  StreamSubscription<bool>? _connectionSub;

  Timer? _reconnectTimer;
  bool _autoReconnect = false;
  bool _disposed = false;
  static const _reconnectInterval = Duration(seconds: 5);

  VehicleState _state = const VehicleState();

  // ── VehicleBusRepository ──────────────────────────────────────────────

  @override
  Stream<VehicleState> get vehicleStateStream => _stateController.stream;

  @override
  Stream<VanMessage> get messageStream => _messageController.stream;

  @override
  bool get isConnected => _serial.isConnected;

  @override
  Future<void> connect() async {
    _autoReconnect = true;
    await _openSerial();
    _startReconnectWatch();
  }

  Future<void> _openSerial() async {
    if (_serial.isConnected) return;
    try {
      await _serial.connect();
      _sub ??= _serial.messageStream.listen((message) {
        _messageController.add(message);
        _state = Peugeot206Parser.apply(_state, message);
        _stateController.add(_state);
      });
    } catch (e) {
      debugPrint('[VAN] connect failed: $e');
      rethrow;
    }
  }

  /// Start a periodic watchdog that retries [_openSerial] whenever the link
  /// is down. Safe to call multiple times.
  void _startReconnectWatch() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(_reconnectInterval, (_) async {
      if (_disposed || !_autoReconnect) return;
      if (_serial.isConnected) return;
      try {
        await _openSerial();
        debugPrint('[VAN] reconnected');
      } catch (_) {
        // Swallow — next tick will retry.
      }
    });
  }

  @override
  Future<void> disconnect() async {
    _autoReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _sub?.cancel();
    _sub = null;
    await _connectionSub?.cancel();
    _connectionSub = null;
    await _serial.disconnect();
    _state = const VehicleState();
  }

  /// Release stream controllers. Call once on app dispose.
  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _stateController.close();
    await _messageController.close();
    await _serial.dispose();
  }
}
