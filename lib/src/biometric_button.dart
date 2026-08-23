import 'package:flutter/material.dart';

import 'biometric_login_base.dart';
import 'biometric_types.dart';

/// Visual styling for [BiometricLoginButton].
///
/// Every field is optional; anything left `null` falls back to a sensible,
/// theme-aware default derived from the ambient [Theme]. Use [copyWith] to tweak
/// a shared base style.
class BiometricButtonStyle {
  const BiometricButtonStyle({
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.borderRadius = 8.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.height,
    this.iconSize = 24.0,
    this.gap = 8.0,
    this.textStyle,
    this.elevation = 0.0,
    this.disabledOpacity = 0.5,
  });

  /// Fill color. Defaults to a subtle tint of the theme's primary color.
  final Color? backgroundColor;

  /// Icon + label color. Defaults to the theme's primary color.
  final Color? foregroundColor;

  /// Border color. Defaults to [foregroundColor]. Pass [Colors.transparent] for
  /// no visible border.
  final Color? borderColor;

  /// Border thickness.
  final double borderWidth;

  /// Corner radius.
  final double borderRadius;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  /// Fixed height. When `null`, the button sizes to its content + [padding].
  final double? height;

  /// Icon size.
  final double iconSize;

  /// Horizontal gap between the icon and the label.
  final double gap;

  /// Label text style. Merged over a theme-derived default.
  final TextStyle? textStyle;

  /// Material elevation.
  final double elevation;

  /// Opacity applied while the button is disabled.
  final double disabledOpacity;

  /// Returns a copy of this style with the given fields replaced.
  BiometricButtonStyle copyWith({
    Color? backgroundColor,
    Color? foregroundColor,
    Color? borderColor,
    double? borderWidth,
    double? borderRadius,
    EdgeInsetsGeometry? padding,
    double? height,
    double? iconSize,
    double? gap,
    TextStyle? textStyle,
    double? elevation,
    double? disabledOpacity,
  }) {
    return BiometricButtonStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      foregroundColor: foregroundColor ?? this.foregroundColor,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      borderRadius: borderRadius ?? this.borderRadius,
      padding: padding ?? this.padding,
      height: height ?? this.height,
      iconSize: iconSize ?? this.iconSize,
      gap: gap ?? this.gap,
      textStyle: textStyle ?? this.textStyle,
      elevation: elevation ?? this.elevation,
      disabledOpacity: disabledOpacity ?? this.disabledOpacity,
    );
  }
}

/// A ready-to-use "Sign in with Face ID / fingerprint" button.
///
/// The button is backend-agnostic. It works in one of two modes:
///
/// 1. **Gate mode** (recommended): pass a [biometric] instance. On tap the
///    button runs [BiometricLogin.unlock], shows a loading indicator while the
///    system prompt is up, then calls [onUnlocked] with the secret on success
///    or [onError] with the failure status. It also auto-detects the device's
///    biometric kind to choose the icon/label.
///
/// 2. **Manual mode**: pass [onPressed] to fully control what happens on tap
///    (e.g. run your own gate). While the returned future is awaited, the button
///    shows the loading indicator. [onPressed] takes precedence over [biometric].
///
/// Either way the button contains NO login/backend logic.
class BiometricLoginButton extends StatefulWidget {
  const BiometricLoginButton({
    super.key,
    this.biometric,
    this.onUnlocked,
    this.onError,
    this.onPressed,
    this.kind,
    this.label,
    this.icon,
    this.style,
    this.enabled = true,
    this.loadingIndicator,
    this.semanticLabel,
  });

  /// The gate used in "gate mode". When provided (and [onPressed] is null), the
  /// button runs [BiometricLogin.unlock] on tap.
  final BiometricLogin? biometric;

  /// Called with the unlocked secret after a successful unlock in gate mode.
  final Future<void> Function(String secret)? onUnlocked;

  /// Called when a gate-mode unlock does not succeed.
  final void Function(BiometricStatus status)? onError;

  /// Manual tap handler. Takes precedence over [biometric]. While the returned
  /// future runs, the button shows [loadingIndicator].
  final Future<void> Function()? onPressed;

  /// Overrides the auto-detected biometric kind used for the default icon/label.
  final BiometricKind? kind;

  /// Overrides the default label text.
  final String? label;

  /// Overrides the default icon widget.
  final Widget? icon;

  /// Visual styling. Missing values fall back to theme-aware defaults.
  final BiometricButtonStyle? style;

  /// When `false`, the button is dimmed and non-interactive.
  final bool enabled;

  /// Widget shown while a tap action is in progress. Defaults to a small
  /// circular progress indicator in the foreground color.
  final Widget? loadingIndicator;

  /// Accessibility label. Defaults to the resolved [label].
  final String? semanticLabel;

  @override
  State<BiometricLoginButton> createState() => _BiometricLoginButtonState();
}

class _BiometricLoginButtonState extends State<BiometricLoginButton> {
  bool _busy = false;
  BiometricKind _kind = BiometricKind.generic;

  @override
  void initState() {
    super.initState();
    _kind = widget.kind ?? BiometricKind.generic;
    if (widget.kind == null && widget.biometric != null) {
      _detectKind();
    }
  }

  @override
  void didUpdateWidget(covariant BiometricLoginButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.kind != null && widget.kind != _kind) {
      setState(() => _kind = widget.kind!);
    }
  }

  Future<void> _detectKind() async {
    try {
      final kind = await widget.biometric!.getBiometricKind();
      if (!mounted) return;
      setState(() => _kind = kind == BiometricKind.none
          ? BiometricKind.generic
          : kind);
    } catch (_) {
      // Keep the generic fallback.
    }
  }

  IconData _defaultIconData() {
    switch (_kind) {
      case BiometricKind.face:
        return Icons.face;
      case BiometricKind.fingerprint:
      case BiometricKind.iris:
      case BiometricKind.generic:
      case BiometricKind.none:
        return Icons.fingerprint;
    }
  }

  String _defaultLabel() {
    switch (_kind) {
      case BiometricKind.face:
        return 'Sign in with Face ID';
      case BiometricKind.fingerprint:
        return 'Sign in with fingerprint';
      case BiometricKind.iris:
        return 'Sign in with iris';
      case BiometricKind.generic:
      case BiometricKind.none:
        return 'Sign in with biometrics';
    }
  }

  Future<void> _handleTap() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (widget.onPressed != null) {
        await widget.onPressed!();
      } else if (widget.biometric != null) {
        final result = await widget.biometric!.unlock();
        if (result.isSuccess) {
          await widget.onUnlocked?.call(result.secret!);
        } else {
          widget.onError?.call(result.status);
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = widget.style ?? const BiometricButtonStyle();

    final Color foreground = style.foregroundColor ?? theme.colorScheme.primary;
    final Color background =
        style.backgroundColor ?? foreground.withAlpha(20); // ~8% opacity
    final Color border = style.borderColor ?? foreground;

    final bool disabled = !widget.enabled;
    final radius = BorderRadius.circular(style.borderRadius);

    final label = widget.label ?? _defaultLabel();
    final TextStyle textStyle = (theme.textTheme.labelLarge ?? const TextStyle())
        .copyWith(color: foreground, fontWeight: FontWeight.w600)
        .merge(style.textStyle);

    final Widget content = _busy
        ? (widget.loadingIndicator ??
            SizedBox(
              width: style.iconSize,
              height: style.iconSize,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(foreground),
              ),
            ))
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              widget.icon ??
                  Icon(
                    _defaultIconData(),
                    size: style.iconSize,
                    color: foreground,
                  ),
              if (label.isNotEmpty) ...[
                SizedBox(width: style.gap),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle,
                  ),
                ),
              ],
            ],
          );

    return Semantics(
      button: true,
      enabled: !disabled,
      label: widget.semanticLabel ?? label,
      child: Opacity(
        opacity: disabled ? style.disabledOpacity : 1.0,
        child: Material(
          color: background,
          elevation: style.elevation,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: (disabled || _busy) ? null : _handleTap,
            child: Container(
              height: style.height,
              padding: style.padding,
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: border,
                  width: style.borderWidth,
                ),
              ),
              child: Center(child: content),
            ),
          ),
        ),
      ),
    );
  }
}
