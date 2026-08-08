import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../theme/theme.dart';
import '../common/glass_container.dart';

/// A single tab definition for [CustomNavigationBar].
class NavBarItem {
  const NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badgeCount;
}

/// Floating "Liquid Glass" bottom navigation bar, styled after iOS 26 /
/// Telegram's frosted tab bars rather than Material's default
/// [BottomNavigationBar].
///
/// Deliberately floats with margin on all sides (rather than docking flush
/// to the screen edges) so the blur has visible background on every side —
/// docking it flush would clip the blur against the screen bounds and
/// flatten the glass effect.
class CustomNavigationBar extends StatelessWidget {
  const CustomNavigationBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<NavBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.lg,
        0,
        AppDimens.lg,
        AppDimens.md,
      ),
      child: GlassContainer(
        height: 64,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        blurSigma: AppConstants.glassBlurSigma,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (int i = 0; i < items.length; i++)
              Expanded(
                child: _NavBarButton(
                  item: items[i],
                  selected: i == currentIndex,
                  isDark: isDark,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavBarButton extends StatelessWidget {
  const _NavBarButton({
    required this.item,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final NavBarItem item;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color activeColor =
        isDark ? AppColors.darkAccent : AppColors.lightAccent;
    final Color inactiveColor =
        isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;
    final Color color = selected ? activeColor : inactiveColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppConstants.animFast,
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedSwitcher(
                    duration: AppConstants.animFast,
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      selected ? item.activeIcon : item.icon,
                      key: ValueKey<bool>(selected),
                      color: color,
                      size: 24,
                    ),
                  ),
                  if (item.badgeCount > 0)
                    Positioned(
                      right: -8,
                      top: -4,
                      child: _Badge(count: item.badgeCount),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final String label = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      constraints: const BoxConstraints(minWidth: 17),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 1.5,
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
    );
  }
}
