import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// Circular avatar used across chat list tiles, chat headers, contacts,
/// and profile screens.
///
/// Shows the user's photo when [avatarUrl] is set; otherwise falls back to
/// a deterministic gradient (keyed off [seed], typically the uid or name)
/// with the user's initials, so avatars are still visually distinct
/// without a network round-trip.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.seed,
    this.avatarUrl,
    this.initials = '?',
    this.radius = AppDimens.avatarRadiusMedium,
    this.showOnlineDot = false,
    this.isOnline = false,
    this.heroTag,
  });

  final String seed;
  final String? avatarUrl;
  final String initials;
  final double radius;
  final bool showOnlineDot;
  final bool isOnline;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final Widget avatar = _buildAvatarCircle();
    final Widget wrapped = heroTag != null
        ? Hero(tag: heroTag!, child: avatar)
        : avatar;

    if (!showOnlineDot) return wrapped;

    final double dotSize = radius * 0.42;
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          wrapped,
          if (isOnline)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: AppColors.online,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarCircle() {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: (context, url) => _gradientFallback(),
          errorWidget: (context, url, error) => _gradientFallback(),
        ),
      );
    }
    return _gradientFallback();
  }

  Widget _gradientFallback() {
    final List<Color> colors = AppColors.avatarGradientFor(seed);
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }
}
