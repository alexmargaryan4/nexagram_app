import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../theme/theme.dart';

/// The app's single filled call-to-action button style: full-width, pill
/// or rounded-rect shape, with a built-in loading spinner swap so callers
/// never have to hand-roll `isLoading ? Spinner : Text` at each call site.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.enabled = true,
    this.backgroundColor,
    this.foregroundColor,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool enabled;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bool canTap = enabled && !isLoading && onPressed != null;
    final Color bg = backgroundColor ?? Colors.white;
    final Color fg = foregroundColor ?? const Color(0xFF0A84FF);

    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: canTap ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withOpacity(0.6),
          disabledForegroundColor: fg.withOpacity(0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: AnimatedSwitcher(
          duration: AppConstants.animFast,
          child: isLoading
              ? SizedBox(
                  key: const ValueKey('loading'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(fg),
                  ),
                )
              : Row(
                  key: const ValueKey('label'),
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 19),
                      const SizedBox(width: 8),
                    ],
                    Text(label),
                  ],
                ),
        ),
      ),
    );
  }
}

/// A borderless, secondary-emphasis text button styled to sit on glass
/// backgrounds (white text, subtle underline-free hover state).
class GlassTextButton extends StatelessWidget {
  const GlassTextButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: Colors.white),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
