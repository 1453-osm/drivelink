import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:drivelink/core/database/settings_repository.dart';
import 'package:drivelink/core/services/audio_service.dart';
import 'package:drivelink/core/services/location_service.dart';
import 'package:drivelink/core/services/steering_handler.dart';
import 'package:drivelink/core/services/tts_service.dart';
import 'package:drivelink/core/services/turkey_package_service.dart';
import 'package:drivelink/features/ai/presentation/providers/ai_provider.dart';
import 'package:drivelink/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:drivelink/features/settings/presentation/providers/theme_prefs_provider.dart';
import 'package:drivelink/features/vehicle_bus/presentation/providers/vehicle_bus_providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/colors.dart';

final _mapSkippedProvider = FutureProvider<bool>((ref) async {
  final repo = ref.read(settingsRepositoryProvider);
  final val = await repo.get(SettingsKeys.mapSetupDone);
  return val == 'skipped';
});

class DriveLinkApp extends ConsumerStatefulWidget {
  const DriveLinkApp({super.key});

  @override
  ConsumerState<DriveLinkApp> createState() => _DriveLinkAppState();
}

class _DriveLinkAppState extends ConsumerState<DriveLinkApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initServices();
    });
  }

  Future<void> _initServices() async {
    // Initialize location service (handles permissions + starts listening)
    try {
      final locationService = ref.read(locationServiceProvider);
      await locationService.init();
    } catch (e) {
      debugPrint('[App] Location init failed: $e');
    }

    // Initialize TTS + Audio services before AI
    try {
      final ttsService = ref.read(ttsServiceProvider);
      final audioService = ref.read(driveAudioServiceProvider);
      await Future.wait([ttsService.init(), audioService.init()]);
    } catch (e) {
      debugPrint('[App] TTS/Audio init failed: $e');
    }

    // Auto-connect the VAN bus (ESP32) — repository has its own reconnect
    // watchdog, so a single call here is enough to keep trying.
    try {
      final vanRepo = ref.read(vehicleBusRepositoryProvider);
      await vanRepo.connect();
    } catch (e) {
      debugPrint('[App] VAN bus connect failed: $e');
    }

    // Initialize Vosk + auto-start wake word after dependencies are ready
    try {
      await ref.read(aiInitProvider.future);
    } catch (e) {
      debugPrint('[App] AI init failed: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final locationService = ref.read(locationServiceProvider);
    final aiService = ref.read(aiAssistantServiceProvider);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        WakelockPlus.disable();
        locationService.stopListening();
        // Pause wake word when backgrounded
        aiService.toggleWakeWord(false);
      case AppLifecycleState.resumed:
        WakelockPlus.enable();
        // Only restart listening if already initialized
        if (locationService.isInitialized) {
          locationService.startListening();
        }
        // Resume wake word when foregrounded
        if (aiService.isReady) {
          aiService.toggleWakeWord(true);
        }
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(steeringHandlerProvider);

    final hasRegions = ref.watch(turkeyPackInstalledProvider);
    final mapSkipped = ref.watch(_mapSkippedProvider);
    final themePrefs = ref.watch(themePrefsProvider).valueOrNull ??
        const ThemePrefs();
    final systemBrightness = MediaQuery.platformBrightnessOf(context);
    final effectiveBrightness = switch (themePrefs.mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => systemBrightness,
    };
    AppColors.setBrightness(effectiveBrightness);
    final appTheme = effectiveBrightness == Brightness.dark
        ? AppTheme.dark(accentColor: themePrefs.accentColor)
        : AppTheme.light(accentColor: themePrefs.accentColor);
    final rebuildKey = ValueKey<int>(
      Object.hash(effectiveBrightness, themePrefs.accentColor.toARGB32()),
    );

    return hasRegions.when(
      data: (has) {
        if (has) return _mainApp(appTheme, rebuildKey);
        return mapSkipped.when(
          data: (skipped) => skipped
              ? _mainApp(appTheme, rebuildKey)
              : _onboardingApp(appTheme, rebuildKey),
          loading: () => _splashApp(),
          error: (_, _) => _onboardingApp(appTheme, rebuildKey),
        );
      },
      loading: () => _splashApp(),
      error: (_, _) => _mainApp(appTheme, rebuildKey),
    );
  }

  Widget _mainApp(ThemeData theme, Key key) {
    return MaterialApp.router(
      key: key,
      title: 'DriveLink',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
    );
  }

  Widget _onboardingApp(ThemeData theme, Key key) {
    return MaterialApp(
      key: key,
      title: 'DriveLink',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      home: const OnboardingScreen(),
    );
  }

  Widget _splashApp() {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
