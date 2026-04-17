import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart' as ja;

import 'package:drivelink/core/services/sherpa_tts_engine.dart';

// ---------------------------------------------------------------------------
// Navigation instruction types
// ---------------------------------------------------------------------------
enum NavInstruction {
  turnRight,
  turnLeft,
  turnSharpRight,
  turnSharpLeft,
  turnSlightRight,
  turnSlightLeft,
  goStraight,
  roundabout,
  roundaboutExit1,
  roundaboutExit2,
  roundaboutExit3,
  roundaboutExit4,
  uTurn,
  mergeLeft,
  mergeRight,
  exitHighway,
  arrivedDestination,
  arrivedWaypoint,
  keepLeft,
  keepRight,
  ferryBoard,
  ferryExit,
  speedWarning,
  cameraWarning,
}

// ---------------------------------------------------------------------------
// Turkish instruction templates
// ---------------------------------------------------------------------------
const _instructionTemplates = <NavInstruction, String>{
  NavInstruction.turnRight: 'Saga donun',
  NavInstruction.turnLeft: 'Sola donun',
  NavInstruction.turnSharpRight: 'Keskin saga donun',
  NavInstruction.turnSharpLeft: 'Keskin sola donun',
  NavInstruction.turnSlightRight: 'Hafif saga donun',
  NavInstruction.turnSlightLeft: 'Hafif sola donun',
  NavInstruction.goStraight: 'Duz devam edin',
  NavInstruction.roundabout: 'Donel kavsaktan gecin',
  NavInstruction.roundaboutExit1: 'Donel kavsaktan birinci cikisi alin',
  NavInstruction.roundaboutExit2: 'Donel kavsaktan ikinci cikisi alin',
  NavInstruction.roundaboutExit3: 'Donel kavsaktan ucuncu cikisi alin',
  NavInstruction.roundaboutExit4: 'Donel kavsaktan dorduncu cikisi alin',
  NavInstruction.uTurn: 'U donusu yapin',
  NavInstruction.mergeLeft: 'Sola kaynaklanin',
  NavInstruction.mergeRight: 'Saga kaynaklanin',
  NavInstruction.exitHighway: 'Otoyol cikisini alin',
  NavInstruction.arrivedDestination: 'Hedefinize ulastiniz',
  NavInstruction.arrivedWaypoint: 'Ara noktaya ulastiniz',
  NavInstruction.keepLeft: 'Soldan devam edin',
  NavInstruction.keepRight: 'Sagdan devam edin',
  NavInstruction.ferryBoard: 'Feribota binin',
  NavInstruction.ferryExit: 'Feribottan inin',
  NavInstruction.speedWarning: 'Hiz limitini asiyorsunuz',
  NavInstruction.cameraWarning: 'Hiz kamerasi yaklasiyorsunuz',
};

// ---------------------------------------------------------------------------
// Distance prefix templates
// ---------------------------------------------------------------------------
String _distancePrefix(int meters) {
  if (meters >= 1000) {
    final km = (meters / 1000).toStringAsFixed(1);
    return '${km} kilometre sonra, ';
  }
  // Round to nearest 50
  final rounded = ((meters + 25) ~/ 50) * 50;
  return '$rounded metre sonra, ';
}

// ---------------------------------------------------------------------------
// TTS queue entry
// ---------------------------------------------------------------------------
class _TtsQueueEntry {
  final String text;
  final bool interruptible;
  final int priority; // lower = higher priority

  const _TtsQueueEntry({
    required this.text,
    this.interruptible = true,
    this.priority = 5,
  });
}

// ---------------------------------------------------------------------------
// TTS Service
// ---------------------------------------------------------------------------
class TtsService {
  TtsService();

  final FlutterTts _tts = FlutterTts();
  final SherpaTtsEngine _sherpa = SherpaTtsEngine();
  ja.AudioPlayer? _sherpaPlayer;

  final Queue<_TtsQueueEntry> _queue = Queue();
  bool _isSpeaking = false;
  bool _disposed = false;
  bool _initialized = false;
  bool _sherpaReady = false;
  bool _forceSystemTts = false;
  StreamSubscription<ja.PlayerState>? _sherpaPlayerSub;
  Completer<void>? _initCompleter;

  final _speakingController = StreamController<bool>.broadcast();
  Completer<void>? _doneCompleter;

  // ---- Public API ----

  Stream<bool> get speakingStream => _speakingController.stream;
  bool get isSpeaking => _isSpeaking;
  SherpaTtsEngine get sherpaEngine => _sherpa;
  bool get isSherpaReady => _sherpaReady;

  /// Force system TTS (bypass Sherpa) when another just_audio player is active.
  /// Prevents audio focus conflicts between two just_audio instances.
  void setForceSystemTts(bool force) {
    _forceSystemTts = force;
  }

  /// Wait for init() to complete. Safe to call multiple times.
  Future<void> ensureInitialized() async {
    if (_initCompleter != null) await _initCompleter!.future;
  }

  /// Initialize TTS engine with Turkish language.
  Future<void> init() async {
    if (_initialized) return;
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();

    try {

    await _tts.setLanguage('tr-TR');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    // Try to set a Turkish voice if available
    final voices = await _tts.getVoices;
    if (voices is List) {
      for (final voice in voices) {
        if (voice is Map) {
          final locale = (voice['locale'] ?? '').toString().toLowerCase();
          if (locale.contains('tr')) {
            await _tts.setVoice({
              'name': voice['name'].toString(),
              'locale': voice['locale'].toString(),
            });
            break;
          }
        }
      }
    }

    _tts.setCompletionHandler(() {
      _onSpeakDone();
    });

    _tts.setErrorHandler((msg) {
      debugPrint('[TTS] Error: $msg');
      _onSpeakDone();
    });

    _tts.setCancelHandler(() {
      _isSpeaking = false;
      _speakingController.add(false);
    });

    _initialized = true;
    _initCompleter!.complete();

    // Try to initialize Sherpa TTS (if model downloaded)
    _initSherpa();
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }

  Future<void> _initSherpa() async {
    _sherpaReady = await _sherpa.initialize();
    if (_sherpaReady) {
      debugPrint('[TTS] Sherpa TTS ready (fahrettin voice)');
    }
  }

  /// Speak a navigation instruction with optional distance prefix.
  Future<void> speakNavInstruction(
    NavInstruction instruction, {
    int? distanceMeters,
    String? streetName,
    bool interrupt = false,
    int priority = 3,
  }) async {
    final template = _instructionTemplates[instruction] ?? '';
    if (template.isEmpty) return;

    final buffer = StringBuffer();

    if (distanceMeters != null && distanceMeters > 0) {
      buffer.write(_distancePrefix(distanceMeters));
    }

    buffer.write(template);

    if (streetName != null && streetName.isNotEmpty) {
      buffer.write(', $streetName');
    }

    await speak(
      buffer.toString(),
      interrupt: interrupt,
      priority: priority,
    );
  }

  /// Speak arbitrary text.
  Future<void> speak(
    String text, {
    bool interrupt = false,
    int priority = 5,
  }) async {
    if (_disposed || text.isEmpty) return;
    await init();

    if (interrupt) {
      await _stopCurrent();
      _queue.clear();
    }

    _queue.add(_TtsQueueEntry(
      text: text,
      interruptible: true,
      priority: priority,
    ));

    // Sort queue by priority (stable sort: lower number = higher priority)
    final sorted = _queue.toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    _queue
      ..clear()
      ..addAll(sorted);

    if (!_isSpeaking) {
      _processQueue();
    }
  }

  /// Speak a speed warning.
  Future<void> speakSpeedWarning(int currentSpeed, int limitSpeed) async {
    await speak(
      'Dikkat! Hiz limitini asiyorsunuz. '
      'Mevcut hiz: $currentSpeed, limit: $limitSpeed kilometre.',
      interrupt: true,
      priority: 1,
    );
  }

  /// Speak a camera warning.
  Future<void> speakCameraWarning(int distanceMeters) async {
    await speak(
      '${_distancePrefix(distanceMeters)}hiz kamerasi var.',
      interrupt: false,
      priority: 2,
    );
  }

  /// Speak a short phrase and wait for it to finish.
  /// Bypasses the queue — used for immediate audio feedback (e.g., "Buyrun").
  Future<void> speakAndWait(String text) async {
    if (_disposed || text.isEmpty) return;
    await init();
    await _stopCurrent();
    _queue.clear();

    _isSpeaking = true;
    _speakingController.add(true);

    await _tts.awaitSpeakCompletion(true);
    try {
      await _tts.speak(text);
    } finally {
      await _tts.awaitSpeakCompletion(false);
      _isSpeaking = false;
      _speakingController.add(false);
    }
  }

  /// Stop speaking and clear the queue.
  Future<void> stopAll() async {
    _queue.clear();
    await _stopCurrent();
    _doneCompleter?.complete();
    _doneCompleter = null;
  }

  /// Stop only the current utterance (queue continues).
  Future<void> _stopCurrent() async {
    if (_isSpeaking) {
      await _tts.stop();
      _isSpeaking = false;
      _speakingController.add(false);
    }
  }

  // ---- Settings ----

  Future<void> setSpeechRate(double rate) async {
    await _tts.setSpeechRate(rate.clamp(0.1, 1.0));
  }

  Future<void> setVolume(double volume) async {
    await _tts.setVolume(volume.clamp(0.0, 1.0));
  }

  Future<void> setPitch(double pitch) async {
    await _tts.setPitch(pitch.clamp(0.5, 2.0));
  }

  // ---- Queue processing ----

  Future<void> _processQueue() async {
    if (_disposed || _isSpeaking || _queue.isEmpty) return;

    final entry = _queue.removeFirst();
    _isSpeaking = true;
    _speakingController.add(true);

    if (_sherpaReady && !_forceSystemTts) {
      await _speakWithSherpa(entry.text);
    } else {
      await _tts.speak(entry.text);
    }
  }

  Future<void> _speakWithSherpa(String text) async {
    try {
      final wavPath = await _sherpa.generateWav(text, speed: 0.85);
      if (wavPath == null || _disposed) {
        _onSpeakDone();
        return;
      }

      _sherpaPlayer ??= ja.AudioPlayer();
      await _sherpaPlayer!.setFilePath(wavPath);
      // Cancel previous subscription to prevent leaks and missed completions
      _sherpaPlayerSub?.cancel();
      _sherpaPlayerSub = _sherpaPlayer!.playerStateStream.listen((state) {
        if (state.processingState == ja.ProcessingState.completed) {
          _onSpeakDone();
          try { File(wavPath).deleteSync(); } catch (_) {}
        }
      });
      await _sherpaPlayer!.play();
    } catch (e) {
      debugPrint('[TTS] Sherpa playback error: $e');
      // Fallback to system TTS
      await _tts.speak(text);
    }
  }

  void _onSpeakDone() {
    _isSpeaking = false;
    _speakingController.add(false);
    if (_queue.isEmpty) {
      _doneCompleter?.complete();
      _doneCompleter = null;
    } else {
      _processQueue();
    }
  }

  /// Wait for all queued speech to finish playing.
  ///
  /// Returns immediately if nothing is playing. Times out after 30s as safety.
  Future<void> waitUntilDone() async {
    if (!_isSpeaking && _queue.isEmpty) return;
    _doneCompleter ??= Completer<void>();
    return _doneCompleter!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('[TTS] waitUntilDone timed out');
        _isSpeaking = false;
        _speakingController.add(false);
        _queue.clear();
        _doneCompleter?.complete();
        _doneCompleter = null;
      },
    );
  }

  // ---- Cleanup ----

  void dispose() {
    _disposed = true;
    _tts.stop();
    _sherpaPlayerSub?.cancel();
    _sherpaPlayer?.dispose();
    _sherpa.dispose();
    _queue.clear();
    _speakingController.close();
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Awaitable provider that ensures the TTS service is fully initialized.
final ttsServiceInitProvider = FutureProvider<TtsService>((ref) async {
  final service = ref.watch(ttsServiceProvider);
  await service.init();
  return service;
});

final ttsSpeakingProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(ttsServiceProvider);
  return service.speakingStream;
});
