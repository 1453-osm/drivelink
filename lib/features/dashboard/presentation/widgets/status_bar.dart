import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/features/ai/data/datasources/ai_assistant_service.dart';
import 'package:drivelink/features/ai/presentation/providers/ai_provider.dart';
import 'package:drivelink/features/dashboard/domain/models/dashboard_state.dart';
import 'package:drivelink/features/vehicle_bus/presentation/providers/vehicle_bus_providers.dart';

/// Compact horizontal status bar pinned to the top of the dashboard.
///
/// Shows AI mic button, connection dots, current time, and battery voltage.
class StatusBar extends ConsumerWidget {
  const StatusBar({super.key, required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiState = ref.watch(aiAssistantStateProvider);
    final primary = Theme.of(context).colorScheme.primary;
    // Read the raw VAN state so we can tell "no data yet" from "actually 0°C".
    final vanState = ref.watch(vehicleStateProvider).valueOrNull;
    final externalTemp = vanState?.externalTemp;
    final tempLabel = externalTemp != null
        ? '${externalTemp.toStringAsFixed(0)}°'
        : '--°';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surfaceVariant, AppColors.surface],
        ),
        border: Border(
          bottom:
              BorderSide(color: primary.withAlpha(15), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // ── Battery ──────────────────────────────────────────────
          _IconValue(
            icon: Icons.battery_std_outlined,
            value: '${state.batteryVoltage.toStringAsFixed(1)}V',
            iconColor: state.batteryVoltage < 11.5
                ? AppColors.error
                : AppColors.success,
          ),

          const SizedBox(width: 10),

          // ── Connection dots ──────────────────────────────────────
          _ConnectionDot(label: 'VAN', connected: state.vanConnected),
          const SizedBox(width: 8),
          _ConnectionDot(label: 'OBD', connected: state.obdConnected),

          const Spacer(),

          // ── Clock ────────────────────────────────────────────────
          StreamBuilder<DateTime>(
            stream: Stream.periodic(
                const Duration(seconds: 30), (_) => DateTime.now()),
            builder: (context, snapshot) {
              final now = snapshot.data ?? DateTime.now();
              return Text(
                DateFormat('HH:mm').format(now),
                style: GoogleFonts.jetBrainsMono(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              );
            },
          ),

          const Spacer(),

          // ── External temp ────────────────────────────────────────
          _IconValue(
            icon: Icons.thermostat_outlined,
            value: tempLabel,
            iconColor: externalTemp == null
                ? AppColors.textDisabled
                : AppColors.info,
          ),

          const SizedBox(width: 10),

          // ── AI mic button ────────────────────────────────────────
          _AiMicButton(aiState: aiState, ref: ref, primary: primary),
        ],
      ),
    );
  }
}

// ─── AI Mic Button ──────────────────────────────────────────────────────

class _AiMicButton extends StatelessWidget {
  const _AiMicButton({
    required this.aiState,
    required this.ref,
    required this.primary,
  });

  final AssistantState aiState;
  final WidgetRef ref;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final isListening = aiState == AssistantState.listening;
    final isProcessing = aiState == AssistantState.processing ||
        aiState == AssistantState.speaking;
    final isActive = isListening || isProcessing;

    final Color color;
    final IconData icon;
    if (isListening) {
      color = primary;
      icon = Icons.mic_rounded;
    } else if (isProcessing) {
      color = AppColors.accent;
      icon = Icons.hourglass_top_rounded;
    } else {
      color = AppColors.textSecondary;
      icon = Icons.mic_none_rounded;
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        final service = ref.read(aiAssistantServiceProvider);
        service.activate();
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? color.withAlpha(20) : Colors.transparent,
          border: Border.all(
            color: color.withAlpha(isActive ? 80 : 40),
            width: 1,
          ),
          boxShadow: isActive
              ? [BoxShadow(color: color.withAlpha(50), blurRadius: 10)]
              : null,
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────

class _IconValue extends StatelessWidget {
  const _IconValue({
    required this.icon,
    required this.value,
    required this.iconColor,
  });

  final IconData icon;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ConnectionDot extends StatelessWidget {
  const _ConnectionDot({
    required this.label,
    required this.connected,
  });

  final String label;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final Color dotColor = connected ? AppColors.success : AppColors.error;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: dotColor.withAlpha(120),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
