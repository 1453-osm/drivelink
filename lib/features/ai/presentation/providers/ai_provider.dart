import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivelink/core/database/settings_repository.dart';
import 'package:drivelink/core/services/audio_service.dart';
import 'package:drivelink/core/services/connectivity_service.dart';
import 'package:drivelink/core/services/tts_service.dart';
import 'package:drivelink/features/ai/data/datasources/ai_assistant_service.dart';
import 'package:drivelink/features/obd/presentation/providers/obd_providers.dart';
import 'package:drivelink/features/settings/presentation/screens/vehicle_config_screen.dart';
import 'package:drivelink/features/vehicle_bus/presentation/providers/vehicle_bus_providers.dart';

// ── Service provider ───────────────────────────────────────────────────

final aiAssistantServiceProvider = Provider<AiAssistantService>((ref) {
  final tts = ref.watch(ttsServiceProvider);
  final audio = ref.watch(driveAudioServiceProvider);

  final service = AiAssistantService(ttsService: tts, audioService: audio);

  // Feed live VAN bus data
  ref.listen(vehicleStateProvider, (_, next) {
    final state = next.valueOrNull;
    if (state != null) service.updateVehicleState(state);
  });

  // Feed live OBD data
  ref.listen(obdDataProvider, (_, next) {
    final data = next.valueOrNull;
    if (data != null) service.updateObdData(data);
  });

  // Feed vehicle profile name
  ref.listen(vehicleProfileProvider, (_, next) {
    final profile = next.valueOrNull;
    if (profile != null) service.updateVehicleProfile(profile.displayName);
  });

  // Feed connectivity state
  ref.listen(isOnlineProvider, (_, next) {
    final online = next.valueOrNull ?? false;
    service.updateConnectivity(online);
  });

  // When playback starts, audio focus changes may kill the wake word
  // microphone session. Re-check after a short settle delay.
  ref.listen(playbackStateProvider, (prev, next) {
    final cur = next.valueOrNull;
    final old = prev?.valueOrNull;
    if (cur != null &&
        cur.status == PlaybackStatus.playing &&
        old?.status != PlaybackStatus.playing) {
      Future.delayed(const Duration(milliseconds: 800), () {
        service.checkWakeWordHealth();
      });
    }
  });

  ref.onDispose(() => service.dispose());
  return service;
});

// ── State stream provider ──────────────────────────────────────────────

final aiStateProvider = StreamProvider<AiAssistantSnapshot>((ref) {
  final service = ref.watch(aiAssistantServiceProvider);
  return service.stateStream;
});

// ── Initialization provider ────────────────────────────────────────────

final aiInitProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(aiAssistantServiceProvider);

  // Restore saved chat settings.
  final repo = ref.read(settingsRepositoryProvider);
  final geminiKey = await repo.get(SettingsKeys.geminiApiKey);
  if (geminiKey != null && geminiKey.isNotEmpty) {
    service.setGeminiApiKey(geminiKey);
  }
  final openRouterKey = await repo.get(SettingsKeys.openRouterApiKey);
  if (openRouterKey != null && openRouterKey.isNotEmpty) {
    service.setOpenRouterApiKey(openRouterKey);
  }
  final geminiModel = await repo.get(SettingsKeys.geminiModel);
  if (geminiModel != null && geminiModel.isNotEmpty) {
    service.setGeminiModel(geminiModel);
  }
  final openRouterModel = await repo.get(SettingsKeys.openRouterModel);
  if (openRouterModel != null && openRouterModel.isNotEmpty) {
    service.setOpenRouterModel(openRouterModel);
  }
  service.setChatProvider(
    await repo.getOrDefault(SettingsKeys.chatProvider, 'gemini'),
  );

  await service.initialize();

  // Auto-start wake word when Vosk is ready
  if (service.currentSnapshot.state == AssistantState.ready) {
    await service.toggleWakeWord(true);
  }

  return service.currentSnapshot.state == AssistantState.ready;
});

// ── Convenience providers ──────────────────────────────────────────────

final aiAssistantStateProvider = Provider<AssistantState>((ref) {
  final snapshot = ref.watch(aiStateProvider).valueOrNull;
  return snapshot?.state ?? AssistantState.idle;
});

final aiIsListeningProvider = Provider<bool>((ref) {
  return ref.watch(aiAssistantStateProvider) == AssistantState.listening;
});

final aiPartialTranscriptProvider = Provider<String>((ref) {
  final snapshot = ref.watch(aiStateProvider).valueOrNull;
  return snapshot?.partialTranscript ?? '';
});

final aiLastResponseProvider = Provider<String>((ref) {
  final snapshot = ref.watch(aiStateProvider).valueOrNull;
  return snapshot?.lastResponse?.text ?? '';
});

final aiWakeWordActiveProvider = Provider<bool>((ref) {
  final snapshot = ref.watch(aiStateProvider).valueOrNull;
  return snapshot?.wakeWordActive ?? false;
});

/// Whether cloud chat is available (online + API key configured).
final aiChatAvailableProvider = Provider<bool>((ref) {
  final snapshot = ref.watch(aiStateProvider).valueOrNull;
  return snapshot?.chatAvailable ?? false;
});
