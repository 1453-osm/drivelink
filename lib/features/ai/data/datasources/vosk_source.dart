import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vosk_flutter_service/vosk_flutter.dart';

/// Unified Vosk manager handling both speech recognition and wake word.
///
/// Android's Vosk SpeechService can only run one recognizer at a time.
/// This class manages a shared model and switches between:
/// - **Wake word mode**: grammar-restricted recognizer (["abidin", "[unk]"])
/// - **Speech mode**: full Turkish speech recognizer
class VoskSource {
  VoskSource();

  VoskFlutterPlugin? _vosk;
  Model? _model;

  // Two recognizers sharing one model
  Recognizer? _speechRecognizer; // Full speech recognition
  Recognizer? _wakeWordRecognizer; // Grammar-restricted wake word

  SpeechService? _activeSpeechService;

  bool _initialized = false;
  bool _isListening = false;
  bool _isWakeWordListening = false;

  final _wakeWordController = StreamController<void>.broadcast();

  // ── Configuration ────────────────────────────────────────────────────

  /// Direct method channel for native SpeechService cleanup when Dart
  /// reference is lost (hot restart, crash, or failed init).
  static const _voskChannel = MethodChannel('vosk_flutter');

  static const String modelName = 'vosk-model-small-tr-0.3';
  static const String _modelUrl =
      'https://alphacephei.com/vosk/models/$modelName.zip';
  static const int _sampleRate = 16000;

  /// Wake word to detect.
  static const String wakeWord = 'abidin';
  static const List<String> _grammar = [wakeWord, '[unk]'];

  /// Maximum listening duration before auto-stop.
  static const Duration maxListenDuration = Duration(seconds: 15);

  /// Stop after this much silence.
  static const Duration silenceTimeout = Duration(seconds: 5);

  // ── Public API ───────────────────────────────────────────────────────

  bool get isInitialized => _initialized;
  bool get isListening => _isListening;
  bool get isWakeWordListening => _isWakeWordListening;

  /// Stream that fires when wake word "abidin" is detected.
  Stream<void> get onWakeWord => _wakeWordController.stream;

  /// Initialize model + both recognizers. Downloads model on first run (~50MB).
  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      _vosk = VoskFlutterPlugin.instance();
      final loader = ModelLoader();

      String modelPath;
      if (await loader.isModelAlreadyLoaded(modelName)) {
        modelPath = await loader.modelPath(modelName);
      } else {
        modelPath = await loader.loadFromNetwork(_modelUrl);
      }

      _model = await _vosk!.createModel(modelPath);

      // Full speech recognizer (no grammar restriction)
      _speechRecognizer = await _vosk!.createRecognizer(
        model: _model!,
        sampleRate: _sampleRate,
      );

      // Wake word recognizer (grammar-restricted)
      _wakeWordRecognizer = await _vosk!.createRecognizer(
        model: _model!,
        sampleRate: _sampleRate,
        grammar: _grammar,
      );

      _initialized = true;
      return true;
    } catch (e) {
      debugPrint('[Vosk] initialize error: $e');
      _initialized = false;
      return false;
    }
  }

  // ── Speech recognition ───────────────────────────────────────────────

  /// Start full speech recognition. Returns stream of partial/final results.
  Stream<Map<String, String>> startListening() {
    if (!_initialized || _isListening) {
      return const Stream.empty();
    }

    final controller = StreamController<Map<String, String>>();
    _isListening = true;
    _startService(_speechRecognizer!, controller, isWakeWord: false);
    return controller.stream;
  }

  /// Stop speech recognition.
  Future<void> stopListening() async {
    if (!_isListening) return;
    _isListening = false;
    await _stopActiveService();
  }

  // ── Wake word detection ──────────────────────────────────────────────

  /// Start wake word detection. Fires [onWakeWord] when "abidin" detected.
  Future<bool> startWakeWord() async {
    if (!_initialized) {
      debugPrint('[Vosk] startWakeWord: not initialized');
      return false;
    }
    if (_isWakeWordListening) return true;

    _isWakeWordListening = true;
    final controller = StreamController<Map<String, String>>();
    try {
      await _startService(_wakeWordRecognizer!, controller, isWakeWord: true);
    } catch (e) {
      debugPrint('[Vosk] startWakeWord error: $e');
      _isWakeWordListening = false;
    }
    return _isWakeWordListening;
  }

  /// Stop wake word detection.
  Future<void> stopWakeWord() async {
    if (!_isWakeWordListening) return;
    _isWakeWordListening = false;
    await _stopActiveService();
  }

  // ── Lifecycle ────────────────────────────────────────────────────────

  void dispose() {
    stopListening();
    stopWakeWord();
    _activeSpeechService?.dispose();
    _speechRecognizer?.dispose();
    _wakeWordRecognizer?.dispose();
    _model?.dispose();
    _wakeWordController.close();
    _initialized = false;
  }

  // ── Private ──────────────────────────────────────────────────────────

  Future<void> _startService(
    Recognizer recognizer,
    StreamController<Map<String, String>> controller, {
    required bool isWakeWord,
  }) async {
    // Ensure previous service is fully released
    await _stopActiveService();

    // Try up to 3 times — native SpeechService singleton may need time to
    // fully release after dispose() (which is fire-and-forget void).
    for (var attempt = 0; attempt < 3; attempt++) {
      // Increasing delay: 100ms, 500ms, 1000ms
      final delay = attempt == 0 ? 100 : 500 * attempt;
      await Future.delayed(Duration(milliseconds: delay));

      try {
        debugPrint('[Vosk] _startService attempt ${attempt + 1} (wakeWord=$isWakeWord)');
        _activeSpeechService = await _vosk!.initSpeechService(recognizer);

        _activeSpeechService!.onPartial().listen((raw) {
          final text = _extractField(raw, 'partial');
          if (text.isEmpty) return;

          if (isWakeWord) {
            if (text == wakeWord && !_wakeWordController.isClosed) {
              _wakeWordController.add(null);
            }
          } else {
            if (!controller.isClosed) controller.add({'partial': text});
          }
        });

        _activeSpeechService!.onResult().listen((raw) {
          final text = _extractField(raw, 'text');

          if (isWakeWord) {
            if (text == wakeWord && !_wakeWordController.isClosed) {
              _wakeWordController.add(null);
            }
          } else {
            if (!controller.isClosed) controller.add({'text': text});
          }
        });

        await _activeSpeechService!.start();
        debugPrint('[Vosk] _startService: started OK (wakeWord=$isWakeWord)');
        return; // Success
      } catch (e) {
        final isStale = e.toString().contains('already exist');
        debugPrint('[Vosk] _startService attempt ${attempt + 1} failed: $e');

        if (isStale && attempt < 2) {
          // Native singleton not yet destroyed — force-destroy and retry
          debugPrint('[Vosk] Stale native SpeechService, destroying and retrying...');
          try {
            await _voskChannel.invokeMethod<void>('speechService.destroy');
          } catch (_) {}
          continue;
        }

        // Final attempt or non-recoverable error
        if (isWakeWord) {
          _isWakeWordListening = false;
        } else {
          _isListening = false;
          if (!controller.isClosed) {
            controller.addError(e);
            controller.close();
          }
        }
        return;
      }
    }
  }

  Future<void> _stopActiveService() async {
    final service = _activeSpeechService;
    _activeSpeechService = null;

    if (service != null) {
      try {
        await service.stop();
      } catch (e) {
        debugPrint('[Vosk] stop error: $e');
      }
      try {
        await service.dispose();
      } catch (e) {
        debugPrint('[Vosk] dispose error: $e');
      }
    } else {
      // No Dart reference but native singleton may exist (hot restart, crash,
      // or a previous initSpeechService that partially succeeded).
      // Force-destroy via direct method channel call.
      try {
        await _voskChannel.invokeMethod<void>('speechService.destroy');
        debugPrint('[Vosk] Destroyed stale native SpeechService via channel');
      } catch (_) {
        // Expected if no native singleton exists
      }
    }
  }

  String _extractField(String raw, String field) {
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return (decoded[field] ?? '').toString().trim();
    } catch (_) {
      return raw.trim();
    }
  }
}
