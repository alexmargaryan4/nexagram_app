import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/theme.dart';

/// The single building block behind NexaGram's "Liquid Glass" look.
///
/// Wraps [child] in a blurred, translucent, rounded panel with a subtle
/// gradient border highlight — the same recipe reused for the nav bar,
/// message composer, app bars, sheets, and cards throughout the app so the
/// glass effect stays visually consistent everywhere it appears.
///
/// Kept deliberately cheap: a single [BackdropFilter] + [DecoratedBox],
/// no repeated blur layers, so it's safe to nest several on one screen
/// (e.g. a glass nav bar over a glass app bar) without a frame-rate hit.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppDimens.radiusLarge)),
    this.blurSigma = 18,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.tintOpacity,
    this.borderWidth = 1,
    this.alignment,
    this.clip = Clip.antiAlias,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double blurSigma;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;

  /// Overrides the theme-default fill opacity (0.0–1.0). Leave null to use
  /// the standard light/dark glass fill from [AppColors].
  final double? tintOpacity;
  final double borderWidth;
  final AlignmentGeometry? alignment;
  final Clip clip;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color baseFill = isDark ? AppColors.darkGlassFill : AppColors.lightGlassFill;
    final Color borderColor = isDark ? AppColors.darkGlassBorder : AppColors.lightGlassBorder;

    final Color fill = tintOpacity != null
        ? baseFill.withOpacity(tintOpacity!)
        : baseFill;

    return Container(
      width: width,
      height: height,
      margin: margin,
      alignment: alignment,
      child: ClipRRect(
        borderRadius: borderRadius,
        clipBehavior: clip,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: borderRadius,
              border: Border.all(color: borderColor, width: borderWidth),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(isDark ? 0.06 : 0.35),
                  Colors.white.withOpacity(0.0),
                ],
              ),
            ),
            child: Padding(
              padding: padding ?? EdgeInsets.zero,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A single soft, blurred color blob used by [LiquidGlassBackground].
class _GlassBlob extends StatelessWidget {
  const _GlassBlob({
    required this.color,
    required this.alignment,
    required this.size,
    required this.opacity,
  });

  final Color color;
  final Alignment alignment;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(opacity),
        ),
      ),
    );
  }
}

/// A full-bleed, slowly drifting gradient backdrop used behind glass panels
/// on the splash, auth, and empty-state screens — this is what gives the
/// glass panels something colorful to actually refract.
class LiquidGlassBackground extends StatefulWidget {
  const LiquidGlassBackground({super.key, this.child});

  final Widget? child;

  @override
  State<LiquidGlassBackground> createState() => _LiquidGlassBackgroundState();
}

class _LiquidGlassBackgroundState extends State<LiquidGlassBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          ),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final double t = _controller.value * 2 * math.pi;
            return Stack(
              children: [
                _GlassBlob(
                  color: AppColors.brandGradient[0],
                  alignment: Alignment(0.9 * math.cos(t), -0.8 * math.sin(t)),
                  size: 340,
                  opacity: isDark ? 0.35 : 0.45,
                ),
                _GlassBlob(
                  color: AppColors.brandGradient[2],
                  alignment: Alignment(-0.8 * math.sin(t), 0.9 * math.cos(t)),
                  size: 300,
                  opacity: isDark ? 0.30 : 0.40,
                ),
                _GlassBlob(
                  color: AppColors.brandGradient[1],
                  alignment: Alignment(
                    0.6 * math.cos(t + 1.5),
                    0.7 * math.sin(t + 1.5),
                  ),
                  size: 260,
                  opacity: isDark ? 0.28 : 0.35,
                ),
              ],
            );
          },
        ),
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: const SizedBox.expand(),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}
