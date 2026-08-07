import 'package:flutter/cupertino.dart';

/// Centralised color palette for NexaGram.
///
/// Values come directly from the product design spec: a Telegram-inspired,
/// iOS "Liquid Glass" aesthetic with distinct light/dark palettes.
class AppColors {
  AppColors._();

  // ---------------- Light theme ----------------
  static const Color lightBackground = Color(0xFFF2F2F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightOutgoingBubble = Color(0xFF2AABEE);
  static const Color lightIncomingBubble = Color(0xFFFFFFFF);
  static const Color lightAccent = Color(0xFF0A84FF);
  static const Color lightText = Color(0xFF000000);
  static const Color lightSecondaryText = Color(0xFF6D6D72);
  static const Color lightDivider = Color(0x1F000000);
  static const Color lightGlassFill = Color(0xB3FFFFFF); // white @ 70%
  static const Color lightGlassBorder = Color(0x59FFFFFF); // white @ 35%

  // ---------------- Dark theme ----------------
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF1C1C1E);
  static const Color darkIncomingBubble = Color(0xFF2C2C2E);
  static const Color darkOutgoingBubble = Color(0xFF2AABEE);
  static const Color darkAccent = Color(0xFF0A84FF);
  static const Color darkText = Color(0xFFFFFFFF);
  static const Color darkSecondaryText = Color(0xFF9A9A9E);
  static const Color darkDivider = Color(0x1FFFFFFF);
  static const Color darkGlassFill = Color(0x661C1C1E); // surface @ 40%
  static const Color darkGlassBorder = Color(0x1FFFFFFF); // white @ 12%

  // ---------------- Shared / semantic ----------------
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9F0A);
  static const Color error = Color(0xFFFF3B30);
  static const Color online = Color(0xFF34C759);
  static const Color readTick = Color(0xFF2AABEE);

  /// Gradient used for the splash logo & empty states.
  static const List<Color> brandGradient = [
    Color(0xFF2AABEE),
    Color(0xFF0A84FF),
    Color(0xFF6C5CE7),
  ];

  /// Deterministic avatar background gradients, keyed by name hash.
  static const List<List<Color>> avatarGradients = [
    [Color(0xFFFF9A8B), Color(0xFFFF6A88)],
    [Color(0xFF2AABEE), Color(0xFF0A84FF)],
    [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
    [Color(0xFF34C759), Color(0xFF00B894)],
    [Color(0xFFFFB347), Color(0xFFFF9F0A)],
    [Color(0xFFFF6B9D), Color(0xFFC44569)],
    [Color(0xFF00CEC9), Color(0xFF0984E3)],
    [Color(0xFFFDCB6E), Color(0xFFE17055)],
  ];

  static List<Color> avatarGradientFor(String seed) {
    final int hash = seed.codeUnits.fold(0, (a, b) => a + b);
    return avatarGradients[hash % avatarGradients.length];
  }
}
