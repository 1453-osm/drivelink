import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/core/database/settings_repository.dart';
import 'package:drivelink/core/services/usb_serial_service.dart';
import 'package:drivelink/shared/widgets/responsive_page_body.dart';

/// Which USB port role the user has assigned.
enum UsbRole {
  esp32('ESP32 (VAN-bus gateway)'),
  elm327('ELM327 (OBD-II)');

  const UsbRole(this.label);
  final String label;

  static UsbRole fromName(String? name) {
    if (name == null) return UsbRole.esp32;
    return UsbRole.values.firstWhere(
      (r) => r.name == name,
      orElse: () => UsbRole.esp32,
    );
  }
}

/// Available baud rates for serial communication.
const List<int> _baudRates = [9600, 19200, 38400, 57600, 115200];

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class UsbConfig {
  const UsbConfig({
    this.port0Role = UsbRole.esp32,
    this.port1Role = UsbRole.elm327,
    this.esp32BaudRate = 115200,
    this.elm327BaudRate = 115200,
  });

  final UsbRole port0Role;
  final UsbRole port1Role;
  final int esp32BaudRate;
  final int elm327BaudRate;

  /// Legacy getter for backward compatibility.
  int get baudRate => esp32BaudRate;

  UsbConfig copyWith({
    UsbRole? port0Role,
    UsbRole? port1Role,
    int? esp32BaudRate,
    int? elm327BaudRate,
  }) {
    return UsbConfig(
      port0Role: port0Role ?? this.port0Role,
      port1Role: port1Role ?? this.port1Role,
      esp32BaudRate: esp32BaudRate ?? this.esp32BaudRate,
      elm327BaudRate: elm327BaudRate ?? this.elm327BaudRate,
    );
  }
}

// ---------------------------------------------------------------------------
// AsyncNotifier — loads from DB, persists every change
// ---------------------------------------------------------------------------

class UsbConfigNotifier extends AsyncNotifier<UsbConfig> {
  @override
  FutureOr<UsbConfig> build() async {
    final repo = ref.read(settingsRepositoryProvider);

    final esp32Port = await repo.get(SettingsKeys.usbEsp32Port);
    final elm327Port = await repo.get(SettingsKeys.usbElm327Port);
    final esp32Baud = await repo.get(SettingsKeys.esp32BaudRate);
    final elm327Baud = await repo.get(SettingsKeys.elm327BaudRate);

    // Derive port roles from stored port assignments.
    UsbRole port0 = UsbRole.esp32;
    UsbRole port1 = UsbRole.elm327;
    if (esp32Port == '1') {
      port0 = UsbRole.elm327;
      port1 = UsbRole.esp32;
    } else if (elm327Port == '0') {
      port0 = UsbRole.elm327;
      port1 = UsbRole.esp32;
    }

    return UsbConfig(
      port0Role: port0,
      port1Role: port1,
      esp32BaudRate: int.tryParse(esp32Baud ?? '') ?? 115200,
      elm327BaudRate: int.tryParse(elm327Baud ?? '') ?? 115200,
    );
  }

  Future<void> _persist(UsbConfig config) async {
    final repo = ref.read(settingsRepositoryProvider);
    final esp32PortIndex = config.port0Role == UsbRole.esp32 ? '0' : '1';
    final elm327PortIndex = config.port0Role == UsbRole.elm327 ? '0' : '1';

    await Future.wait([
      repo.set(SettingsKeys.usbEsp32Port, esp32PortIndex),
      repo.set(SettingsKeys.usbElm327Port, elm327PortIndex),
      repo.set(SettingsKeys.esp32BaudRate, config.esp32BaudRate.toString()),
      repo.set(SettingsKeys.elm327BaudRate, config.elm327BaudRate.toString()),
    ]);
  }

  Future<void> setPort0Role(UsbRole role) async {
    final current = state.valueOrNull ?? const UsbConfig();
    final updated = current.copyWith(
      port0Role: role,
      port1Role: role == UsbRole.esp32 ? UsbRole.elm327 : UsbRole.esp32,
    );
    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> setPort1Role(UsbRole role) async {
    final current = state.valueOrNull ?? const UsbConfig();
    final updated = current.copyWith(
      port1Role: role,
      port0Role: role == UsbRole.esp32 ? UsbRole.elm327 : UsbRole.esp32,
    );
    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> setEsp32BaudRate(int rate) async {
    final current = state.valueOrNull ?? const UsbConfig();
    final updated = current.copyWith(esp32BaudRate: rate);
    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> setElm327BaudRate(int rate) async {
    final current = state.valueOrNull ?? const UsbConfig();
    final updated = current.copyWith(elm327BaudRate: rate);
    state = AsyncData(updated);
    await _persist(updated);
  }
}

final usbConfigProvider = AsyncNotifierProvider<UsbConfigNotifier, UsbConfig>(
  UsbConfigNotifier.new,
);

/// Screen for assigning USB ports and testing connectivity.
class UsbConfigScreen extends ConsumerStatefulWidget {
  const UsbConfigScreen({super.key});

  @override
  ConsumerState<UsbConfigScreen> createState() => _UsbConfigScreenState();
}

class _UsbConfigScreenState extends ConsumerState<UsbConfigScreen> {
  bool _testing = false;
  String? _testResult;
  Color _testResultColor = AppColors.success;

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });

    try {
      final usbService = ref.read(usbSerialServiceProvider);
      final devices = await usbService.refreshDevices();

      if (!mounted) return;

      if (devices.isEmpty) {
        setState(() {
          _testing = false;
          _testResult =
              'USB cihaz bulunamadi. Lutfen baglantilari kontrol edin.';
          _testResultColor = AppColors.error;
        });
        return;
      }

      // Try connecting to all discovered devices
      final results = <String>[];
      for (final device in devices) {
        final vid =
            '0x${device.device.vid?.toRadixString(16).toUpperCase().padLeft(4, '0') ?? '????'}';
        final pid =
            '0x${device.device.pid?.toRadixString(16).toUpperCase().padLeft(4, '0') ?? '????'}';
        final success = await usbService.connect(device.device);
        final status = success ? 'Bagli' : 'Baglanti basarisiz';
        results.add('${device.label} (VID:$vid PID:$pid) — $status');
      }

      if (!mounted) return;

      final anyConnected = devices.any(
        (d) => d.connectionState == UsbConnectionState.connected,
      );
      // Re-read devices after connection attempts for updated state
      final updatedDevices = usbService.devices;
      final connectedCount = updatedDevices
          .where((d) => d.connectionState == UsbConnectionState.connected)
          .length;

      setState(() {
        _testing = false;
        _testResult =
            '${devices.length} cihaz bulundu, $connectedCount bagli:\n${results.join('\n')}';
        _testResultColor = anyConnected || connectedCount > 0
            ? AppColors.success
            : AppColors.warning;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testResult = 'Hata: $e';
        _testResultColor = AppColors.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(usbConfigProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('USB Configuration'),
        backgroundColor: AppColors.surface,
      ),
      body: ResponsivePageBody(
        maxWidth: 1040,
        child: configAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
          ),
          data: (config) {
            final notifier = ref.read(usbConfigProvider.notifier);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Port 0 ───────────────────────────────────────────────
                _PortCard(
                  portLabel: 'USB Port 0',
                  currentRole: config.port0Role,
                  onRoleChanged: notifier.setPort0Role,
                ),
                const SizedBox(height: 12),

                // ── Port 1 ───────────────────────────────────────────────
                _PortCard(
                  portLabel: 'USB Port 1',
                  currentRole: config.port1Role,
                  onRoleChanged: notifier.setPort1Role,
                ),
                const SizedBox(height: 20),

                // ── ESP32 Baud rate ──────────────────────────────────────
                Text(
                  'ESP32 Baud Rate',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _baudRates.map((rate) {
                    final isSelected = rate == config.esp32BaudRate;
                    return ChoiceChip(
                      label: Text(rate.toString()),
                      selected: isSelected,
                      onSelected: (_) => notifier.setEsp32BaudRate(rate),
                      selectedColor: AppColors.primary.withAlpha(40),
                      backgroundColor: AppColors.surfaceVariant,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // ── ELM327 Baud rate ─────────────────────────────────────
                Text(
                  'ELM327 Baud Rate',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _baudRates.map((rate) {
                    final isSelected = rate == config.elm327BaudRate;
                    return ChoiceChip(
                      label: Text(rate.toString()),
                      selected: isSelected,
                      onSelected: (_) => notifier.setElm327BaudRate(rate),
                      selectedColor: AppColors.primary.withAlpha(40),
                      backgroundColor: AppColors.surfaceVariant,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 28),

                // ── Test connection ──────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _testing ? null : _testConnection,
                    icon: _testing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.cable),
                    label: Text(_testing ? 'Testing...' : 'Test Connection'),
                  ),
                ),

                if (_testResult != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _testResult!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _testResultColor, fontSize: 13),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PortCard extends StatelessWidget {
  const _PortCard({
    required this.portLabel,
    required this.currentRole,
    required this.onRoleChanged,
  });

  final String portLabel;
  final UsbRole currentRole;
  final ValueChanged<UsbRole> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.usb, color: AppColors.textSecondary, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    portLabel,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currentRole.label,
                    style: TextStyle(
                      color: AppColors.textDisabled,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            DropdownButton<UsbRole>(
              value: currentRole,
              dropdownColor: AppColors.surface,
              underline: const SizedBox.shrink(),
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              items: UsbRole.values
                  .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onRoleChanged(v);
              },
            ),
          ],
        ),
      ),
    );
  }
}
