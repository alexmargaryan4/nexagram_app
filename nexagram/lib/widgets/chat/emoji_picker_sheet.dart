import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../common/glass_container.dart';

/// A bottom-sheet emoji keyboard for inserting emoji into the message
/// composer.
///
/// Kept as a curated, categorized grid (rather than pulling in a full
/// system-emoji-font picker package) so it renders instantly, matches the
/// app's existing "Liquid Glass" sheet styling, and needs no extra
/// dependency — the same tradeoff [ReactionPicker] makes for the quick
/// reaction row.
class EmojiPickerSheet extends StatefulWidget {
  const EmojiPickerSheet({super.key, required this.onSelected});

  /// Called with a single emoji each time the user taps one. The sheet
  /// stays open so people can insert several emoji in a row — they close
  /// it themselves via the handle/backdrop when done, the same way a
  /// system emoji keyboard behaves.
  final ValueChanged<String> onSelected;

  static const Map<String, List<String>> _categories = {
    'Smileys': [
      '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃',
      '😉', '😊', '😇', '🥰', '😍', '🤩', '😘', '😗', '😚', '😙',
      '😋', '😛', '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🤫', '🤔',
      '😐', '😑', '😶', '🙄', '😏', '😴', '🤤', '😪', '😮', '😲',
    ],
    'Emotions': [
      '😢', '😭', '😤', '😠', '😡', '🤬', '😳', '🥵', '🥶', '😱',
      '😨', '😰', '😥', '😓', '🤗', '🤤', '😷', '🤒', '🤕', '🥳',
      '🥺', '😬', '🙁', '☹️', '😞', '😔', '😟', '😕', '🫠', '🤯',
    ],
    'Gestures': [
      '👍', '👎', '👏', '🙌', '👋', '🤝', '🙏', '💪', '✌️', '🤞',
      '👌', '🤙', '👊', '✊', '🤟', '🫶', '👆', '👇', '👉', '👈',
    ],
    'Hearts': [
      '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔',
      '❤️‍🔥', '❤️‍🩹', '💕', '💞', '💓', '💗', '💖', '💘', '💝', '💟',
    ],
    'Symbols': [
      '🔥', '✨', '🎉', '🎊', '💯', '⭐', '🌟', '💫', '⚡', '☀️',
      '🌈', '☕', '🎁', '📎', '✅', '❌', '❗', '❓', '💤', '🎵',
    ],
  };

  @override
  State<EmojiPickerSheet> createState() => _EmojiPickerSheetState();
}

class _EmojiPickerSheetState extends State<EmojiPickerSheet> {
  late String _selectedCategory = EmojiPickerSheet._categories.keys.first;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent = isDark ? AppColors.darkAccent : AppColors.lightAccent;
    final Color muted =
        isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;
    final List<String> emojis = EmojiPickerSheet._categories[_selectedCategory]!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.md,
        0,
        AppDimens.md,
        AppDimens.md,
      ),
      child: SafeArea(
        top: false,
        child: GlassContainer(
          borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
          blurSigma: 22,
          child: SizedBox(
            height: 340,
            child: Column(
              children: [
                const SizedBox(height: AppDimens.sm),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: muted.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.sm,
                      AppDimens.md,
                      AppDimens.sm,
                      AppDimens.xs,
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8,
                    ),
                    itemCount: emojis.length,
                    itemBuilder: (context, index) {
                      final String emoji = emojis[index];
                      return InkWell(
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusSmall),
                        onTap: () => widget.onSelected(emoji),
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 26),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.sm,
                    vertical: AppDimens.xs,
                  ),
                  child: SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: EmojiPickerSheet._categories.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: AppDimens.xs),
                      itemBuilder: (context, index) {
                        final String category =
                            EmojiPickerSheet._categories.keys.elementAt(index);
                        final bool selected = category == _selectedCategory;
                        return ChoiceChip(
                          label: Text(category),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _selectedCategory = category),
                          labelStyle: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : (isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText),
                          ),
                          selectedColor: accent,
                          backgroundColor:
                              (isDark ? Colors.white : Colors.black)
                                  .withOpacity(0.05),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusPill),
                            side: BorderSide.none,
                          ),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
