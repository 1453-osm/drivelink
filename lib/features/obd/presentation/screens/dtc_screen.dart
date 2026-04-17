import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/features/obd/domain/models/dtc_code.dart';
import 'package:drivelink/features/obd/presentation/providers/obd_providers.dart';

/// Screen for reading and clearing OBD-II diagnostic trouble codes.
class DtcScreen extends ConsumerWidget {
  const DtcScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCodes = ref.watch(dtcCodesProvider);
    final connected = ref.watch(obdConnectedProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Diagnostics (DTC)'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              connected ? Icons.usb : Icons.usb_off,
              color: connected ? AppColors.success : AppColors.error,
              size: 20,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Action buttons ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: connected
                        ? () => ref.read(dtcCodesProvider.notifier).readCodes()
                        : null,
                    icon: const Icon(Icons.search, size: 20),
                    label: const Text('Read Codes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.surfaceVariant,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: connected
                        ? () => _confirmClear(context, ref)
                        : null,
                    icon: const Icon(Icons.delete_outline, size: 20),
                    label: const Text('Clear Codes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.surfaceVariant,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: AppColors.divider),

          // ── DTC list ──────────────────────────────────────────────
          Expanded(
            child: asyncCodes.when(
              loading: () => Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Error reading codes:\n$e',
                    style: TextStyle(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (codes) {
                if (codes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: AppColors.success,
                          size: 48,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No fault codes',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tap "Read Codes" to scan',
                          style: TextStyle(
                            color: AppColors.textDisabled,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: codes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return _DtcTile(code: codes[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Clear Fault Codes?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'This will send the clear-DTC command to the ECU. '
          'The check-engine light will turn off. Continue?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(dtcCodesProvider.notifier).clearCodes();
            },
            child: Text(
              'Clear',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _DtcTile extends StatelessWidget {
  const _DtcTile({required this.code});

  final DtcCode code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _severityColor(code.severity).withAlpha(60),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Severity dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _severityColor(code.severity),
            ),
          ),
          const SizedBox(width: 14),

          // Code
          Text(
            code.code,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 14),

          // Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  code.description,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${code.categoryName} - ${code.severity.name}',
                  style: TextStyle(
                    color: AppColors.textDisabled,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _severityColor(DtcSeverity severity) {
    return switch (severity) {
      DtcSeverity.info => AppColors.info,
      DtcSeverity.warning => AppColors.warning,
      DtcSeverity.critical => AppColors.error,
    };
  }
}
