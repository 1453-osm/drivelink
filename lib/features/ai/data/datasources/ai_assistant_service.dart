import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:drivelink/core/services/audio_service.dart';
import 'package:drivelink/core/services/tts_service.dart';
import 'package:drivelink/features/ai/data/datasources/gemini_source.dart';
import 'package:drivelink/features/ai/data/datasources/groq_source.dart';
import 'package:drivelink/features/ai/data/datasources/openrouter_source.dart';
import 'package:drivelink/features/ai/data/datasources/vosk_source.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:drivelink/features/ai/data/parsers/intent_parser.dart';
import 'package:drivelink/features/ai/domain/models/ai_response.dart';
import 'package:drivelink/features/ai/domain/models/intent.dart';
import 'package:drivelink/features/media/data/playlist_store.dart';
import 'package:drivelink/features/obd/domain/models/obd_data.dart';
import 'package:drivelink/features/vehicle_bus/domain/models/vehicle_state.dart';

// ── Assistant state ────────────────────────────────────────────────────

enum AssistantState {
  idle,
  initializing,
  ready,
  listening,
  processing,
  speaking,
  error,
}

// ── State snapshot ─────────────────────────────────────────────────────

class AiAssistantSnapshot {
  final AssistantState state;
  final String? partialTranscript;
  final String? finalTranscript;
  final AiResponse? lastResponse;
  final List<AiResponse> history;
  final String? errorMessage;
  final bool wakeWordActive;
  final bool isOnline;
  final bool chatAvailable;

  const AiAssistantSnapshot({
    this.state = AssistantState.idle,
    this.partialTranscript,
    this.finalTranscript,
    this.lastResponse,
    this.history = const [],
    this.errorMessage,
    this.wakeWordActive = false,
    this.isOnline = false,
    this.chatAvailable = false,
  });

  AiAssistantSnapshot copyWith({
    AssistantState? state,
    String? partialTranscript,
    String? finalTranscript,
    AiResponse? lastResponse,
    List<AiResponse>? history,
    String? errorMessage,
    bool? wakeWordActive,
    bool? isOnline,
    bool? chatAvailable,
  }) {
    return AiAssistantSnapshot(
      state: state ?? this.state,
      partialTranscript: partialTranscript ?? this.partialTranscript,
      finalTranscript: finalTranscript ?? this.finalTranscript,
      lastResponse: lastResponse ?? this.lastResponse,
      history: history ?? this.history,
      errorMessage: errorMessage ?? this.errorMessage,
      wakeWordActive: wakeWordActive ?? this.wakeWordActive,
      isOnline: isOnline ?? this.isOnline,
      chatAvailable: chatAvailable ?? this.chatAvailable,
    );
  }
}

// ── Main service ───────────────────────────────────────────────────────

/// Orchestrates the full AI assistant pipeline:
///
///   Wake word / button → Listening → Intent → [Action | Vehicle | Cloud chat] → TTS
///
/// Offline: action commands + vehicle data work without internet.
/// Online: conversational chat via Gemini API.
class AiAssistantService {
  AiAssistantService({required this.ttsService, required this.audioService});

  final TtsService ttsService;
  final DriveAudioService audioService;

  final VoskSource _vosk = VoskSource();
  final GeminiSource _gemini = GeminiSource();
  final OpenRouterSource _openRouter = OpenRouterSource();
  final GroqSource _groq = GroqSource();
  final IntentParser _intentParser = IntentParser();
  String _chatProvider = 'gemini';

  StreamSubscription<void>? _wakeWordSub;

  // External state fed by providers
  VehicleState _vehicleState = const VehicleState();
  ObdData _obdData = const ObdData();
  String _vehicleProfileName = 'Peugeot 206';
  bool _isOnline = false;

  bool _isProcessing = false;
  bool _deferredPlayback = false;

  final _stateController = StreamController<AiAssistantSnapshot>.broadcast();
  AiAssistantSnapshot _snapshot = const AiAssistantSnapshot();
  final List<AiResponse> _history = [];

  // ── Public API ───────────────────────────────────────────────────────

  Stream<AiAssistantSnapshot> get stateStream => _stateController.stream;
  AiAssistantSnapshot get currentSnapshot => _snapshot;
  bool get isReady =>
      _snapshot.state == AssistantState.ready ||
      _snapshot.state == AssistantState.idle;
  bool get isWakeWordActive => _vosk.isWakeWordListening;
  bool get isChatAvailable => _isOnline && _activeSourceConfigured;
  bool get _activeSourceConfigured => switch (_chatProvider) {
    'openrouter' => _openRouter.isConfigured,
    'groq' => _groq.isConfigured,
    _ => _gemini.isConfigured,
  };
  GeminiSource get gemini => _gemini;
  OpenRouterSource get openRouter => _openRouter;
  GroqSource get groq => _groq;
  String get chatProvider => _chatProvider;

  /// Initialize Vosk speech recognition.
  Future<void> initialize() async {
    _emit(_snapshot.copyWith(state: AssistantState.initializing));

    final voskOk = await _vosk.initialize();

    if (voskOk) {
      _emit(
        _snapshot.copyWith(state: AssistantState.ready, wakeWordActive: false),
      );
    } else {
      _emit(
        _snapshot.copyWith(
          state: AssistantState.error,
          errorMessage: 'Ses tanima modeli yuklenemedi',
        ),
      );
    }
  }

  /// Set Gemini API key.
  void setGeminiApiKey(String key) {
    _gemini.setApiKey(key);
    _emit(_snapshot.copyWith(chatAvailable: isChatAvailable));
  }

  /// Set OpenRouter API key.
  void setOpenRouterApiKey(String key) {
    _openRouter.setApiKey(key);
    _emit(_snapshot.copyWith(chatAvailable: isChatAvailable));
  }

  /// Set Gemini model.
  void setGeminiModel(String model) {
    _gemini.setModel(model);
    _emit(_snapshot.copyWith(chatAvailable: isChatAvailable));
  }

  /// Set OpenRouter model.
  void setOpenRouterModel(String model) {
    _openRouter.setModel(model);
    _emit(_snapshot.copyWith(chatAvailable: isChatAvailable));
  }

  /// Set Groq API key.
  void setGroqApiKey(String key) {
    _groq.setApiKey(key);
    _emit(_snapshot.copyWith(chatAvailable: isChatAvailable));
  }

  /// Set Groq model.
  void setGroqModel(String model) {
    _groq.setModel(model);
    _emit(_snapshot.copyWith(chatAvailable: isChatAvailable));
  }

  /// Switch the active cloud chat provider.
  void setChatProvider(String provider) {
    _chatProvider = switch (provider) {
      'openrouter' => 'openrouter',
      'groq' => 'groq',
      _ => 'gemini',
    };
    _emit(_snapshot.copyWith(chatAvailable: isChatAvailable));
  }

  /// Update connectivity state.
  void updateConnectivity(bool online) {
    _isOnline = online;
    _emit(_snapshot.copyWith(isOnline: online, chatAvailable: isChatAvailable));
  }

  Future<void> toggleWakeWord(bool enabled) async {
    if (enabled && !_vosk.isInitialized) {
      // Try to (re-)initialize Vosk if model wasn't loaded yet
      debugPrint('[AI] Wake word toggle: Vosk not initialized, retrying...');
      final ok = await _vosk.initialize();
      if (!ok) {
        debugPrint('[AI] Wake word: Vosk initialization failed');
        _emit(_snapshot.copyWith(wakeWordActive: false));
        return;
      }
      _emit(_snapshot.copyWith(state: AssistantState.ready));
    }

    if (!_vosk.isInitialized) return;

    if (enabled) {
      final success = await _startWakeWordDetection();
      if (!success) {
        debugPrint('[AI] Wake word: could not start');
        _emit(_snapshot.copyWith(wakeWordActive: false));
        return;
      }
    } else {
      await _stopWakeWordDetection();
    }
    _emit(_snapshot.copyWith(wakeWordActive: _vosk.isWakeWordListening));
  }

  /// Check if wake word should be active but got killed (e.g. by audio focus
  /// change when music starts). Restart if needed.
  Future<void> checkWakeWordHealth() async {
    if (!_snapshot.wakeWordActive || _isProcessing) return;
    if (_vosk.isWakeWordListening) return; // All good
    debugPrint('[AI] Wake word health check: not listening, restarting...');
    await _restartWakeWordWithRetry();
    _emit(_snapshot.copyWith(wakeWordActive: _vosk.isWakeWordListening));
  }

  void updateVehicleState(VehicleState state) {
    _vehicleState = state;
  }

  void updateObdData(ObdData data) {
    _obdData = data;
  }

  void updateVehicleProfile(String name) {
    _vehicleProfileName = name;
  }

  /// Activate via wake word or button press.
  Future<void> activate() async {
    if (_isProcessing) return;
    if (!_vosk.isInitialized) {
      await ttsService.speak(
        'Ses tanima henuz hazir degil, biraz bekle',
        interrupt: true,
      );
      return;
    }

    _isProcessing = true;
    _deferredPlayback = false;

    // Check music state BEFORE stopping wake word — stopWakeWord releases
    // the native audio session which can trigger audio focus changes.
    final currentStatus = audioService.currentState.status;
    final musicWasPlaying = currentStatus == PlaybackStatus.playing;
    final savedVolume = audioService.currentState.volume;
    debugPrint(
      '[AI] activate: status=$currentStatus, musicPlaying=$musicWasPlaying, volume=$savedVolume',
    );

    final wasWakeWordActive = _vosk.isWakeWordListening;
    if (wasWakeWordActive) {
      await _vosk.stopWakeWord();
    }

    // Duck music volume while AI is active — improves speech recognition
    // and prevents audio focus conflicts between Sherpa TTS and music player.
    if (musicWasPlaying) {
      await audioService.setVolume(0.15);
      ttsService.setForceSystemTts(true);
      debugPrint('[AI] Music ducked to 15%');
    }

    try {
      // Audio feedback so the user knows the app is listening
      await ttsService.speakAndWait('Buyrun');

      _emit(
        _snapshot.copyWith(
          state: AssistantState.listening,
          partialTranscript: null,
          finalTranscript: null,
        ),
      );

      final transcript = await _listenForTranscript();

      if (transcript.isEmpty) {
        _emit(_snapshot.copyWith(state: AssistantState.ready));
        await ttsService.speak(
          'Duyamadim, bir daha soyler misin?',
          interrupt: true,
        );
        return;
      }

      _emit(
        _snapshot.copyWith(
          state: AssistantState.processing,
          finalTranscript: transcript,
        ),
      );

      final intent = _intentParser.parse(transcript);
      final response = await _executeIntent(intent);
      final fullResponse = response.copyWith(userQuery: transcript);

      _history.add(fullResponse);
      _emit(
        _snapshot.copyWith(
          state: AssistantState.speaking,
          lastResponse: fullResponse,
          history: List.unmodifiable(_history),
        ),
      );

      await ttsService.speak(fullResponse.text, interrupt: true, priority: 1);
    } catch (e) {
      debugPrint('[AI] activate error: $e');
    } finally {
      _isProcessing = false;
      if (wasWakeWordActive) {
        // Wait for TTS to finish to prevent self-triggering wake word
        await ttsService.waitUntilDone();
        // Buffer for mic to settle after speaker stops (echo/reverb)
        await Future.delayed(const Duration(milliseconds: 800));
        await _restartWakeWordWithRetry();
      }

      // Restore music volume and TTS mode
      if (musicWasPlaying) {
        ttsService.setForceSystemTts(false);
        await audioService.setVolume(savedVolume);
      }

      // Start deferred music playback (after TTS done + wake word restarted)
      if (_deferredPlayback) {
        _deferredPlayback = false;
        await _ensurePlayback();
      }

      _emit(
        _snapshot.copyWith(
          state: AssistantState.ready,
          wakeWordActive: _vosk.isWakeWordListening,
        ),
      );
    }
  }

  /// Restart wake word detection with retries. Audio system may be busy
  /// right after music starts or TTS speaks, so we retry a few times.
  Future<void> _restartWakeWordWithRetry() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        if (attempt > 0) {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
        final ok = await _vosk.startWakeWord();
        if (ok) {
          // Re-subscribe in case the old subscription went stale.
          _wakeWordSub?.cancel();
          _wakeWordSub = _vosk.onWakeWord.listen((_) => activate());
          return;
        }
      } catch (e) {
        debugPrint('[AI] Wake word restart attempt ${attempt + 1} failed: $e');
      }
    }
    debugPrint('[AI] Wake word could not be restarted after 3 attempts');
  }

  /// Process a text command directly.
  Future<AiResponse> processText(String text) async {
    _deferredPlayback = false;
    try {
      _emit(
        _snapshot.copyWith(
          state: AssistantState.processing,
          finalTranscript: text,
        ),
      );

      final intent = _intentParser.parse(text);
      final response = await _executeIntent(intent);
      final fullResponse = response.copyWith(userQuery: text);

      _history.add(fullResponse);
      _emit(
        _snapshot.copyWith(
          state: AssistantState.speaking,
          lastResponse: fullResponse,
          history: List.unmodifiable(_history),
        ),
      );

      await ttsService.speak(fullResponse.text, interrupt: true, priority: 1);

      // Start deferred music playback after TTS
      if (_deferredPlayback) {
        _deferredPlayback = false;
        await ttsService.waitUntilDone();
        await _ensurePlayback();
      }

      return fullResponse;
    } catch (e) {
      debugPrint('[AI] processText error: $e');
      return AiResponse(
        text: 'Bir hata olustu, tekrar deneyin.',
        userQuery: text,
      );
    } finally {
      _emit(_snapshot.copyWith(state: AssistantState.ready));
    }
  }

  Future<void> cancel() async {
    await _vosk.stopListening();
    await ttsService.stopAll();
    _isProcessing = false;
    _emit(_snapshot.copyWith(state: AssistantState.ready));
  }

  void dispose() {
    _wakeWordSub?.cancel();
    _vosk.dispose();
    _stateController.close();
  }

  // ── Wake word ────────────────────────────────────────────────────────

  Future<bool> _startWakeWordDetection() async {
    if (!_vosk.isInitialized) {
      debugPrint('[AI] Wake word: Vosk henuz hazir degil');
      return false;
    }

    // Ensure microphone permission before starting
    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      debugPrint('[AI] Wake word: Requesting microphone permission');
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        debugPrint('[AI] Wake word: Mikrofon izni reddedildi');
        return false;
      }
    }

    // Retry up to 3 times — Android audio system may need time to release mic
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(milliseconds: 400 * attempt));
        debugPrint('[AI] Wake word start retry ${attempt + 1}');
      }

      final started = await _vosk.startWakeWord();
      if (started) {
        _wakeWordSub?.cancel();
        _wakeWordSub = _vosk.onWakeWord.listen((_) {
          activate();
        });
        debugPrint('[AI] Wake word detection active');
        return true;
      }
    }

    debugPrint('[AI] Wake word: 3 denemede de baslatilamadi');
    return false;
  }

  Future<void> _stopWakeWordDetection() async {
    _wakeWordSub?.cancel();
    _wakeWordSub = null;
    await _vosk.stopWakeWord();
  }

  // ── Speech recognition ───────────────────────────────────────────────

  /// Silence timeout for action commands (shorter for snappy response).
  static const _actionSilenceTimeout = Duration(milliseconds: 1500);

  Future<String> _listenForTranscript() async {
    try {
      final stream = _vosk.startListening();
      final completer = Completer<String>();

      String lastPartial = '';
      String finalText = '';
      bool earlyActionMatch = false;

      Timer? silenceTimer;
      final maxTimer = Timer(VoskSource.maxListenDuration, () {
        if (!completer.isCompleted) {
          _vosk.stopListening();
          completer.complete(finalText.isNotEmpty ? finalText : lastPartial);
        }
      });

      void completeWith(String text) {
        if (!completer.isCompleted) {
          _vosk.stopListening();
          completer.complete(text);
        }
      }

      final sub = stream.listen(
        (event) {
          if (event.containsKey('partial')) {
            lastPartial = event['partial']!;
            _emit(_snapshot.copyWith(partialTranscript: lastPartial));

            // ── Streaming intent match: check partial against action keywords.
            // If high-confidence action match found, use shorter silence timeout
            // so the command executes faster.
            final partialIntent = _intentParser.parse(lastPartial);
            if (partialIntent.action != 'AI_CHAT' &&
                partialIntent.action != 'UNKNOWN' &&
                partialIntent.confidence >= 0.85) {
              earlyActionMatch = true;
              // Use a very short silence timeout — the user likely finished
              // the command phrase.
              silenceTimer?.cancel();
              silenceTimer = Timer(_actionSilenceTimeout, () {
                completeWith(finalText.isNotEmpty ? finalText : lastPartial);
              });
              return;
            }

            silenceTimer?.cancel();
            silenceTimer = Timer(VoskSource.silenceTimeout, () {
              completeWith(finalText.isNotEmpty ? finalText : lastPartial);
            });
          } else if (event.containsKey('text')) {
            final text = event['text']!;
            if (text.isNotEmpty) {
              finalText = text;

              // If we already matched an action from partials, resolve
              // immediately on the final result.
              if (earlyActionMatch) {
                completeWith(finalText);
              }
            }
          }
        },
        onDone: () {
          completeWith(finalText.isNotEmpty ? finalText : lastPartial);
        },
        onError: (_) {
          if (!completer.isCompleted) completer.complete('');
        },
      );

      silenceTimer = Timer(VoskSource.silenceTimeout, () {
        completeWith(finalText.isNotEmpty ? finalText : lastPartial);
      });

      final result = await completer.future;
      maxTimer.cancel();
      silenceTimer?.cancel();
      await sub.cancel();
      await _vosk.stopListening();

      return result.trim();
    } catch (e) {
      await _vosk.stopListening();
      return '';
    }
  }

  // ── Conversation history ─────────────────────────────────────────────

  List<({String user, String assistant})> _buildChatHistory() {
    final relevant = _history
        .where((r) => r.userQuery != null && r.userQuery!.isNotEmpty)
        .toList();
    final start = (relevant.length - 4).clamp(0, relevant.length);
    return relevant
        .sublist(start)
        .map((r) => (user: r.userQuery!, assistant: r.text))
        .toList();
  }

  // ── Intent execution ─────────────────────────────────────────────────

  Future<AiResponse> _executeIntent(Intent intent) async {
    // ── 1. Action commands ────────────────────────────────────────
    final actionResponse = await _tryActionCommand(intent);
    if (actionResponse != null) return actionResponse;

    // ── 2. Loose action match (Turkish morphology) ────────────────
    final looseAction = await _tryLooseActionMatch(intent.transcript);
    if (looseAction != null) return looseAction;

    // ── 3. Vehicle data queries (real sensor data) ────────────────
    final vehicleResponse = _tryVehicleDataResponse(intent.transcript);
    if (vehicleResponse != null) return vehicleResponse;

    // ── 4. Conversation → Cloud or fallback ───────────────────────
    debugPrint(
      '[AI] Chat query: "${intent.transcript}" (provider=$_chatProvider, online=$_isOnline, configured=$_activeSourceConfigured)',
    );
    return _askCloud(intent.transcript);
  }

  Future<AiResponse?> _tryActionCommand(Intent intent) async {
    debugPrint(
      '[AI] Parsed intent: ${intent.action}, confidence: ${intent.confidence}',
    );
    switch (intent.action) {
      case 'NAV_HOME':
        return AiResponse(
          text: 'Eve yola cikiyoruz! Rotayi hazirliyorum.',
          navigateTo: '/navigation',
          actionExecuted: true,
          intentAction: intent.action,
        );
      case 'NAV_WORK':
        return AiResponse(
          text: 'Is yerine rota olusturuyorum, haydi baslayalim.',
          navigateTo: '/navigation',
          actionExecuted: true,
          intentAction: intent.action,
        );
      case 'NAV_SEARCH':
        final dest = intent.params['destination'] ?? '';
        return AiResponse(
          text: dest.isNotEmpty
              ? '$dest icin rotayi ciziyorum.'
              : 'Nereye gitmek istiyorsun?',
          navigateTo: dest.isNotEmpty ? '/navigation' : null,
          actionExecuted: dest.isNotEmpty,
          intentAction: intent.action,
        );
      case 'NAV_STOP':
        return AiResponse(
          text: 'Navigasyonu kapattim.',
          actionExecuted: true,
          intentAction: intent.action,
        );
      case 'NAV_NEARBY_GAS':
        return AiResponse(
          text: 'En yakin benzinligi buluyorum.',
          navigateTo: '/navigation',
          actionExecuted: true,
          intentAction: intent.action,
        );
      case 'NAV_NEARBY_PARKING':
        return AiResponse(
          text: 'Yakin bir otopark ariyorum.',
          navigateTo: '/navigation',
          actionExecuted: true,
          intentAction: intent.action,
        );
      case 'NAV_NEARBY_HOSPITAL':
        return AiResponse(
          text: 'En yakin hastaneyi ariyorum.',
          navigateTo: '/navigation',
          actionExecuted: true,
          intentAction: intent.action,
        );
      case 'VEHICLE_TRIP':
        return AiResponse(
          text: 'Trip ekranina yonlendiriyorum.',
          navigateTo: '/trip',
          actionExecuted: true,
          intentAction: intent.action,
        );
      case 'MEDIA_PLAY':
        if (audioService.currentState.status == PlaybackStatus.playing) {
          return AiResponse(
            text: 'Muzik zaten caliyor.',
            actionExecuted: true,
            intentAction: intent.action,
          );
        }
        // Defer playback to after TTS — prevents audio focus conflict
        final canPlay =
            audioService.hasPlaylist || await PlaylistStore.load() != null;
        _deferredPlayback = canPlay;
        return AiResponse(
          text: canPlay
              ? 'Muzigi baslatiyorum!'
              : 'Muzik dosyasi bulunamadi. Once muzik ekranından tarama yapin.',
          actionExecuted: canPlay,
          intentAction: intent.action,
        );
      case 'MEDIA_PAUSE':
        audioService.togglePlayPause();
        return AiResponse(
          text: 'Muzigi durdurdum.',
          actionExecuted: true,
          intentAction: intent.action,
        );
      case 'MEDIA_NEXT':
        audioService.next();
        return AiResponse(
          text: 'Siradaki parca geliyor.',
          actionExecuted: true,
          intentAction: intent.action,
        );
      case 'MEDIA_PREV':
        audioService.previous();
        return AiResponse(
          text: 'Onceki parcaya donuyorum.',
          actionExecuted: true,
          intentAction: intent.action,
        );
      case 'MEDIA_VOLUME_UP':
        audioService.volumeUp();
        return AiResponse(
          text: 'Sesi biraz actim.',
          actionExecuted: true,
          intentAction: intent.action,
        );
      case 'MEDIA_VOLUME_DOWN':
        audioService.volumeDown();
        return AiResponse(
          text: 'Sesi kistim biraz.',
          actionExecuted: true,
          intentAction: intent.action,
        );
      case 'SYSTEM_NIGHT_MODE':
        return AiResponse(
          text: 'Gece moduna gectim, gozlerin yorulmasin.',
          actionExecuted: true,
          intentAction: intent.action,
        );
      case 'SYSTEM_DAY_MODE':
        return AiResponse(
          text: 'Gunduz moduna aldim.',
          actionExecuted: true,
          intentAction: intent.action,
        );
      default:
        return null;
    }
  }

  // ── Turkish text normalization ─────────────────────────────────────

  static String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll('\u0131', 'i')
        .replaceAll('\u00f6', 'o')
        .replaceAll('\u00fc', 'u')
        .replaceAll('\u015f', 's')
        .replaceAll('\u00e7', 'c')
        .replaceAll('\u011f', 'g');
  }

  static bool _has(String text, String sub) => text.contains(sub);

  // ── Playback helper ─────────────────────────────────────────────

  /// Ensure music is playing. If no playlist is loaded, restore the saved
  /// playlist from disk and start playback. Returns true on success.
  Future<bool> _ensurePlayback() async {
    // Already playing? Toggle will pause — just return true.
    if (audioService.currentState.status == PlaybackStatus.playing) return true;

    // Playlist loaded? Use togglePlayPause which handles idle/paused states.
    if (audioService.hasPlaylist) {
      await audioService.togglePlayPause();
      return true;
    }

    // No playlist — try restoring from saved playlist.
    final saved = await PlaylistStore.load();
    if (saved == null) return false;

    final paths = <String>[];
    final infos = <TrackInfo>[];
    for (var i = 0; i < saved.paths.length; i++) {
      if (File(saved.paths[i]).existsSync()) {
        paths.add(saved.paths[i]);
        infos.add(
          i < saved.trackInfos.length
              ? saved.trackInfos[i]
              : TrackInfo(title: saved.paths[i].split('/').last),
        );
      }
    }
    if (paths.isEmpty) return false;

    await audioService.setPlaylist(
      paths,
      startIndex: saved.lastIndex.clamp(0, paths.length - 1),
      trackInfos: infos,
    );
    return true;
  }

  // ── Loose action matching ────────────────────────────────────────

  Future<AiResponse?> _tryLooseActionMatch(String transcript) async {
    final q = _normalize(transcript);

    if ((_has(q, 'muzi') || _has(q, 'sark') || _has(q, 'parc')) &&
        (_has(q, 'ac') ||
            _has(q, 'cal') ||
            _has(q, 'basl') ||
            _has(q, 'oynat'))) {
      if (audioService.currentState.status == PlaybackStatus.playing) {
        return AiResponse(
          text: 'Muzik zaten caliyor.',
          actionExecuted: true,
          intentAction: 'MEDIA_PLAY',
        );
      }
      final canPlay =
          audioService.hasPlaylist || await PlaylistStore.load() != null;
      _deferredPlayback = canPlay;
      return AiResponse(
        text: canPlay
            ? 'Muzigi baslatiyorum!'
            : 'Muzik dosyasi bulunamadi. Once muzik ekranından tarama yapin.',
        actionExecuted: canPlay,
        intentAction: 'MEDIA_PLAY',
      );
    }
    if ((_has(q, 'muzi') || _has(q, 'sark')) &&
        (_has(q, 'kapat') || _has(q, 'durdur') || _has(q, 'sus'))) {
      audioService.togglePlayPause();
      return AiResponse(
        text: 'Muzigi durdurdum.',
        actionExecuted: true,
        intentAction: 'MEDIA_PAUSE',
      );
    }
    if ((_has(q, 'sonra') || _has(q, 'sirada') || _has(q, 'atla')) &&
        (_has(q, 'sark') || _has(q, 'parc') || _has(q, 'muzi'))) {
      audioService.next();
      return AiResponse(
        text: 'Siradaki parca geliyor.',
        actionExecuted: true,
        intentAction: 'MEDIA_NEXT',
      );
    }
    if ((_has(q, 'once') || _has(q, 'geri')) &&
        (_has(q, 'sark') || _has(q, 'parc'))) {
      audioService.previous();
      return AiResponse(
        text: 'Onceki parcaya donuyorum.',
        actionExecuted: true,
        intentAction: 'MEDIA_PREV',
      );
    }
    if (_has(q, 'ses') &&
        (_has(q, 'ac') || _has(q, 'artt') || _has(q, 'yuksel'))) {
      audioService.volumeUp();
      return AiResponse(
        text: 'Sesi biraz actim.',
        actionExecuted: true,
        intentAction: 'MEDIA_VOLUME_UP',
      );
    }
    if (_has(q, 'ses') &&
        (_has(q, 'kis') || _has(q, 'azalt') || _has(q, 'dusur'))) {
      audioService.volumeDown();
      return AiResponse(
        text: 'Sesi kistim biraz.',
        actionExecuted: true,
        intentAction: 'MEDIA_VOLUME_DOWN',
      );
    }
    if ((_has(q, 'navigas') || _has(q, 'harita')) &&
        (_has(q, 'ac') || _has(q, 'basl'))) {
      return AiResponse(
        text: 'Navigasyonu aciyorum.',
        navigateTo: '/navigation',
        actionExecuted: true,
        intentAction: 'NAV_SEARCH',
      );
    }
    return null;
  }

  // ── Vehicle data responses (real sensor data) ────────────────────

  AiResponse? _tryVehicleDataResponse(String transcript) {
    final q = transcript.toLowerCase();
    final obd = _obdData;
    final vs = _vehicleState;

    bool obdConnected() =>
        obd.rpm != null ||
        obd.speed != null ||
        obd.coolantTemp != null ||
        obd.batteryVoltage != null;

    if (q.contains('obd') ||
        (q.contains('baglanti') && (q.contains('arac') || q.contains('elm')))) {
      if (!obdConnected())
        return AiResponse(
          text: 'OBD bagli degil, veri alamiyorum.',
          intentAction: 'VEHICLE_STATUS',
        );
      final parts = <String>[];
      if (obd.coolantTemp != null)
        parts.add('Motor ${obd.coolantTemp!.toStringAsFixed(0)}\u00b0C');
      if (obd.batteryVoltage != null)
        parts.add('Aku ${obd.batteryVoltage!.toStringAsFixed(1)}V');
      if (obd.rpm != null) parts.add('${obd.rpm!.toStringAsFixed(0)} RPM');
      return AiResponse(
        text: 'OBD bagli, ${parts.join(", ")}.',
        intentAction: 'VEHICLE_STATUS',
      );
    }
    if (q.contains('motor') &&
        (q.contains('sicak') ||
            q.contains('isi') ||
            q.contains('derece') ||
            q.contains('nasil'))) {
      final t = obd.coolantTemp;
      if (t != null) {
        final c = t > 100
            ? 'Dikkat, yuksek!'
            : t > 90
            ? 'Normal ama goz kulak ol.'
            : 'Gayet iyi.';
        return AiResponse(
          text: 'Motor ${t.toStringAsFixed(0)} derece. $c',
          intentAction: 'VEHICLE_ENGINE_TEMP',
        );
      }
      return AiResponse(
        text: 'Motor sicakligi verisi yok, OBD bagli degil.',
        intentAction: 'VEHICLE_ENGINE_TEMP',
      );
    }
    if (q.contains('dis') &&
        (q.contains('sicak') || q.contains('derece') || q.contains('hava'))) {
      final t = vs.externalTemp;
      if (t != null) {
        final c = t < 5
            ? ' Buzlanmaya dikkat!'
            : t > 35
            ? ' Sicak, klimayi ac.'
            : '';
        return AiResponse(
          text: 'Dis sicaklik ${t.toStringAsFixed(0)} derece.$c',
          intentAction: 'VEHICLE_TEMP',
        );
      }
      return AiResponse(
        text: 'Dis sicaklik verisi yok.',
        intentAction: 'VEHICLE_TEMP',
      );
    }
    if (q.contains('hiz') || q.contains('surat') || q.contains('kac')) {
      final s = obd.speed ?? vs.speed;
      if (s != null) {
        final c = s > 120
            ? ' Dikkatli ol!'
            : s == 0
            ? ' Duruyorsun.'
            : '';
        return AiResponse(
          text: '${s.toStringAsFixed(0)} km/h.$c',
          intentAction: 'VEHICLE_SPEED',
        );
      }
      return AiResponse(
        text: 'Hiz verisi yok, OBD bagli degil.',
        intentAction: 'VEHICLE_SPEED',
      );
    }
    if (q.contains('devir') || q.contains('rpm')) {
      final r = obd.rpm ?? vs.rpm;
      if (r != null) {
        final c = r > 4000 ? ' Yuksek, vites at.' : '';
        return AiResponse(
          text: '${r.toStringAsFixed(0)} RPM.$c',
          intentAction: 'VEHICLE_RPM',
        );
      }
      return AiResponse(text: 'Devir verisi yok.', intentAction: 'VEHICLE_RPM');
    }
    if (q.contains('yakit') || q.contains('benzin') || q.contains('tuketim')) {
      final f = obd.fuelRate;
      if (f != null) {
        final c = f > 10
            ? ' Biraz yuksek.'
            : f < 6
            ? ' Ekonomik gidiyorsun!'
            : '';
        return AiResponse(
          text: 'Yakit ${f.toStringAsFixed(1)} L/100km.$c',
          intentAction: 'VEHICLE_FUEL',
        );
      }
      return AiResponse(
        text: 'Yakit verisi yok.',
        intentAction: 'VEHICLE_FUEL',
      );
    }
    if (q.contains('aku') || q.contains('volt') || q.contains('batarya')) {
      final v = obd.batteryVoltage;
      if (v != null) {
        final c = v < 12.4 ? ' Biraz dusuk, dikkat.' : ' Iyi seviyede.';
        return AiResponse(
          text: 'Aku ${v.toStringAsFixed(1)}V.$c',
          intentAction: 'VEHICLE_BATTERY',
        );
      }
      return AiResponse(
        text: 'Aku verisi yok.',
        intentAction: 'VEHICLE_BATTERY',
      );
    }
    if (q.contains('kapi') || q.contains('bagaj')) {
      final d = vs.doorStatus;
      if (d.allClosed)
        return AiResponse(
          text: 'Tum kapilar kapali.',
          intentAction: 'VEHICLE_DOORS',
        );
      final open = <String>[];
      if (d.frontLeft) open.add('on sol');
      if (d.frontRight) open.add('on sag');
      if (d.rearLeft) open.add('arka sol');
      if (d.rearRight) open.add('arka sag');
      if (d.trunk) open.add('bagaj');
      return AiResponse(
        text: 'Acik: ${open.join(", ")}.',
        intentAction: 'VEHICLE_DOORS',
      );
    }
    if ((q.contains('arac') || q.contains('araba')) &&
        (q.contains('durum') || q.contains('nasil'))) {
      return _buildVehicleStatusResponse();
    }
    return null;
  }

  // ── Cloud chat (Gemini) ──────────────────────────────────────────

  Future<AiResponse> _askCloud(String query) async {
    if (!_isOnline) return _buildBasicAnswer(query);

    final history = _buildChatHistory();
    String text = '';

    if (_chatProvider == 'openrouter') {
      if (_openRouter.isConfigured) {
        text = await _openRouter.generate(
          query,
          vehicleState: _vehicleState,
          obdData: _obdData,
          vehicleName: _vehicleProfileName,
          history: history,
        );
      }
    } else if (_chatProvider == 'groq') {
      if (_groq.isConfigured) {
        text = await _groq.generate(
          query,
          vehicleState: _vehicleState,
          obdData: _obdData,
          vehicleName: _vehicleProfileName,
          history: history,
        );
      }
    } else if (_gemini.isConfigured) {
      text = await _gemini.generate(
        query,
        vehicleState: _vehicleState,
        obdData: _obdData,
        vehicleName: _vehicleProfileName,
        history: history,
      );
    }

    if (text.isNotEmpty) {
      return AiResponse(text: text, intentAction: 'AI_CHAT');
    }
    return _buildBasicAnswer(query);
  }

  /// Offline fallback for conversational queries.
  AiResponse _buildBasicAnswer(String query) {
    final q = query.toLowerCase();

    if (q.contains('merhaba') || q.contains('selam') || q.contains('naber')) {
      final hour = DateTime.now().hour;
      final greeting = hour < 6
          ? 'Gece seferi ha? Dikkatli surelim!'
          : hour < 12
          ? 'Gunaydin! Nasil yardimci olabilirim?'
          : hour < 18
          ? 'Iyi gunler! Soyle bakayim, ne lazim?'
          : 'Iyi aksamlar! Nasil yardimci olabilirim?';
      return AiResponse(text: greeting, intentAction: 'AI_CHAT');
    }

    if (!_isOnline) {
      return AiResponse(
        text: 'Internete baglaninca daha detayli sohbet edebiliriz.',
        intentAction: 'AI_CHAT',
      );
    }

    return AiResponse(
      text: 'Bunu yanitlayamadim. AI ayarlarindan API anahtarini kontrol et.',
      intentAction: 'AI_CHAT',
    );
  }

  AiResponse _buildVehicleStatusResponse() {
    final issues = <String>[];
    final coolant = _obdData.coolantTemp;
    if (coolant != null && coolant > 100) issues.add('motor sicakligi yuksek');
    final batt = _obdData.batteryVoltage;
    if (batt != null && batt < 12.4) issues.add('aku voltaji dusuk');
    final fuel = _obdData.fuelRate;
    if (fuel != null && fuel > 10) issues.add('yakit tuketimi yuksek');

    final parts = <String>[];
    if (coolant != null)
      parts.add('Motor ${coolant.toStringAsFixed(0)}\u00b0C');
    if (batt != null) parts.add('Aku ${batt.toStringAsFixed(1)}V');
    final spd = _obdData.speed ?? _vehicleState.speed;
    if (spd != null) parts.add('Hiz ${spd.toStringAsFixed(0)} km/h');

    final dataStr = parts.isNotEmpty ? parts.join(', ') : 'Veri baglantisi yok';

    if (issues.isEmpty) {
      return AiResponse(
        text: 'Her sey yolunda! $dataStr.',
        intentAction: 'VEHICLE_STATUS',
      );
    }
    return AiResponse(
      text: 'Dikkat: ${issues.join(", ")}. $dataStr.',
      intentAction: 'VEHICLE_STATUS',
    );
  }

  void _emit(AiAssistantSnapshot snapshot) {
    _snapshot = snapshot;
    if (!_stateController.isClosed) {
      _stateController.add(snapshot);
    }
  }
}
