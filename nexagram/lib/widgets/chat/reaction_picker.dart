import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../common/glass_container.dart';

/// A short row of quick-tap emoji reactions, shown above a message in the
/// long-press context menu.
///
/// Deliberately fixed to a curated set (rather than a full emoji keyboard)
/// so it renders instantly as a single row — matching how Telegram/iMessage
/// surface reactions as a fast gesture rather than a picker flow.
class ReactionPicker extends StatelessWidget {
  const ReactionPicker({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  static const List<String> _emojis = ['❤️', '👍', '😂', '😮', '😢', '🙏'];

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      blurSigma: 20,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _emojis.map((emoji) {
          return InkWell(
            borderRadius: BorderRadius.circular(AppDimens.radiusPill),
            onTap: () => onSelected(emoji),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
          );
        }).toList(),
      ),
    );
  }
}
