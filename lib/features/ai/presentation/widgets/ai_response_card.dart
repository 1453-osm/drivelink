import 'package:flutter/material.dart';
import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/features/ai/domain/models/ai_response.dart';

/// Card widget that displays an AI assistant response.
class AiResponseCard extends StatelessWidget {
  const AiResponseCard({
    super.key,
    required this.response,
    this.compact = false,
  });

  final AiResponse response;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final icon = _iconForAction(response.intentAction);
    final color = _colorForAction(response.intentAction);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // User query bubble (right-aligned, chat style)
        if (response.userQuery != null && response.userQuery!.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              margin: EdgeInsets.only(
                left: compact ? 48 : 64,
                right: compact ? 8 : 16,
                top: compact ? 4 : 8,
                bottom: 4,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                response.userQuery!,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: compact ? 12 : 14,
                ),
              ),
            ),
          ),
        // Assistant response card
        Container(
          margin: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 16,
            vertical: compact ? 2 : 4,
          ),
          padding: EdgeInsets.all(compact ? 10 : 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: color.withValues(alpha: 0.3), width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: compact ? 18 : 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      response.text,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: compact ? 13 : 15,
                        height: 1.4,
                      ),
                    ),
                    if (response.actionExecuted) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: AppColors.success, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Komut calistirildi',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _iconForAction(String action) {
    if (action.startsWith('NAV_')) return Icons.navigation;
    if (action.startsWith('VEHICLE_')) return Icons.directions_car;
    if (action.startsWith('MEDIA_')) return Icons.music_note;
    if (action.startsWith('SYSTEM_')) return Icons.settings;
    if (action == 'AI_CHAT') return Icons.smart_toy;
    if (action == 'ERROR') return Icons.error_outline;
    return Icons.assistant;
  }

  Color _colorForAction(String action) {
    if (action.startsWith('NAV_')) return AppColors.primary;
    if (action.startsWith('VEHICLE_')) return AppColors.accent;
    if (action.startsWith('MEDIA_')) return AppColors.success;
    if (action.startsWith('SYSTEM_')) return AppColors.info;
    if (action == 'AI_CHAT') return AppColors.info;
    if (action == 'ERROR') return AppColors.error;
    return AppColors.textSecondary;
  }
}
