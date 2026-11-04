import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// How the feedback panel is laid out.
enum SeaproofPanelStyle {
  /// Full screen on narrow screens, a centred card from 600 logical pixels.
  auto,

  /// Always a centred card.
  card,

  /// Always full screen.
  fullScreen,
}

/// The look of Seaproof's floating button and panel.
///
/// Everything left null follows the app's [ThemeData], which is usually enough. Set it in one
/// of two places; the first one found wins:
///
/// 1. `SeaproofHost(theme: SeaproofTheme(...))`
/// 2. `ThemeData(extensions: [SeaproofTheme(...)])`, which also lets it follow light and dark mode.
@immutable
class SeaproofTheme extends ThemeExtension<SeaproofTheme> {
  /// Creates a theme. All fields are optional.
  const SeaproofTheme({
    this.primaryColor,
    this.onPrimaryColor,
    this.surfaceColor,
    this.onSurfaceColor,
    this.barrierColor,
    this.borderRadius,
    this.fontFamily,
    this.floatingButtonIcon,
    this.floatingButtonSize,
    this.panelStyle,
    this.annotationColor,
  });

  /// Floating button, selected type and send button. Defaults to the app's primary colour.
  final Color? primaryColor;

  /// Text and icons on [primaryColor].
  final Color? onPrimaryColor;

  /// Panel background.
  final Color? surfaceColor;

  /// Text on [surfaceColor].
  final Color? onSurfaceColor;

  /// Dimming behind the card on wide screens.
  final Color? barrierColor;

  /// Corner radius of the card, fields and buttons.
  final double? borderRadius;

  /// Font of the panel. Defaults to the app's.
  final String? fontFamily;

  /// Icon on the floating button.
  final IconData? floatingButtonIcon;

  /// Diameter of the floating button.
  final double? floatingButtonSize;

  /// Card, full screen, or by screen width.
  final SeaproofPanelStyle? panelStyle;

  /// Pen colour when marking up a screenshot.
  final Color? annotationColor;

  /// Default floating button diameter.
  static const double defaultFloatingButtonSize = 48;

  /// Default corner radius of the card. Fields get 55 % of it and buttons 45 %, so a custom
  /// radius keeps the same proportions.
  static const double defaultBorderRadius = 22;

  /// The theme in effect: [explicit] first, then the app theme's extension, then defaults.
  ///
  /// [branding] (the colours set in the Seaproof admin) is used only when neither sets a
  /// primary colour, and then with its own text colour, so the two always match.
  static SeaproofTheme of(BuildContext context, [SeaproofTheme? explicit, SeaproofTheme? branding]) {
    final fromApp = Theme.of(context).extension<SeaproofTheme>();
    final theme = fromApp == null ? (explicit ?? const SeaproofTheme()) : fromApp.merge(explicit);
    if (theme.primaryColor != null || branding?.primaryColor == null) {
      return theme;
    }

    return theme.copyWith(primaryColor: branding!.primaryColor, onPrimaryColor: branding.onPrimaryColor);
  }

  /// [other]'s values where set, this theme's elsewhere.
  SeaproofTheme merge(SeaproofTheme? other) => other == null
      ? this
      : copyWith(
          primaryColor: other.primaryColor,
          onPrimaryColor: other.onPrimaryColor,
          surfaceColor: other.surfaceColor,
          onSurfaceColor: other.onSurfaceColor,
          barrierColor: other.barrierColor,
          borderRadius: other.borderRadius,
          fontFamily: other.fontFamily,
          floatingButtonIcon: other.floatingButtonIcon,
          floatingButtonSize: other.floatingButtonSize,
          panelStyle: other.panelStyle,
          annotationColor: other.annotationColor,
        );

  /// The app's theme with this theme's colours, shape and font applied, for Seaproof's widgets.
  ThemeData applyTo(ThemeData base) {
    final scheme = base.colorScheme.copyWith(
      primary: primaryColor,
      onPrimary: onPrimaryColor,
      surface: surfaceColor,
      onSurface: onSurfaceColor,
    );
    final radius = borderRadius ?? defaultBorderRadius;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius * 0.45));
    // Buttons at least 44 logical pixels high, the smallest comfortable touch target.
    const minimumSize = Size(64, 44);
    final themed = base.copyWith(
      colorScheme: scheme,
      textTheme: fontFamily == null ? null : base.textTheme.apply(fontFamily: fontFamily),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius * 0.55)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: shape, minimumSize: minimumSize),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: shape, minimumSize: minimumSize),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: shape, minimumSize: minimumSize),
      ),
    );
    return themed;
  }

  @override
  SeaproofTheme copyWith({
    Color? primaryColor,
    Color? onPrimaryColor,
    Color? surfaceColor,
    Color? onSurfaceColor,
    Color? barrierColor,
    double? borderRadius,
    String? fontFamily,
    IconData? floatingButtonIcon,
    double? floatingButtonSize,
    SeaproofPanelStyle? panelStyle,
    Color? annotationColor,
  }) => SeaproofTheme(
    primaryColor: primaryColor ?? this.primaryColor,
    onPrimaryColor: onPrimaryColor ?? this.onPrimaryColor,
    surfaceColor: surfaceColor ?? this.surfaceColor,
    onSurfaceColor: onSurfaceColor ?? this.onSurfaceColor,
    barrierColor: barrierColor ?? this.barrierColor,
    borderRadius: borderRadius ?? this.borderRadius,
    fontFamily: fontFamily ?? this.fontFamily,
    floatingButtonIcon: floatingButtonIcon ?? this.floatingButtonIcon,
    floatingButtonSize: floatingButtonSize ?? this.floatingButtonSize,
    panelStyle: panelStyle ?? this.panelStyle,
    annotationColor: annotationColor ?? this.annotationColor,
  );

  @override
  SeaproofTheme lerp(SeaproofTheme? other, double t) {
    if (other == null) {
      return this;
    }

    return SeaproofTheme(
      primaryColor: Color.lerp(primaryColor, other.primaryColor, t),
      onPrimaryColor: Color.lerp(onPrimaryColor, other.onPrimaryColor, t),
      surfaceColor: Color.lerp(surfaceColor, other.surfaceColor, t),
      onSurfaceColor: Color.lerp(onSurfaceColor, other.onSurfaceColor, t),
      barrierColor: Color.lerp(barrierColor, other.barrierColor, t),
      borderRadius: lerpDouble(borderRadius, other.borderRadius, t),
      fontFamily: t < 0.5 ? fontFamily : other.fontFamily,
      floatingButtonIcon: t < 0.5 ? floatingButtonIcon : other.floatingButtonIcon,
      floatingButtonSize: lerpDouble(floatingButtonSize, other.floatingButtonSize, t),
      panelStyle: t < 0.5 ? panelStyle : other.panelStyle,
      annotationColor: Color.lerp(annotationColor, other.annotationColor, t),
    );
  }
}
