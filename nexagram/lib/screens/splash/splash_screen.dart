import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/router/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/common/glass_container.dart';

/// First screen shown on launch: NexaGram's animated logo over a drifting
/// Liquid Glass backdrop, held for at least [AppConstants.splashMinDuration]
/// so the brand moment always registers even on a fast/warm auth check.
///
/// Owns its own navigation rather than relying on the router's `redirect`
/// for this specific hop, because it needs to *wait* for both the minimum
/// display timer and the first real [AuthStatus] before deciding where to
/// go — a plain redirect would fire the instant [AuthStatus.unknown]
/// resolves, which could cut the animation short.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.6, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final AuthProvider auth = context.read<AuthProvider>();

    final Future<void> minDelay = Future.delayed(
      AppConstants.splashMinDuration,
    );

    // Wait for the first resolved auth status (not AuthStatus.unknown).
    final Future<void> authReady = auth.status != AuthStatus.unknown
        ? Future.value()
        : _waitForAuthResolution(auth);

    await Future.wait([minDelay, authReady]);
    if (!mounted) return;

    if (auth.isAuthenticated) {
      context.goNamed(AppRoutes.chatsName);
    } else {
      context.goNamed(AppRoutes.loginName);
    }
  }

  Future<void> _waitForAuthResolution(AuthProvider auth) {
    if (auth.status != AuthStatus.unknown) return Future.value();
    final Completer<void> completer = Completer<void>();
    void listener() {
      if (auth.status != AuthStatus.unknown && !completer.isCompleted) {
        completer.complete();
      }
    }

    auth.addListener(listener);
    completer.future.whenComplete(() => auth.removeListener(listener));
    return completer.future;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidGlassBackground(
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _fade.value,
                child: Transform.scale(scale: _scale.value, child: child),
              );
            },
            child: const _SplashLogo(),
          ),
        ),
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassContainer(
          width: 108,
          height: 108,
          borderRadius: BorderRadius.circular(32),
          blurSigma: 24,
          child: const Center(
            child: Icon(
              Icons.bolt_rounded,
              size: 56,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: AppDimens.xl),
        Text(AppConstants.appName, style: AppTypography.brandLogo),
        const SizedBox(height: AppDimens.xs),
        Text(
          AppConstants.appTagline,
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
