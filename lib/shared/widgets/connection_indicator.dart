import 'package:flutter/material.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/shared/models/connection_status.dart';

/// A small colored dot that reflects the current [ConnectionStatus].
///
/// Green = connected, amber = connecting, red = disconnected/error.
class ConnectionIndicator extends StatelessWidget {
  const ConnectionIndicator({
    super.key,
    required this.status,
    this.size = 10,
    this.showLabel = false,
  });

  final ConnectionStatus status;
  final double size;
  final bool showLabel;

  Color get _color => switch (status) {
        ConnectionStatus.connected => AppColors.success,
        ConnectionStatus.connecting => AppColors.warning,
        ConnectionStatus.disconnected => AppColors.textDisabled,
        ConnectionStatus.error => AppColors.error,
      };

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _color,
        boxShadow: [
          BoxShadow(
            color: _color.withAlpha(100),
            blurRadius: size * 0.6,
            spreadRadius: size * 0.1,
          ),
        ],
      ),
    );

    if (!showLabel) return dot;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(width: 6),
        Text(
          status.label,
          style: TextStyle(
            color: _color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
