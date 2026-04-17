import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/features/vehicle_bus/domain/models/steering_button.dart';
import 'package:drivelink/features/vehicle_bus/presentation/providers/vehicle_bus_providers.dart';

/// Shows the most recent steering-wheel button press.
class SteeringControls extends ConsumerWidget {
  const SteeringControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(vehicleStateProvider);

    return asyncState.when(
      loading: () => _buildBody(null),
      error: (_, __) => _buildBody(null),
      data: (state) => _buildBody(
        state.steeringButtons.isNotEmpty ? state.steeringButtons.first : null,
      ),
    );
  }

  Widget _buildBody(SteeringEvent? lastEvent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Steering Controls',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),

          // Button grid
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ButtonIndicator(
                button: SteeringButton.volUp,
                icon: Icons.volume_up,
                active: lastEvent?.button == SteeringButton.volUp &&
                    lastEvent?.action == SteeringAction.press,
              ),
              const SizedBox(width: 8),
              _ButtonIndicator(
                button: SteeringButton.volDown,
                icon: Icons.volume_down,
                active: lastEvent?.button == SteeringButton.volDown &&
                    lastEvent?.action == SteeringAction.press,
              ),
              const SizedBox(width: 8),
              _ButtonIndicator(
                button: SteeringButton.prev,
                icon: Icons.skip_previous,
                active: lastEvent?.button == SteeringButton.prev &&
                    lastEvent?.action == SteeringAction.press,
              ),
              const SizedBox(width: 8),
              _ButtonIndicator(
                button: SteeringButton.next,
                icon: Icons.skip_next,
                active: lastEvent?.button == SteeringButton.next &&
                    lastEvent?.action == SteeringAction.press,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ButtonIndicator(
                button: SteeringButton.src,
                icon: Icons.source,
                active: lastEvent?.button == SteeringButton.src &&
                    lastEvent?.action == SteeringAction.press,
              ),
              const SizedBox(width: 8),
              _ButtonIndicator(
                button: SteeringButton.phone,
                icon: Icons.phone,
                active: lastEvent?.button == SteeringButton.phone &&
                    lastEvent?.action == SteeringAction.press,
              ),
            ],
          ),

          const SizedBox(height: 12),
          Text(
            lastEvent != null
                ? '${_buttonLabel(lastEvent.button)} — ${lastEvent.action.name}'
                : 'No input',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static String _buttonLabel(SteeringButton button) {
    return switch (button) {
      SteeringButton.volUp => 'VOL +',
      SteeringButton.volDown => 'VOL -',
      SteeringButton.next => 'NEXT',
      SteeringButton.prev => 'PREV',
      SteeringButton.src => 'SRC',
      SteeringButton.phone => 'PHONE',
      SteeringButton.scrollUp => 'SCROLL +',
      SteeringButton.scrollDown => 'SCROLL -',
    };
  }
}

class _ButtonIndicator extends StatelessWidget {
  const _ButtonIndicator({
    required this.button,
    required this.icon,
    required this.active,
  });

  final SteeringButton button;
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? AppColors.primary : AppColors.border,
          width: active ? 2 : 1,
        ),
      ),
      child: Icon(
        icon,
        color: active ? Colors.white : AppColors.textSecondary,
        size: 22,
      ),
    );
  }
}
