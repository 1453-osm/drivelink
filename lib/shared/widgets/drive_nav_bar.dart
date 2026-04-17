import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:drivelink/app/theme/colors.dart';

/// A single destination in the [DriveNavBar].
class DriveNavItem {
  const DriveNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// A custom floating pill-shaped navigation bar with ambient glow,
/// glass-morphism styling, and animated selection indicators.
///
/// Replaces the stock Material NavigationBar for a premium cockpit feel.
class DriveNavBar extends StatelessWidget {
  const DriveNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    required this.items,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;
  final List<DriveNavItem> items;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      margin: EdgeInsets.fromLTRB(
        20, 0, 20, bottomPadding > 0 ? bottomPadding : 10,
      ),
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surfaceVariant, AppColors.surface],
        ),
        border: Border.all(
          color: AppColors.border.withAlpha(50),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(12),
            blurRadius: 32,
            spreadRadius: -8,
          ),
          BoxShadow(
            color: Colors.black.withAlpha(100),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // ── Top-edge highlight ─────────────────────────────────────
            Positioned(
              top: 0,
              left: 24,
              right: 24,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppColors.primary.withAlpha(25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // ── Nav items ──────────────────────────────────────────────
            Row(
              children: List.generate(items.length, (index) {
                return Expanded(
                  child: _NavItem(
                    item: items[index],
                    isSelected: index == selectedIndex,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onTap(index);
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final DriveNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? item.selectedIcon : item.icon,
              color: isSelected ? AppColors.primary : AppColors.textDisabled,
              size: isSelected ? 24 : 22,
              shadows: isSelected
                  ? [
                      Shadow(
                        color: AppColors.primary.withAlpha(100),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: TextStyle(
                color:
                    isSelected ? AppColors.primary : AppColors.textDisabled,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            // ── Bottom indicator glow ──────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: isSelected ? 24 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withAlpha(100),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
