import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:usb_serial/usb_serial.dart';

import 'package:drivelink/core/services/usb_device_matcher.dart';
import 'package:drivelink/features/vehicle_bus/domain/models/van_message.dart';
import 'package:drivelink/features/vehicle_bus/data/parsers/van_message_parser.dart';

/// Communicates with the ESP32 VAN-bus gateway over USB serial.
///
/// The ESP32 firmware sends newline-delimited JSON objects such as:
/// ```json
/// {"type":"TEMP","data":{"external":22.5}}
/// ```
class Esp32SerialSource {
  static const int _baudRate = 115200;
  // Runaway-line protection: ESP frames stay under 300 bytes.
  static const int _maxLineBytes = 4096;

  UsbPort? _port;
  StreamSubscription<Uint8List>? _subscription;
  final _messageController = StreamController<VanMessage>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  /// Byte-level buffer for incomplete lines across USB packets. Split at
  /// raw 0x0A / 0x0D bytes so utf8 decoding always sees complete lines —
  /// avoids U+FFFD replacement on multi-byte boundaries.
  final List<int> _byteBuffer = [];

  /// Diagnostic counters — read via [stats] for UI / logging.
  int _bytesIn = 0;
  int _linesParsed = 0;
  int _parseErrors = 0;

  Map<String, int> get stats => {
        'bytes': _bytesIn,
        'parsed': _linesParsed,
        'errors': _parseErrors,
      };

  /// Parsed [VanMessage] stream.
  Stream<VanMessage> get messageStream => _messageController.stream;

  /// Emits `true` on connect, `false` on disconnect.
  Stream<bool> get connectionStream => _connectionController.stream;

  bool _connected = false;
  bool get isConnected => _connected;

  /// Lists all USB serial devices currently attached.
  Future<List<UsbDevice>> listDevices() async {
    return UsbSerial.listDevices();
  }

  /// Opens the ESP32 VAN-bus gateway (auto-detected by VID/PID) or [device]
  /// if provided, and starts reading JSON lines.
  Future<void> connect({UsbDevice? device}) async {
    if (_connected) return;

    final all = await UsbSerial.listDevices();
    debugPrint('[ESP32] ${all.length} USB device(s) found');
    for (final d in all) {
      debugPrint(
          '[ESP32]   ${d.productName ?? '?'} vid=${d.vid} pid=${d.pid} mfr=${d.manufacturerName ?? '?'}');
    }

    final target = device ??
        UsbDeviceMatcher.pick(all, UsbAdapterRole.esp32VanBus);
    if (target == null) {
      throw StateError('ESP32 VAN-bus adaptörü bulunamadı');
    }

    debugPrint(
        '[ESP32] opening ${target.productName} (vid=${target.vid} pid=${target.pid})');

    _port = await target.create();
    if (_port == null) {
      throw StateError('USB port oluşturulamadı: ${target.productName}');
    }

    final opened = await _port!.open();
    if (!opened) {
      _port = null;
      throw StateError('USB port açılamadı: ${target.productName}');
    }

    // Set port parameters BEFORE wiring the stream — some CH340/CP210x
    // drivers flush the read buffer when parameters change.
    await _port!.setPortParameters(
      _baudRate,
      UsbPort.DATABITS_8,
      UsbPort.STOPBITS_1,
      UsbPort.PARITY_NONE,
    );
    await _port!.setDTR(true);
    await _port!.setRTS(true);

    // inputStream can return null on certain drivers / permission races —
    // catch it explicitly so "connected but no data" is reported as an error.
    final stream = _port!.inputStream;
    if (stream == null) {
      try {
        await _port!.close();
      } catch (_) {}
      _port = null;
      throw StateError(
          'USB inputStream null — sürücü okuma akışını açmadı');
    }

    _byteBuffer.clear();
    _bytesIn = 0;
    _linesParsed = 0;
    _parseErrors = 0;

    _subscription = stream.listen(
      _onData,
      onError: _onError,
      onDone: _onDone,
      cancelOnError: false,
    );

    _connected = true;
    _connectionController.add(true);
    debugPrint('[ESP32] connected @ $_baudRate baud, waiting for VAN frames…');
  }

  /// Split incoming bytes at newline boundaries, then UTF-8 decode each
  /// complete line and hand it to [_parseLine].
  void _onData(Uint8List data) {
    _bytesIn += data.length;

    // First data callback — confirm the stream is alive.
    if (_bytesIn == data.length) {
      debugPrint('[ESP32] first bytes received (${data.length} B)');
    }

    for (var i = 0; i < data.length; i++) {
      final b = data[i];
      if (b == 0x0A || b == 0x0D) {
        if (_byteBuffer.isEmpty) continue;
        try {
          final line =
              utf8.decode(_byteBuffer, allowMalformed: true).trim();
          _byteBuffer.clear();
          if (line.isNotEmpty) _parseLine(line);
        } catch (e) {
          _byteBuffer.clear();
          _parseErrors++;
          debugPrint('[ESP32] decode error: $e');
        }
      } else {
        if (_byteBuffer.length >= _maxLineBytes) {
          _byteBuffer.clear();
          _parseErrors++;
          debugPrint('[ESP32] runaway line discarded (> $_maxLineBytes B)');
          continue;
        }
        _byteBuffer.add(b);
      }
    }
  }

  void _parseLine(String line) {
    final message = VanMessageParser.parse(line);
    if (message != null) {
      _linesParsed++;
      if (_linesParsed <= 5 || _linesParsed % 100 == 0) {
        debugPrint(
            '[ESP32] parsed #$_linesParsed type=${message.type} data=${message.data}');
      }
      _messageController.add(message);
    } else {
      _parseErrors++;
      debugPrint('[ESP32] parse fail: $line');
    }
  }

  void _onError(Object error) {
    debugPrint('[ESP32] stream error: $error');
    _connected = false;
    if (!_connectionController.isClosed) {
      _connectionController.add(false);
    }
  }

  void _onDone() {
    debugPrint(
        '[ESP32] stream closed (bytes=$_bytesIn parsed=$_linesParsed errors=$_parseErrors)');
    _connected = false;
    if (!_connectionController.isClosed) {
      _connectionController.add(false);
    }
  }

  /// Closes the serial port and cleans up resources.
  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _port?.close();
    } catch (_) {}
    _port = null;
    _byteBuffer.clear();
    _connected = false;
    if (!_connectionController.isClosed) {
      _connectionController.add(false);
    }
  }

  /// Release all stream controllers. Call once on app dispose.
  Future<void> dispose() async {
    await disconnect();
    await _messageController.close();
    await _connectionController.close();
  }
}
