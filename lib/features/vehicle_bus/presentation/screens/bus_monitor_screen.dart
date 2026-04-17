import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/features/vehicle_bus/domain/models/van_message.dart';
import 'package:drivelink/features/vehicle_bus/domain/models/vehicle_state.dart';
import 'package:drivelink/features/vehicle_bus/presentation/providers/vehicle_bus_providers.dart';

/// Debug screen that shows raw VAN bus messages, connection status,
/// and a type filter.
class BusMonitorScreen extends ConsumerStatefulWidget {
  const BusMonitorScreen({super.key});

  @override
  ConsumerState<BusMonitorScreen> createState() => _BusMonitorScreenState();
}

class _BusMonitorScreenState extends ConsumerState<BusMonitorScreen> {
  final List<VanMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  String? _typeFilter;
  bool _autoScroll = true;

  static const int _maxMessages = 500;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<VanMessage> get _filteredMessages {
    if (_typeFilter == null) return _messages;
    return _messages.where((m) => m.type == _typeFilter).toList();
  }

  Set<String> get _knownTypes => _messages.map((m) => m.type).toSet();

  void _onNewMessage(VanMessage message) {
    setState(() {
      _messages.insert(0, message);
      if (_messages.length > _maxMessages) {
        _messages.removeRange(_maxMessages, _messages.length);
      }
    });

    if (_autoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for new messages.
    ref.listen<AsyncValue<VanMessage>>(vanMessageStreamProvider, (_, next) {
      next.whenData(_onNewMessage);
    });

    final connected = ref.watch(vehicleBusConnectedProvider);
    final stats = ref.watch(esp32StatsProvider).valueOrNull;
    final vanState = ref.watch(vehicleStateProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('VAN Bus Monitor'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Geri',
          onPressed: () => context.pop(),
        ),
        actions: [
          // Connection indicator
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              connected ? Icons.usb : Icons.usb_off,
              color: connected ? AppColors.success : AppColors.error,
            ),
          ),
          // Auto-scroll toggle
          IconButton(
            icon: Icon(
              _autoScroll ? Icons.vertical_align_bottom : Icons.pause,
              color: AppColors.textPrimary,
            ),
            tooltip: _autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF',
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          // Connect / disconnect
          IconButton(
            icon: Icon(
              connected ? Icons.link_off : Icons.link,
              color: AppColors.textPrimary,
            ),
            tooltip: connected ? 'Disconnect' : 'Connect',
            onPressed: () async {
              final repo = ref.read(vehicleBusRepositoryProvider);
              if (connected) {
                await repo.disconnect();
              } else {
                await repo.connect();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Live diagnostic panel ─────────────────────────────────────
          _DiagPanel(stats: stats, state: vanState, connected: connected),
          Divider(height: 1, color: AppColors.divider),

          // ── Filter chips ──────────────────────────────────────────────
          if (_knownTypes.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _FilterChip(
                    label: 'ALL',
                    selected: _typeFilter == null,
                    onTap: () => setState(() => _typeFilter = null),
                  ),
                  for (final type in _knownTypes.toList()..sort())
                    _FilterChip(
                      label: type,
                      selected: _typeFilter == type,
                      onTap: () => setState(() => _typeFilter = type),
                    ),
                ],
              ),
            ),
          Divider(height: 1, color: AppColors.divider),

          // ── Message counter ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Text(
                  '${_filteredMessages.length} messages',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() {
                    _messages.clear();
                    _typeFilter = null;
                  }),
                  child: Text(
                    'Clear',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Message list ──────────────────────────────────────────────
          Expanded(
            child: _filteredMessages.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    itemCount: _filteredMessages.length,
                    itemBuilder: (context, index) {
                      final msg = _filteredMessages[index];
                      return _MessageTile(message: msg);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Private widgets ──────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Live diagnostic panel — shows ESP32 byte/parse counters and the last-known
/// values from the vehicle bus so "is data actually flowing?" is a one-glance
/// question.
class _DiagPanel extends StatelessWidget {
  const _DiagPanel({
    required this.stats,
    required this.state,
    required this.connected,
  });

  final Map<String, int>? stats;
  final VehicleState? state;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final bytes = stats?['bytes'] ?? 0;
    final parsed = stats?['parsed'] ?? 0;
    final errors = stats?['errors'] ?? 0;

    final temp = state?.externalTemp;
    final speed = state?.speed;
    final rpm = state?.rpm;
    final lastBtn = (state?.steeringButtons.isNotEmpty ?? false)
        ? state!.steeringButtons.first
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1 — raw counters
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: connected ? AppColors.success : AppColors.error,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                connected ? 'LIVE' : 'OFFLINE',
                style: TextStyle(
                  color: connected ? AppColors.success : AppColors.error,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 16),
              _Stat(label: 'bytes', value: bytes.toString()),
              const SizedBox(width: 10),
              _Stat(label: 'parsed', value: parsed.toString()),
              const SizedBox(width: 10),
              _Stat(
                label: 'errors',
                value: errors.toString(),
                highlight: errors > 0,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2 — decoded vehicle state summary
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _Stat(
                label: 'temp',
                value: temp != null ? '${temp.toStringAsFixed(1)}°C' : '—',
              ),
              _Stat(
                label: 'speed',
                value: speed != null ? '${speed.toStringAsFixed(0)} km/h' : '—',
              ),
              _Stat(
                label: 'rpm',
                value: rpm != null ? rpm.toStringAsFixed(0) : '—',
              ),
              _Stat(
                label: 'btn',
                value: lastBtn != null
                    ? '${lastBtn.button.name}/${lastBtn.action.name}'
                    : '—',
              ),
              if (state?.vin != null)
                _Stat(label: 'vin', value: state!.vin!),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            color: highlight ? AppColors.warning : AppColors.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message});

  final VanMessage message;

  @override
  Widget build(BuildContext context) {
    final time =
        '${message.timestamp.hour.toString().padLeft(2, '0')}:'
        '${message.timestamp.minute.toString().padLeft(2, '0')}:'
        '${message.timestamp.second.toString().padLeft(2, '0')}.'
        '${message.timestamp.millisecond.toString().padLeft(3, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          Text(
            time,
            style: TextStyle(
              color: AppColors.textDisabled,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 10),
          // Type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              message.type,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Data
          Expanded(
            child: Text(
              message.data.toString(),
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
