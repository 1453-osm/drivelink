import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivelink/app/router.dart';
import 'package:drivelink/core/services/audio_service.dart';
import 'package:drivelink/core/services/tts_service.dart';
import 'package:drivelink/features/ai/data/datasources/ai_assistant_service.dart';
import 'package:drivelink/features/ai/presentation/providers/ai_provider.dart';
import 'package:drivelink/features/vehicle_bus/domain/models/steering_button.dart';
import 'package:drivelink/features/vehicle_bus/domain/models/vehicle_state.dart';
import 'package:drivelink/features/vehicle_bus/presentation/providers/vehicle_bus_providers.dart';

// ---------------------------------------------------------------------------
// Screen cycle order for the SRC button
// ---------------------------------------------------------------------------
const _screenCycle = [
  AppRoutes.dashboard,
  AppRoutes.navigation,
  AppRoutes.obd,
  AppRoutes.media,
];

// ---------------------------------------------------------------------------
// Steering Handler Service
// ---------------------------------------------------------------------------

/// Listens to steering-wheel button events from the vehicle bus and maps them
/// to application actions (media control, screen cycling, etc.).
class SteeringHandler {
  SteeringHandler({
    required this.audioService,
    required this.ttsService,
    required this.aiService,
  });

  final DriveAudioService audioService;
  final TtsService ttsService;
  final AiAssistantService aiService;

  StreamSubscription<VehicleState>? _subscription;
  int _screenIndex = 0;

  // SRC butonu kısa/uzun basım tespiti
  Timer? _srcLongPressTimer;
  bool _srcLongPressFired = false;
  static const _longPressThreshold = Duration(milliseconds: 500);

  /// Start listening to steering events from [vehicleStateStream].
  void start(Stream<VehicleState> vehicleStateStream) {
    _subscription?.cancel();

    DateTime? lastEventTs;

    _subscription = vehicleStateStream.listen((state) {
      if (state.steeringButtons.isEmpty) return;

      // Parser inserts newest event at index 0 — reading `.last` here would
      // replay the oldest event in the rolling buffer on every state update.
      final event = state.steeringButtons.first;

      // Dedupe by timestamp: unrelated state updates (TEMP, SPEED, …) keep
      // the same steeringButtons list, so we only fire when a new press
      // actually arrives.
      if (lastEventTs != null && event.timestamp == lastEventTs) return;
      lastEventTs = event.timestamp;

      // SRC butonu için press/release ayrı işleniyor
      if (event.button == SteeringButton.src) {
        _handleSrcButton(event.action);
        return;
      }

      // Diğer tuşlar sadece press
      if (event.action != SteeringAction.press) return;
      _handleButton(event.button);
    });
  }

  void _handleButton(SteeringButton button) {
    switch (button) {
      case SteeringButton.volUp:
        audioService.volumeUp();
      case SteeringButton.volDown:
        audioService.volumeDown();
      case SteeringButton.next:
        audioService.next();
      case SteeringButton.prev:
        audioService.previous();
      case SteeringButton.src:
        // _handleSrcButton içinde işleniyor
        break;
      case SteeringButton.phone:
        ttsService.speak('Bildirim yok');
      case SteeringButton.scrollUp:
        _cycleScreen(forward: true);
      case SteeringButton.scrollDown:
        _cycleScreen(forward: false);
    }
  }

  /// SRC butonu: kısa basım → müzik play/pause, uzun basım → AI asistan.
  void _handleSrcButton(SteeringAction action) {
    if (action == SteeringAction.press) {
      _srcLongPressFired = false;
      _srcLongPressTimer?.cancel();
      _srcLongPressTimer = Timer(_longPressThreshold, () {
        _srcLongPressFired = true;
        aiService.activate();
      });
    } else {
      // release
      _srcLongPressTimer?.cancel();
      _srcLongPressTimer = null;
      if (!_srcLongPressFired) {
        audioService.togglePlayPause();
      }
    }
  }

  void _cycleScreen({bool forward = true}) {
    if (forward) {
      _screenIndex = (_screenIndex + 1) % _screenCycle.length;
    } else {
      _screenIndex = (_screenIndex - 1 + _screenCycle.length) % _screenCycle.length;
    }
    appRouter.push(_screenCycle[_screenIndex]);
  }

  void dispose() {
    _subscription?.cancel();
    _srcLongPressTimer?.cancel();
  }
}

// ---------------------------------------------------------------------------
// Riverpod Provider — auto-starts when first read
// ---------------------------------------------------------------------------

/// Provides a [SteeringHandler] that is automatically wired to the vehicle bus
/// and audio/TTS services. Reading this provider is enough to activate it.
final steeringHandlerProvider = Provider<SteeringHandler>((ref) {
  final audioService = ref.watch(driveAudioServiceProvider);
  final ttsService = ref.watch(ttsServiceProvider);
  final aiService = ref.watch(aiAssistantServiceProvider);

  final handler = SteeringHandler(
    audioService: audioService,
    ttsService: ttsService,
    aiService: aiService,
  );

  // Start the handler with the raw stream from the vehicle bus repository.
  final repo = ref.watch(vehicleBusRepositoryProvider);
  handler.start(repo.vehicleStateStream);

  ref.onDispose(() => handler.dispose());

  return handler;
});
