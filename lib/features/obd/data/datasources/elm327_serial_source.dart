import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:usb_serial/usb_serial.dart';

import 'package:drivelink/core/services/usb_device_matcher.dart';
import 'package:drivelink/features/obd/domain/models/pid.dart';

/// Low-level ELM327 OBD-II adapter communication over USB serial.
///
/// Uses Completer-based request/response with echo validation for race-free
/// serial communication. Polling is sequential with adaptive PID removal:
/// non-responding PIDs are automatically skipped after a few failures.
class Elm327SerialSource {
  static const int _defaultBaudRate = 38400;
  static const Duration _commandTimeout = Duration(milliseconds: 2000);
  static const Duration _pollTimeout = Duration(milliseconds: 500);
  static const Duration _initTimeout = Duration(milliseconds: 5000);
  static const int _maxPidFailures = 3;

  UsbPort? _port;
  StreamSubscription<Uint8List>? _inputSub;
  final _connectionController = StreamController<bool>.broadcast();
  final StringBuffer _responseBuffer = StringBuffer();

  /// Single pending response — only one command in flight at a time.
  Completer<String>? _pendingResponse;

  /// Expected echo prefix for the current OBD command (e.g. "410C" for RPM).
  /// Null for AT commands — any response is accepted.
  String? _expectedEchoPrefix;

  bool _connected = false;
  bool _polling = false;
  bool _commandBusy = false;

  List<Pid> _allActivePids = [];
  List<Pid> _fastPids = [];
  List<Pid> _slowPids = [];
  int _slowIndex = 0;

  /// Tracks consecutive failures per PID to skip non-responding ones.
  final Map<String, int> _pidFailCount = {};

  bool get isConnected => _connected;

  /// Emits `true` on connect, `false` on disconnect.
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Called for each successful PID response during polling.
  void Function(Pid pid, String response)? onPidResponse;

  // ── Connection ──────────────────────────────────────────────────────

  /// Connect to an ELM327 adapter and run the AT initialisation sequence.
  Future<void> connect({UsbDevice? device}) async {
    if (_connected) return;

    final target = device ??
        UsbDeviceMatcher.pick(
          await UsbSerial.listDevices(),
          UsbAdapterRole.elm327Obd,
        );
    if (target == null) {
      throw StateError('ELM327 OBD adaptörü bulunamadı');
    }

    debugPrint(
        '[ELM327] connecting to ${target.productName} (vid=${target.vid} pid=${target.pid})');

    _port = await target.create();
    if (_port == null) {
      throw StateError(
          'USB port oluşturulamadı: ${target.productName}');
    }

    final opened = await _port!.open();
    if (!opened) {
      throw StateError('USB port açılamadı');
    }

    await _port!.setDTR(true);
    await _port!.setRTS(true);
    await _port!.setPortParameters(
      _defaultBaudRate,
      UsbPort.DATABITS_8,
      UsbPort.STOPBITS_1,
      UsbPort.PARITY_NONE,
    );

    _inputSub = _port!.inputStream?.listen(
      _onData,
      onError: (_) => _handleDisconnect(),
      onDone: _handleDisconnect,
    );

    _connected = true;
    _connectionController.add(true);

    // Flush any stale data from the adapter
    await Future.delayed(const Duration(milliseconds: 100));
    _responseBuffer.clear();
    _pendingResponse = null;
    _pidFailCount.clear();

    await _initElm327();
  }

  /// ELM327 AT initialisation sequence with retry on reset.
  Future<void> _initElm327() async {
    // Reset — try up to 3 times
    String? response;
    for (var i = 0; i < 3 && _connected; i++) {
      response = await _sendRaw('ATZ', timeout: _initTimeout);
      if (response != null &&
          (response.toUpperCase().contains('ELM') ||
              response.contains('OK'))) {
        break;
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (!_connected) return;

    await _sendRaw('ATE0'); // Echo off
    await _sendRaw('ATL0'); // Linefeeds off
    await _sendRaw('ATS0'); // Spaces off (some clones ignore — OK)
    await _sendRaw('ATH0'); // Headers off
    await _sendRaw('ATAT2'); // Adaptive timing — aggressive
    await _sendRaw('ATSP0'); // Auto-detect protocol

    await Future.delayed(const Duration(milliseconds: 200));
  }

  // ── Polling ─────────────────────────────────────────────────────────

  /// Start sequential round-robin polling.
  ///
  /// RPM and Speed are queried every cycle (fast). All other PIDs rotate
  /// one per cycle (slow). Non-responding PIDs are automatically skipped
  /// after [_maxPidFailures] consecutive failures, and retried every ~50
  /// cycles.
  void startPolling(List<Pid> pids) {
    _allActivePids = List.of(pids);
    _fastPids =
        pids.where((p) => p.code == '010C' || p.code == '010D').toList();
    _slowPids =
        pids.where((p) => p.code != '010C' && p.code != '010D').toList();
    _slowIndex = 0;
    _polling = true;
    _runPollingLoop(); // fire-and-forget async loop
  }

  /// Stop the polling loop. Current in-flight query will finish naturally.
  void stopPolling() {
    _polling = false;
  }

  /// Resume polling without resetting the slow-PID rotation index.
  void _resumePolling() {
    if (_allActivePids.isEmpty) return;
    _polling = true;
    _runPollingLoop();
  }

  Future<void> _runPollingLoop() async {
    var consecutiveErrors = 0;

    while (_polling && _connected) {
      // ── Fast PIDs (RPM, Speed) every cycle ──
      for (final pid in _fastPids) {
        if (!_polling || !_connected) return;
        if (_shouldSkipPid(pid.code)) continue;
        final ok = await _queryPid(pid);
        consecutiveErrors = ok ? 0 : consecutiveErrors + 1;
      }

      // ── One slow PID per cycle (rotated) ──
      if (_slowPids.isNotEmpty && _polling && _connected) {
        final pid = _slowPids[_slowIndex % _slowPids.length];
        _slowIndex++;

        // Periodically reset fail counts to allow retries (~every 50 cycles)
        if (_slowIndex % (_slowPids.length * 7) == 0) {
          _pidFailCount.clear();
        }

        if (!_shouldSkipPid(pid.code)) {
          final ok = await _queryPid(pid);
          consecutiveErrors = ok ? 0 : consecutiveErrors + 1;
        }
      }

      // ── Health check: too many consecutive errors → reinit ──
      if (consecutiveErrors > 20) {
        consecutiveErrors = 0;
        await _sendRaw('ATZ', timeout: _initTimeout);
        await Future.delayed(const Duration(seconds: 1));
        await _initElm327();
      }
    }
  }

  bool _shouldSkipPid(String code) {
    return (_pidFailCount[code] ?? 0) >= _maxPidFailures;
  }

  Future<bool> _queryPid(Pid pid) async {
    final response = await _sendRaw(pid.code, timeout: _pollTimeout);
    if (response == null) {
      _pidFailCount[pid.code] = (_pidFailCount[pid.code] ?? 0) + 1;
      return false;
    }

    final upper = response.toUpperCase();
    if (upper.contains('NODATA') ||
        upper.contains('NO DATA') ||
        upper.contains('ERROR') ||
        upper.contains('UNABLE') ||
        upper.contains('STOPPED') ||
        upper.contains('BUSERROR') ||
        upper.contains('CANERROR')) {
      _pidFailCount[pid.code] = (_pidFailCount[pid.code] ?? 0) + 1;
      return false;
    }

    _pidFailCount[pid.code] = 0; // Reset on success
    onPidResponse?.call(pid, response);
    return true;
  }

  // ── Serial I/O (Completer-based with echo validation) ─────────────

  /// Send a command and wait for the '>' prompt. Internal — no polling
  /// pause/resume logic.
  Future<String?> _sendRaw(String command, {Duration? timeout}) async {
    if (_port == null || !_connected) return null;

    // Complete any stale pending response
    _completePending('');
    _responseBuffer.clear();
    _pendingResponse = Completer<String>();

    // Set expected echo prefix for OBD commands so stale responses
    // from previous (timed-out) commands are automatically discarded.
    _setExpectedEcho(command);

    final bytes = Uint8List.fromList(utf8.encode('$command\r'));
    await _port!.write(bytes);

    _commandBusy = true;
    try {
      final raw = await _pendingResponse!.future
          .timeout(timeout ?? _commandTimeout);
      return raw.isEmpty ? null : raw;
    } on TimeoutException {
      _pendingResponse = null;
      _responseBuffer.clear();
      return null;
    } catch (_) {
      _pendingResponse = null;
      return null;
    } finally {
      _commandBusy = false;
    }
  }

  /// Public command API. Pauses polling if active, sends command, resumes.
  ///
  /// Used by the repository for supported-PID queries and DTC commands.
  Future<String?> sendCommand(String command, {Duration? timeout}) async {
    final wasPolling = _polling;
    if (wasPolling) _polling = false;

    // Wait for in-flight polling query to finish
    while (_commandBusy) {
      await Future.delayed(const Duration(milliseconds: 20));
    }

    final response = await _sendRaw(command, timeout: timeout);

    if (wasPolling && _connected) {
      _resumePolling();
    }

    return response;
  }

  void _setExpectedEcho(String command) {
    final upper = command.toUpperCase();
    if (upper.length >= 4 && upper.startsWith('01')) {
      // Mode 01 PID query: "010C" → expect "410C"
      _expectedEchoPrefix = '41${upper.substring(2)}';
    } else if (upper == '03') {
      _expectedEchoPrefix = '43';
    } else if (upper == '04') {
      _expectedEchoPrefix = '44';
    } else {
      // AT commands — accept any response
      _expectedEchoPrefix = null;
    }
  }

  // ── Response processing ─────────────────────────────────────────────

  /// Accumulate USB chunks and process all complete responses ('>'-delimited).
  void _onData(Uint8List data) {
    final chunk = utf8.decode(data, allowMalformed: true);
    _responseBuffer.write(chunk);
    _processResponseBuffer();
  }

  /// Walk through the buffer, split on '>' prompts, and handle each response.
  ///
  /// Stale responses from timed-out commands are automatically discarded via
  /// echo-prefix validation — this prevents the off-by-one bug where a late
  /// response for command A would be attributed to command B.
  void _processResponseBuffer() {
    while (true) {
      final buffered = _responseBuffer.toString();
      final promptIdx = buffered.indexOf('>');
      if (promptIdx < 0) return; // No complete response yet

      // Extract response before '>' and keep remaining data
      final raw = buffered.substring(0, promptIdx);
      final remaining = buffered.substring(promptIdx + 1);
      _responseBuffer
        ..clear()
        ..write(remaining);

      final cleaned = _cleanResponse(raw);
      if (cleaned.isEmpty) continue;

      final upper = cleaned.toUpperCase().replaceAll(' ', '');

      // AT commands: no echo validation, accept anything
      if (_expectedEchoPrefix == null) {
        _completePending(cleaned);
        return;
      }

      // ELM327 error/status responses: accept without echo check
      // (these are valid responses to the current command)
      if (_isElm327Error(upper)) {
        _completePending(cleaned);
        return;
      }

      // OBD data responses: validate echo prefix to reject stale data
      if (!upper.contains(_expectedEchoPrefix!)) {
        // Stale response from a previous timed-out command — discard
        continue;
      }

      _completePending(cleaned);
      return;
    }
  }

  bool _isElm327Error(String upper) {
    return upper.contains('NODATA') ||
        upper.contains('ERROR') ||
        upper.contains('UNABLE') ||
        upper.contains('STOPPED') ||
        upper.contains('CANERROR') ||
        upper.contains('BUSERROR') ||
        upper.contains('BUFFERFULL');
  }

  void _completePending(String value) {
    if (_pendingResponse != null && !_pendingResponse!.isCompleted) {
      _pendingResponse!.complete(value);
    }
    _pendingResponse = null;
  }

  String _cleanResponse(String raw) {
    return raw
        .replaceAll('>', '')
        .replaceAll('\r', '')
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'SEARCHING\.\.\.'), '')
        .replaceAll(RegExp(r'BUS INIT:.*'), '')
        .trim();
  }

  // ── DTC commands ────────────────────────────────────────────────────

  /// Mode 03 — read stored DTCs.
  Future<String?> readDtcRaw() => sendCommand('03');

  /// Mode 04 — clear stored DTCs.
  Future<String?> clearDtcRaw() => sendCommand('04');

  // ── Lifecycle ───────────────────────────────────────────────────────

  void _handleDisconnect() {
    _connected = false;
    _polling = false;
    _completePending('');
    _inputSub?.cancel();
    _inputSub = null;
    try {
      _port?.close();
    } catch (_) {}
    _port = null;
    if (!_connectionController.isClosed) {
      _connectionController.add(false);
    }
  }

  Future<void> disconnect() async {
    _polling = false;
    _completePending('');
    await _inputSub?.cancel();
    _inputSub = null;
    try {
      await _port?.close();
    } catch (_) {}
    _port = null;
    _responseBuffer.clear();
    _connected = false;
    if (!_connectionController.isClosed) {
      _connectionController.add(false);
    }
  }

  Future<void> dispose() async {
    await disconnect();
    await _connectionController.close();
  }
}
