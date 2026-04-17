import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import 'package:drivelink/app/router.dart';
import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/core/services/audio_service.dart';
import 'package:drivelink/core/services/location_service.dart';
import 'package:drivelink/core/services/region_coverage_service.dart';
import 'package:drivelink/features/dashboard/domain/models/dashboard_state.dart';
import 'package:drivelink/features/dashboard/domain/models/gauge_metric.dart';
import 'package:drivelink/features/dashboard/presentation/widgets/configurable_gauge.dart';
import 'package:drivelink/features/dashboard/presentation/widgets/media_controls.dart';
import 'package:drivelink/features/dashboard/presentation/widgets/mini_map.dart';
import 'package:drivelink/features/dashboard/presentation/widgets/status_bar.dart';
import 'package:drivelink/features/obd/presentation/providers/obd_providers.dart';
import 'package:drivelink/features/settings/presentation/screens/settings_screen.dart';
import 'package:drivelink/features/vehicle_bus/presentation/providers/vehicle_bus_providers.dart';
import 'package:drivelink/shared/widgets/glass_panel.dart';

// ─── Providers ──────────────────────────────────────────────────────────

final dashboardStateProvider = Provider<DashboardState>((ref) {
  final obdAsync = ref.watch(obdDataProvider);
  final vanAsync = ref.watch(vehicleStateProvider);
  final obdConnected = ref.watch(obdConnectedProvider);
  final vanConnected = ref.watch(vehicleBusConnectedProvider);

  final obd = obdAsync.valueOrNull;
  final van = vanAsync.valueOrNull;

  return DashboardState(
    speed: obd?.speed ?? van?.speed ?? 0,
    rpm: obd?.rpm ?? van?.rpm ?? 0,
    coolantTemp: obd?.coolantTemp ?? 0,
    externalTemp: van?.externalTemp ?? 0,
    fuelConsumption: obd?.fuelRate ?? 0,
    tripDistance: 0,
    batteryVoltage: obd?.batteryVoltage ?? 0,
    obdConnected: obdConnected,
    vanConnected: vanConnected,
  );
});

final _gaugeLeftProvider = StateProvider<GaugeMetric>((_) => GaugeMetric.speed);
final _gaugeRightProvider = StateProvider<GaugeMetric>((_) => GaugeMetric.rpm);

// ─── Root screen with horizontal PageView ───────────────────────────────

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (_currentPage != 0) {
          _goToPage(0);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              // ── Status bar (always visible) ───────────────────────
              StatusBar(state: ref.watch(dashboardStateProvider))
                  .animate()
                  .fadeIn(duration: 200.ms)
                  .slideY(begin: -0.3, end: 0, duration: 200.ms),

              // ── Pages ─────────────────────────────────────────────
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  children: [
                    // Page 0 — Dashboard (varsayilan)
                    _DashboardPage(onGoToPage: _goToPage),
                    // Page 1 — Settings (saga kaydir)
                    const SettingsScreen(),
                  ],
                ),
              ),

              // ── Page indicator dots ───────────────────────────────
              _PageDots(current: _currentPage, count: 2),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Page indicator ─────────────────────────────────────────────────────

class _PageDots extends StatelessWidget {
  const _PageDots({required this.current, required this.count});
  final int current;
  final int count;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final isActive = i == current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: isActive ? primary : AppColors.textDisabled.withAlpha(80),
              boxShadow: isActive
                  ? [BoxShadow(color: primary.withAlpha(60), blurRadius: 8)]
                  : null,
            ),
          );
        }),
      ),
    );
  }
}

// ─── Dashboard page (page 0) ────────────────────────────────────────────

class _DashboardPage extends ConsumerWidget {
  const _DashboardPage({required this.onGoToPage});
  final ValueChanged<int> onGoToPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardStateProvider);
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return Column(
      children: [
        // ── Main body ───────────────────────────────────────────
        Expanded(
          child: isLandscape
              ? _LandscapeBody(state: state)
              : _PortraitBody(state: state),
        ),

        // ── Media + AI bar ──────────────────────────────────────
        if (!isLandscape) const _MediaBar().animate().fadeIn(duration: 500.ms),
      ],
    );
  }
}

// ─── Portrait layout ────────────────────────────────────────────────────

class _PortraitBody extends ConsumerWidget {
  const _PortraitBody({required this.state});
  final DashboardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obd = ref.watch(obdDataProvider).valueOrNull;
    final leftMetric = ref.watch(_gaugeLeftProvider);
    final rightMetric = ref.watch(_gaugeRightProvider);

    final knownPos = ref.watch(lastKnownPositionProvider);
    final locationAsync = ref.watch(locationStreamProvider);
    final defaultPos = ref.watch(defaultMapPositionProvider);
    final llPos = knownPos ?? defaultPos;
    final position = ml.LatLng(llPos.latitude, llPos.longitude);
    final heading = locationAsync.whenOrNull(data: (loc) => loc.heading) ?? 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          // ── Mini map ───────────────────────────────────────────
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: MiniMap(
                  currentPosition: position,
                  heading: heading,
                  nextTurnInstruction: null,
                  onTap: () => context.push(AppRoutes.navigation),
                ),
              ),
            ).animate().fadeIn(duration: 300.ms),
          ),

          const SizedBox(height: 4),

          // ── Configurable gauges → tap opens OBD ────────────────
          Expanded(
                flex: 3,
                child: GestureDetector(
                  onTap: () => context.push(AppRoutes.obd),
                  child: Row(
                    children: [
                      Expanded(
                        child: ConfigurableGauge(
                          metric: leftMetric,
                          value: leftMetric.getValue(state, obd),
                          onLongPress: () =>
                              _showGaugeSelector(context, ref, isLeft: true),
                        ),
                      ),
                      Expanded(
                        child: ConfigurableGauge(
                          metric: rightMetric,
                          value: rightMetric.getValue(state, obd),
                          onLongPress: () =>
                              _showGaugeSelector(context, ref, isLeft: false),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .animate()
              .fadeIn(duration: 400.ms)
              .scale(
                begin: const Offset(0.92, 0.92),
                end: const Offset(1, 1),
                duration: 400.ms,
              ),

          const SizedBox(height: 4),

          // ── OBD data cards → tap opens Trip ────────────────────
          GestureDetector(
                onTap: () => context.push(AppRoutes.trip),
                child: _ObdDataRow(state: state),
              )
              .animate()
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.15, end: 0, duration: 500.ms),
        ],
      ),
    );
  }
}

// ─── Landscape layout ───────────────────────────────────────────────────

class _LandscapeBody extends ConsumerWidget {
  const _LandscapeBody({required this.state});
  final DashboardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obd = ref.watch(obdDataProvider).valueOrNull;
    final leftMetric = ref.watch(_gaugeLeftProvider);
    final rightMetric = ref.watch(_gaugeRightProvider);

    final knownPos = ref.watch(lastKnownPositionProvider);
    final locationAsync = ref.watch(locationStreamProvider);
    final defaultPos = ref.watch(defaultMapPositionProvider);
    final llPos = knownPos ?? defaultPos;
    final position = ml.LatLng(llPos.latitude, llPos.longitude);
    final heading = locationAsync.whenOrNull(data: (loc) => loc.heading) ?? 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // ── Left: Map (full height) ────────────────────────────
          Expanded(
            flex: 2,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: MiniMap(
                currentPosition: position,
                heading: heading,
                nextTurnInstruction: null,
                onTap: () => context.push(AppRoutes.navigation),
              ),
            ).animate().fadeIn(duration: 300.ms),
          ),

          const SizedBox(width: 8),

          // ── Middle: Gauges + Media ─────────────────────────────
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: () => context.push(AppRoutes.obd),
                    child: Row(
                      children: [
                        Expanded(
                          child: ConfigurableGauge(
                            metric: leftMetric,
                            value: leftMetric.getValue(state, obd),
                            onLongPress: () =>
                                _showGaugeSelector(context, ref, isLeft: true),
                          ),
                        ),
                        Expanded(
                          child: ConfigurableGauge(
                            metric: rightMetric,
                            value: rightMetric.getValue(state, obd),
                            onLongPress: () =>
                                _showGaugeSelector(context, ref, isLeft: false),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .scale(
                      begin: const Offset(0.92, 0.92),
                      end: const Offset(1, 1),
                      duration: 400.ms,
                    ),
                const SizedBox(height: 4),
                const Expanded(
                  flex: 2,
                  child: _MediaBar(compact: true),
                ).animate().fadeIn(duration: 600.ms),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // ── Right: OBD status cards (vertical) ─────────────────
          Expanded(
            flex: 1,
            child: GestureDetector(
              onTap: () => context.push(AppRoutes.trip),
              child: _ObdDataRow(
                state: state,
                compact: true,
                vertical: true,
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms)
                .slideX(begin: 0.15, end: 0, duration: 500.ms),
          ),
        ],
      ),
    );
  }
}

// ─── Gauge metric selector ──────────────────────────────────────────────

Future<void> _showGaugeSelector(
  BuildContext context,
  WidgetRef ref, {
  required bool isLeft,
}) async {
  HapticFeedback.mediumImpact();
  final primary = Theme.of(context).colorScheme.primary;
  final current = isLeft
      ? ref.read(_gaugeLeftProvider)
      : ref.read(_gaugeRightProvider);

  final selected = await showModalBottomSheet<GaugeMetric>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.34,
      maxChildSize: 0.92,
      builder: (context, scrollController) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Text(
              'Gosterge Degeri Sec',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                ...GaugeMetric.values.map((metric) {
                  final isCurrent = metric == current;
                  return ListTile(
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: (isCurrent ? primary : AppColors.surfaceVariant)
                            .withAlpha(isCurrent ? 24 : 100),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCurrent
                              ? primary.withAlpha(90)
                              : AppColors.border,
                          width: 0.8,
                        ),
                      ),
                      child: Icon(
                        metric.icon,
                        color: isCurrent ? primary : AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      metric.label,
                      style: TextStyle(
                        color: isCurrent ? primary : AppColors.textPrimary,
                        fontWeight: isCurrent
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    subtitle: Text(
                      '${metric.minValue.toInt()} - ${metric.maxValue.toInt()} ${metric.unit}',
                      style: TextStyle(
                        color: AppColors.textDisabled,
                        fontSize: 12,
                      ),
                    ),
                    trailing: isCurrent
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: primary,
                            size: 20,
                          )
                        : null,
                    onTap: () => Navigator.of(ctx).pop(metric),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  if (selected != null) {
    if (isLeft) {
      ref.read(_gaugeLeftProvider.notifier).state = selected;
    } else {
      ref.read(_gaugeRightProvider.notifier).state = selected;
    }
  }
}

// ─── OBD data row ───────────────────────────────────────────────────────

class _ObdDataRow extends StatelessWidget {
  const _ObdDataRow({
    required this.state,
    this.compact = false,
    this.vertical = false,
  });
  final DashboardState state;
  final bool compact;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final fontSize = compact ? 12.0 : 14.0;
    final labelSize = compact ? 9.0 : 10.0;
    final iconSize = compact ? 14.0 : 16.0;
    final vPad = compact ? 6.0 : 8.0;
    final gap = compact ? 4.0 : 5.0;

    final cards = [
      _DataCard(
        icon: Icons.local_gas_station_rounded,
        value: state.fuelConsumption.toStringAsFixed(1),
        label: 'L/100',
        iconSize: iconSize,
        fontSize: fontSize,
        labelSize: labelSize,
        vPad: vPad,
      ),
      _DataCard(
        icon: Icons.thermostat_rounded,
        value: '${state.coolantTemp.toStringAsFixed(0)}°',
        label: 'Motor',
        iconSize: iconSize,
        fontSize: fontSize,
        labelSize: labelSize,
        vPad: vPad,
        valueColor: state.coolantTemp > 105 ? AppColors.error : null,
      ),
      _DataCard(
        icon: Icons.route_rounded,
        value: state.tripDistance.toStringAsFixed(1),
        label: 'km',
        iconSize: iconSize,
        fontSize: fontSize,
        labelSize: labelSize,
        vPad: vPad,
      ),
      _DataCard(
        icon: Icons.ac_unit_rounded,
        value: '${state.externalTemp.toStringAsFixed(0)}°',
        label: 'Dis',
        iconSize: iconSize,
        fontSize: fontSize,
        labelSize: labelSize,
        vPad: vPad,
      ),
    ];

    if (vertical) {
      return Column(
        children: [
          Expanded(child: cards[0]),
          SizedBox(height: gap),
          Expanded(child: cards[1]),
          SizedBox(height: gap),
          Expanded(child: cards[2]),
          SizedBox(height: gap),
          Expanded(child: cards[3]),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: cards[0]),
        SizedBox(width: gap),
        Expanded(child: cards[1]),
        SizedBox(width: gap),
        Expanded(child: cards[2]),
        SizedBox(width: gap),
        Expanded(child: cards[3]),
      ],
    );
  }
}

class _DataCard extends StatelessWidget {
  const _DataCard({
    required this.icon,
    required this.value,
    required this.label,
    this.valueColor,
    this.iconSize = 16,
    this.fontSize = 14,
    this.labelSize = 10,
    this.vPad = 8,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? valueColor;
  final double iconSize;
  final double fontSize;
  final double labelSize;
  final double vPad;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = valueColor ?? AppColors.textPrimary;
    final primary = Theme.of(context).colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;
        final scale = maxHeight < 46
            ? 0.68
            : maxHeight < 52
                ? 0.78
                : maxHeight < 60
                    ? 0.88
                    : 1.0;

        final scaledIcon = iconSize * scale;
        final scaledValue = fontSize * scale;
        final scaledLabel = labelSize * scale;
        final scaledVPad = (vPad * scale).clamp(2.0, vPad);
        final gap = scale < 0.8 ? 4.0 : 6.0;

        return GlassPanel(
          borderRadius: 12,
          glowColor: valueColor ?? primary,
          glowIntensity: valueColor != null ? 0.08 : 0.04,
          padding: EdgeInsets.symmetric(vertical: scaledVPad, horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(icon, color: primary.withAlpha(140), size: scaledIcon),
              SizedBox(width: gap),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: effectiveColor,
                          fontSize: scaledValue,
                          fontWeight: FontWeight.w600,
                          height: 1,
                          shadows: [
                            Shadow(
                              color: effectiveColor.withAlpha(40),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textDisabled,
                          fontSize: scaledLabel,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Combined Media + AI bar ────────────────────────────────────────────

class _MediaBar extends ConsumerWidget {
  const _MediaBar({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioService = ref.watch(driveAudioServiceProvider);
    final playbackState = ref.watch(playbackStateProvider).valueOrNull;
    final playerState = ref.watch(audioPlayerStateProvider).valueOrNull;
    final currentTrack = ref.watch(currentTrackProvider).valueOrNull;
    final track = playbackState?.track ?? currentTrack;

    ImageProvider? albumArt;
    final artPath = track?.artUri;
    if (artPath != null && artPath.isNotEmpty) {
      final artFile = File(artPath);
      if (artFile.existsSync()) {
        albumArt = FileImage(artFile);
      }
    }

    final controls = MediaControls(
      songTitle: track?.title ?? 'Sarki secilmedi',
      artist: track?.artist ?? '',
      albumArt: albumArt,
      isPlaying: playerState?.playing ?? false,
      repeat: playbackState?.repeat ?? false,
      compact: compact,
      onPrevious: () => audioService.previous(),
      onPlayPause: () => audioService.togglePlayPause(),
      onNext: () => audioService.next(),
      onRepeatToggle: () => audioService.toggleRepeat(),
      onExpand: () => context.push(AppRoutes.media),
    );

    if (compact) return controls;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: controls,
    );
  }
}
