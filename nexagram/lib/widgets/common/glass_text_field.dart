import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// A frosted-glass styled [TextFormField] used throughout auth and
/// profile-editing forms.
///
/// Deliberately renders its own translucent fill instead of relying on
/// [InputDecorationTheme] (which is tuned for opaque surfaces elsewhere in
/// the app), because this field is almost always placed directly on top of
/// [LiquidGlassBackground] and needs to read as glass-on-glass, not
/// glass-on-solid.
class GlassTextField extends StatelessWidget {
  const GlassTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onSubmitted,
    this.onChanged,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.maxLength,
    this.autofocus = false,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onSubmitted;
  final void Function(String)? onChanged;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final int maxLines;
  final int? maxLength;
  final bool autofocus;
  final bool enabled;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        validator: validator,
        onFieldSubmitted: onSubmitted,
        onChanged: onChanged,
        maxLines: obscureText ? 1 : maxLines,
        maxLength: maxLength,
        autofocus: autofocus,
        enabled: enabled,
        textCapitalization: textCapitalization,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          counterText: '',
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.75)),
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.08),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: Colors.white70, size: 20)
              : null,
          suffixIcon: suffixIcon,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimens.lg,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
            borderSide: const BorderSide(color: Colors.white, width: 1.4),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
            borderSide: const BorderSide(color: AppColors.error, width: 1.2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
            borderSide: const BorderSide(color: AppColors.error, width: 1.4),
          ),
          errorStyle: const TextStyle(color: Color(0xFFFFB4AC), fontSize: 12.5),
        ),
      ),
    );
  }
}

/// A compact, opaque-surface variant of [GlassTextField] for screens that
/// sit on the normal (non-liquid-glass) scaffold background — e.g. the
/// profile editor and new-group screen — where white-on-white text would
/// be unreadable.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      onChanged: onChanged,
      maxLines: maxLines,
      maxLength: maxLength,
      enabled: enabled,
      textCapitalization: textCapitalization,
      style: TextStyle(
        color: isDark ? AppColors.darkText : AppColors.lightText,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
        suffixIcon: suffixIcon,
      ),
    );
  }
}
