import 'package:flutter/material.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/shared/widgets/glass_panel.dart';

/// A single data tile inside the OBD dashboard grid.
class ObdTile extends StatelessWidget {
  const ObdTile({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final String unit;
  final IconData? icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isSmall = constraints.maxWidth < 100;
      final valueFontSize = isSmall ? 18.0 : 24.0;
      final labelFontSize = isSmall ? 9.0 : 11.0;
      final iconSize = isSmall ? 16.0 : 20.0;
      final pad = isSmall ? 8.0 : 14.0;

      return GlassPanel(
        borderRadius: 14,
        glowColor: valueColor ?? AppColors.primary,
        glowIntensity: valueColor != null ? 0.08 : 0.03,
        padding: EdgeInsets.all(pad),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: AppColors.textSecondary, size: iconSize),
              const SizedBox(height: 2),
            ],
            Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: labelFontSize,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  color: valueColor ?? AppColors.textPrimary,
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              unit,
              style: TextStyle(
                color: AppColors.textDisabled,
                fontSize: labelFontSize,
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Responsive grid layout for OBD data tiles.
/// 2 columns on phones, 4 columns on tablets/landscape.
class ObdGrid extends StatelessWidget {
  const ObdGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width < 500 ? 2 : (width < 800 ? 3 : 4);
    final aspectRatio = width < 500 ? 1.2 : 1.0;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: aspectRatio,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8),
      children: children,
    );
  }
}
