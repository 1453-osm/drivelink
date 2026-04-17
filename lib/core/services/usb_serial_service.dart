import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:usb_serial/usb_serial.dart';
import 'package:usb_serial/transaction.dart';

import '../constants/app_constants.dart';

// ---------------------------------------------------------------------------
// Device type enum
// ---------------------------------------------------------------------------
enum UsbDeviceType {
  esp32VanBus,
  elm327Obd,
  unknown,
}

// ---------------------------------------------------------------------------
// Connection state
// ---------------------------------------------------------------------------
enum UsbConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

// ---------------------------------------------------------------------------
// Device descriptor
// ---------------------------------------------------------------------------
class UsbDeviceInfo {
  final UsbDevice device;
  final UsbDeviceType type;
  final UsbConnectionState connectionState;
  final String? errorMessage;

  const UsbDeviceInfo({
    required this.device,
    required this.type,
    this.connectionState = UsbConnectionState.disconnected,
    this.errorMessage,
  });

  UsbDeviceInfo copyWith({
    UsbDevice? device,
    UsbDeviceType? type,
    UsbConnectionState? connectionState,
    String? errorMessage,
  }) {
    return UsbDeviceInfo(
      device: device ?? this.device,
      type: type ?? this.type,
      connectionState: connectionState ?? this.connectionState,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  String get label {
    switch (type) {
      case UsbDeviceType.esp32VanBus:
        return 'ESP32 VAN Bus';
      case UsbDeviceType.elm327Obd:
        return 'ELM327 OBD-II';
      case UsbDeviceType.unknown:
        return device.productName ?? 'Unknown Device';
    }
  }
}

// ---------------------------------------------------------------------------
// Known VID/PID pairs for auto-detection
// ---------------------------------------------------------------------------
class _KnownDevice {
  final int vid;
  final int pid;
  final UsbDeviceType type;
  const _KnownDevice(this.vid, this.pid, this.type);
}

const _knownDevices = [
  // Silicon Labs CP2102 (common ESP32 boards)
  _KnownDevice(0x10C4, 0xEA60, UsbDeviceType.esp32VanBus),
  // FTDI FT232R (common ELM327 clones)
  _KnownDevice(0x0403, 0x6001, UsbDeviceType.elm327Obd),
  // CH340 (cheap ESP32 boards)
  _KnownDevice(0x1A86, 0x7523, UsbDeviceType.esp32VanBus),
  // Prolific PL2303 (some ELM327 cables)
  _KnownDevice(0x067B, 0x2303, UsbDeviceType.elm327Obd),
];

// ---------------------------------------------------------------------------
// USB Serial Service
// ---------------------------------------------------------------------------
class UsbSerialService {
  UsbSerialService();

  final Map<String, UsbPort?> _openPorts = {};
  final Map<String, StreamSubscription?> _readSubscriptions = {};
  final Map<String, Transaction<String>?> _transactions = {};
  Timer? _reconnectTimer;
  bool _disposed = false;

  // Stream controllers
  final _devicesController = StreamController<List<UsbDeviceInfo>>.broadcast();
  final _dataController = StreamController<UsbDataEvent>.broadcast();
  final _connectionStateController =
      StreamController<Map<String, UsbConnectionState>>.broadcast();

  /// Currently known devices and their states.
  final Map<String, UsbDeviceInfo> _devices = {};

  // ---- Public streams ----

  Stream<List<UsbDeviceInfo>> get devicesStream => _devicesController.stream;
  Stream<UsbDataEvent> get dataStream => _dataController.stream;
  Stream<Map<String, UsbConnectionState>> get connectionStateStream =>
      _connectionStateController.stream;

  List<UsbDeviceInfo> get devices => _devices.values.toList();

  // ---- Lifecycle ----

  /// Begin scanning for USB devices and start auto-reconnect loop.
  Future<void> init() async {
    await refreshDevices();
    _startAutoReconnect();

    // Listen for USB attach / detach events
    UsbSerial.usbEventStream?.listen((UsbEvent event) async {
      await refreshDevices();
    });
  }

  /// Scan for connected USB devices and auto-detect their type.
  Future<List<UsbDeviceInfo>> refreshDevices() async {
    final rawDevices = await UsbSerial.listDevices();

    final discovered = <String, UsbDeviceInfo>{};
    for (final d in rawDevices) {
      final key = _deviceKey(d);
      final type = _detectType(d);
      final existing = _devices[key];
      discovered[key] = UsbDeviceInfo(
        device: d,
        type: type,
        connectionState:
            existing?.connectionState ?? UsbConnectionState.disconnected,
        errorMessage: existing?.errorMessage,
      );
    }

    // Close ports for devices that were removed
    for (final key in _devices.keys.toList()) {
      if (!discovered.containsKey(key)) {
        await _closePort(key);
      }
    }

    _devices
      ..clear()
      ..addAll(discovered);
    _emitDevices();
    return devices;
  }

  // ---- Connect / Disconnect ----

  /// Connect to a specific device by its key.
  Future<bool> connect(UsbDevice device) async {
    final key = _deviceKey(device);
    final info = _devices[key];
    if (info == null) return false;

    if (info.connectionState == UsbConnectionState.connected) return true;

    _updateState(key, UsbConnectionState.connecting);

    try {
      final port = await device.create();
      if (port == null) {
        _updateState(key, UsbConnectionState.error,
            error: 'Port oluşturulamadı');
        return false;
      }

      final opened = await port.open();
      if (!opened) {
        _updateState(key, UsbConnectionState.error,
            error: 'Port açılamadı');
        return false;
      }

      // Configure baud rate based on device type
      final baudRate = info.type == UsbDeviceType.elm327Obd
          ? AppConstants.elm327BaudRate
          : AppConstants.esp32BaudRate;

      await port.setDTR(true);
      await port.setRTS(true);
      await port.setPortParameters(
        baudRate,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      _openPorts[key] = port;

      // Set up read stream
      final transaction = Transaction.stringTerminated(
        port.inputStream!,
        Uint8List.fromList([13, 10]), // CR+LF
      );
      _transactions[key] = transaction;

      _readSubscriptions[key] = transaction.stream.listen(
        (data) {
          if (!_disposed) {
            _dataController.add(UsbDataEvent(
              deviceKey: key,
              deviceType: info.type,
              data: data.trim(),
            ));
          }
        },
        onError: (e) {
          _updateState(key, UsbConnectionState.error,
              error: e.toString());
          _closePort(key);
        },
        onDone: () {
          _updateState(key, UsbConnectionState.disconnected);
          _closePort(key);
        },
      );

      _updateState(key, UsbConnectionState.connected);

      // If ELM327, verify with ATZ probe
      if (info.type == UsbDeviceType.elm327Obd) {
        await _probeElm327(key);
      }

      return true;
    } catch (e) {
      _updateState(key, UsbConnectionState.error, error: e.toString());
      return false;
    }
  }

  /// Connect to all detected devices.
  Future<void> connectAll() async {
    for (final info in _devices.values) {
      if (info.connectionState != UsbConnectionState.connected) {
        await connect(info.device);
      }
    }
  }

  /// Disconnect a specific device.
  Future<void> disconnect(UsbDevice device) async {
    final key = _deviceKey(device);
    await _closePort(key);
    _updateState(key, UsbConnectionState.disconnected);
  }

  /// Disconnect all devices.
  Future<void> disconnectAll() async {
    for (final key in _openPorts.keys.toList()) {
      await _closePort(key);
    }
  }

  // ---- Write ----

  /// Send a raw string command to a device. Appends CR by default.
  Future<void> write(
    UsbDevice device,
    String command, {
    bool appendCR = true,
  }) async {
    final key = _deviceKey(device);
    final port = _openPorts[key];
    if (port == null) return;

    final payload = appendCR ? '$command\r' : command;
    await port.write(Uint8List.fromList(utf8.encode(payload)));
  }

  /// Send raw bytes to a device.
  Future<void> writeBytes(UsbDevice device, Uint8List data) async {
    final key = _deviceKey(device);
    final port = _openPorts[key];
    if (port == null) return;

    await port.write(data);
  }

  /// Send a command and wait for a response with timeout.
  Future<String?> sendCommand(
    UsbDevice device,
    String command, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final key = _deviceKey(device);
    final transaction = _transactions[key];
    if (transaction == null) return null;

    final port = _openPorts[key];
    if (port == null) return null;

    await port.write(Uint8List.fromList(utf8.encode('$command\r')));

    try {
      final response = await transaction.stream.first.timeout(timeout);
      return response.trim();
    } on TimeoutException {
      return null;
    }
  }

  // ---- Helpers ----

  /// Get the first connected device of a given type.
  UsbDeviceInfo? getDeviceByType(UsbDeviceType type) {
    return _devices.values.cast<UsbDeviceInfo?>().firstWhere(
          (d) =>
              d!.type == type &&
              d.connectionState == UsbConnectionState.connected,
          orElse: () => null,
        );
  }

  /// Unique key for a USB device.
  String _deviceKey(UsbDevice d) => '${d.vid}:${d.pid}:${d.deviceId}';

  /// Detect device type by VID/PID.
  UsbDeviceType _detectType(UsbDevice d) {
    for (final known in _knownDevices) {
      if (d.vid == known.vid && d.pid == known.pid) {
        return known.type;
      }
    }
    // Fallback: check product name
    final name = (d.productName ?? '').toLowerCase();
    if (name.contains('elm') || name.contains('obd')) {
      return UsbDeviceType.elm327Obd;
    }
    if (name.contains('esp') || name.contains('cp210') || name.contains('ch34')) {
      return UsbDeviceType.esp32VanBus;
    }
    return UsbDeviceType.unknown;
  }

  /// Probe an ELM327 device with ATZ to confirm identity.
  Future<void> _probeElm327(String key) async {
    final port = _openPorts[key];
    if (port == null) return;

    await port.write(Uint8List.fromList(utf8.encode('ATZ\r')));
    // Response will arrive through the data stream
  }

  Future<void> _closePort(String key) async {
    await _readSubscriptions[key]?.cancel();
    _readSubscriptions.remove(key);
    _transactions.remove(key);

    try {
      await _openPorts[key]?.close();
    } catch (_) {}
    _openPorts.remove(key);
  }

  void _updateState(
    String key,
    UsbConnectionState state, {
    String? error,
  }) {
    final existing = _devices[key];
    if (existing == null) return;
    _devices[key] = existing.copyWith(
      connectionState: state,
      errorMessage: error,
    );
    _emitDevices();
    _connectionStateController.add({
      for (final e in _devices.entries) e.key: e.value.connectionState,
    });
  }

  void _emitDevices() {
    if (!_disposed) {
      _devicesController.add(devices);
    }
  }

  /// Periodically attempt to reconnect disconnected devices.
  void _startAutoReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) async {
        if (_disposed) return;
        await refreshDevices();
        for (final info in _devices.values) {
          if (info.connectionState == UsbConnectionState.disconnected ||
              info.connectionState == UsbConnectionState.error) {
            await connect(info.device);
          }
        }
      },
    );
  }

  /// Dispose all resources.
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    disconnectAll();
    _devicesController.close();
    _dataController.close();
    _connectionStateController.close();
  }
}

// ---------------------------------------------------------------------------
// Data event
// ---------------------------------------------------------------------------
class UsbDataEvent {
  final String deviceKey;
  final UsbDeviceType deviceType;
  final String data;

  const UsbDataEvent({
    required this.deviceKey,
    required this.deviceType,
    required this.data,
  });

  @override
  String toString() => 'UsbDataEvent($deviceType, $data)';
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

final usbSerialServiceProvider = Provider<UsbSerialService>((ref) {
  final service = UsbSerialService();
  service.init();
  ref.onDispose(() => service.dispose());
  return service;
});

final usbDevicesProvider = StreamProvider<List<UsbDeviceInfo>>((ref) {
  final service = ref.watch(usbSerialServiceProvider);
  return service.devicesStream;
});

final usbDataStreamProvider = StreamProvider<UsbDataEvent>((ref) {
  final service = ref.watch(usbSerialServiceProvider);
  return service.dataStream;
});

final usbConnectionStateProvider =
    StreamProvider<Map<String, UsbConnectionState>>((ref) {
  final service = ref.watch(usbSerialServiceProvider);
  return service.connectionStateStream;
});
