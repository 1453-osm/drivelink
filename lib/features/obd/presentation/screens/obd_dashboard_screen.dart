import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:drivelink/app/router.dart';
import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/features/obd/domain/models/obd_data.dart';
import 'package:drivelink/features/obd/presentation/providers/obd_providers.dart';
import 'package:drivelink/features/obd/presentation/widgets/coolant_temp.dart';
import 'package:drivelink/features/obd/presentation/widgets/fuel_consumption.dart';
import 'package:drivelink/features/obd/presentation/widgets/obd_grid.dart';
import 'package:drivelink/features/obd/presentation/widgets/rpm_gauge.dart';

/// Full-screen OBD-II dashboard.
///
/// Layout (landscape-friendly 4 x 2 grid):
/// ┌────────────┬────────────┬────────────┬────────────┐
/// │  RPM gauge │   Speed    │  Coolant   │  Intake P  │
/// ├────────────┼────────────┼────────────┼────────────┤
/// │   Fuel     │  Battery   │  Throttle  │  Eng Load  │
/// └────────────┴────────────┴────────────┴────────────┘
class ObdDashboardScreen extends ConsumerWidget {
  const ObdDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(obdConnectedProvider);
    final connecting = ref.watch(obdConnectingProvider);
    final data = ref.watch(obdDataProvider).valueOrNull ?? const ObdData();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('OBD Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Geri',
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.error_outline),
            tooltip: 'Arıza Kodları',
            onPressed: () => context.push(AppRoutes.dtc),
          ),
          IconButton(
            icon: const Icon(Icons.monitor_outlined),
            tooltip: 'Bus Monitor',
            onPressed: () => context.push(AppRoutes.busMonitor),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              connected ? Icons.usb : Icons.usb_off,
              color: connected ? AppColors.success : AppColors.error,
              size: 20,
            ),
          ),
          IconButton(
            icon: connecting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textPrimary,
                    ),
                  )
                : Icon(
                    connected ? Icons.link_off : Icons.link,
                    color: AppColors.textPrimary,
                  ),
            tooltip: connected ? 'Bağlantıyı Kes' : 'Bağlan',
            onPressed: connecting
                ? null
                : () => _toggleConnection(context, ref, connected),
          ),
        ],
      ),
      body: connected
          ? _DashboardBody(data: data)
          : connecting
              ? const _ConnectingBody()
              : _NotConnectedBody(
                  onConnect: () => _toggleConnection(context, ref, false),
                ),
    );
  }

  Future<void> _toggleConnection(
    BuildContext context,
    WidgetRef ref,
    bool connected,
  ) async {
    final repo = ref.read(obdRepositoryProvider);
    try {
      if (connected) {
        await repo.disconnect();
      } else {
        ref.read(obdConnectingProvider.notifier).state = true;
        await repo.connect();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bağlantı hatası: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      ref.read(obdConnectingProvider.notifier).state = false;
    }
  }
}

// ── Not connected ─────────────────────────────────────────────────────

class _NotConnectedBody extends StatelessWidget {
  const _NotConnectedBody({required this.onConnect});

  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withAlpha(30)),
              ),
              child: Icon(Icons.usb_off_rounded,
                  size: 40, color: AppColors.textDisabled),
            ),
            const SizedBox(height: 20),
            Text(
              'ELM327 Bagli Degil',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'OBD-II adaptorunuzu USB ile baglayip\nasagidaki butona dokunun',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onConnect,
              icon: const Icon(Icons.link_rounded),
              label: const Text('Baglan'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Connecting ────────────────────────────────────────────────────────

class _ConnectingBody extends StatelessWidget {
  const _ConnectingBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'ELM327 başlatılıyor...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          SizedBox(height: 4),
          Text(
            'Protokol algılanıyor',
            style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Dashboard body ────────────────────────────────────────────────────

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.data});

  final ObdData data;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isSmallPhone = width < 400;
    final speedFontSize = isSmallPhone ? 32.0 : 48.0;

    return SingleChildScrollView(
      child: Column(
        children: [
          // ── Top row: RPM gauge + speed ──────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: SizedBox(
              height: isSmallPhone ? 140 : 180,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: RpmGauge(rpm: data.rpm ?? 0),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.border.withAlpha(40), width: 0.5),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.speed,
                              color: AppColors.textSecondary,
                              size: isSmallPhone ? 18 : 24),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              data.speed?.toInt().toString() ?? '--',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: speedFontSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            'km/h',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom grid: 4 x 2 tiles ─────────────────────────────
          ObdGrid(
            children: [
              // Row 1
              CoolantTempWidget(temp: data.coolantTemp)
                  .animate()
                  .fadeIn(delay: 0.ms, duration: 300.ms)
                  .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 300.ms),
              ObdTile(
                label: 'Intake P',
                value: data.intakePressure?.toStringAsFixed(0) ?? '--',
                unit: 'kPa',
                icon: Icons.compress,
              )
                  .animate()
                  .fadeIn(delay: 60.ms, duration: 300.ms)
                  .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 300.ms),
              FuelConsumptionWidget(
                fuelRateLph: data.fuelRate,
                speedKmh: data.speed,
              )
                  .animate()
                  .fadeIn(delay: 120.ms, duration: 300.ms)
                  .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 300.ms),
              ObdTile(
                label: 'Battery',
                value: data.batteryVoltage?.toStringAsFixed(1) ?? '--',
                unit: 'V',
                icon: Icons.battery_std,
                valueColor: _batteryColor(data.batteryVoltage),
              )
                  .animate()
                  .fadeIn(delay: 180.ms, duration: 300.ms)
                  .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 300.ms),

              // Row 2
              ObdTile(
                label: 'Throttle',
                value: data.throttle?.toStringAsFixed(0) ?? '--',
                unit: '%',
                icon: Icons.tune,
              )
                  .animate()
                  .fadeIn(delay: 240.ms, duration: 300.ms)
                  .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 300.ms),
              ObdTile(
                label: 'Engine Load',
                value: data.engineLoad?.toStringAsFixed(0) ?? '--',
                unit: '%',
                icon: Icons.engineering,
                valueColor: _loadColor(data.engineLoad),
              )
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 300.ms)
                  .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 300.ms),
              ObdTile(
                label: 'Intake Temp',
                value: data.intakeTemp?.toStringAsFixed(0) ?? '--',
                unit: '°C',
                icon: Icons.air,
              )
                  .animate()
                  .fadeIn(delay: 360.ms, duration: 300.ms)
                  .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 300.ms),
              ObdTile(
                label: 'Fuel Rate',
                value: data.fuelRate?.toStringAsFixed(1) ?? '--',
                unit: 'L/h',
                icon: Icons.local_gas_station,
              )
                  .animate()
                  .fadeIn(delay: 420.ms, duration: 300.ms)
                  .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 300.ms),
            ],
          ),
        ],
      ),
    );
  }

  Color _batteryColor(double? v) {
    if (v == null) return AppColors.textDisabled;
    if (v < 11.5) return AppColors.error;
    if (v < 12.4) return AppColors.warning;
    return AppColors.success;
  }

  Color _loadColor(double? l) {
    if (l == null) return AppColors.textDisabled;
    if (l > 85) return AppColors.error;
    if (l > 65) return AppColors.warning;
    return AppColors.textPrimary;
  }
}
