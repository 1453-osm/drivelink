import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/features/ai/presentation/providers/ai_provider.dart';

/// Compact status indicator for wake word detection.
///
/// Shows a small pulsing dot when wake word is actively listening,
/// or a static indicator when inactive. Tap to toggle.
class WakeWordStatus extends ConsumerWidget {
  const WakeWordStatus({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(aiStateProvider).valueOrNull;
    final isActive = snapshot?.wakeWordActive ?? false;

    if (compact) {
      return _CompactIndicator(isActive: isActive);
    }

    return GestureDetector(
      onTap: () {
        final service = ref.read(aiAssistantServiceProvider);
        service.toggleWakeWord(!isActive);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.success.withValues(alpha: 0.15)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? AppColors.success.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PulsingDot(active: isActive),
            const SizedBox(width: 6),
            Text(
              isActive ? '"Abidin" dinliyor' : 'Wake word kapali',
              style: TextStyle(
                color: isActive ? AppColors.success : AppColors.textDisabled,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactIndicator extends StatelessWidget {
  const _CompactIndicator({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isActive ? 'Wake word aktif' : 'Wake word kapali',
      child: _PulsingDot(active: isActive),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.active});
  final bool active;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulsingDot old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && old.active) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = widget.active ? 0.5 + _controller.value * 0.5 : 0.3;
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (widget.active ? AppColors.success : AppColors.textDisabled)
                .withValues(alpha: opacity),
          ),
        );
      },
    );
  }
}
