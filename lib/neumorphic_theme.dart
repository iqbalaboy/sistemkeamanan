// lib/neumorphic_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // Light palette
  static const Color baseBlue = Color(0xFFCEE7FF);
  static const Color softBlue = Color(0xFFA8D8FF);
  static const Color primaryBlue = Color(0xFF4BA3FF);
  static const Color deepBlue = Color(0xFF2B6CB0);
  static const Color surface = Color(0xFFF3F8FF);
  static const Color innerSurface = Color(0xFFEFF6FF);

  // Dark palette
  static const Color darkBackground = Color(0xFF0B1220);
  static const Color darkSurface = Color(0xFF0F1724);
  static const Color darkInnerSurface = Color(0xFF111827);
  static const Color darkOnBackground = Color(0xFFE6F0FF); // subtle light tone for titles
  static const Color darkOnSurface = Color(0xFFE6EEF9);

  static ThemeData neumorphicBlue() {
    final cs = ColorScheme(
      brightness: Brightness.light,
      primary: primaryBlue,
      onPrimary: Colors.white,
      secondary: softBlue,
      onSecondary: Colors.white,
      error: Colors.red.shade700,
      onError: Colors.white,
      background: surface,
      onBackground: deepBlue,
      surface: innerSurface,
      onSurface: deepBlue,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.background,
      appBarTheme: AppBarTheme(
        backgroundColor: cs.background,
        elevation: 0,
        iconTheme: IconThemeData(color: cs.onBackground),
        titleTextStyle: TextStyle(
          color: cs.onBackground,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        systemOverlayStyle: null,
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(color: cs.onBackground, fontWeight: FontWeight.bold),
        headlineSmall: TextStyle(color: cs.onBackground, fontWeight: FontWeight.bold),
        bodyMedium: TextStyle(color: cs.onBackground),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          elevation: 0,
        ),
      ),
      // small global visual tweaks for neumorphic appearance on light
      cardColor: cs.surface,
      iconTheme: IconThemeData(color: cs.onBackground),
    );
  }

  // Improved dark variant with explicit color choices and adjusted contrasts
  static ThemeData neumorphicBlueDark() {
    final cs = ColorScheme(
      brightness: Brightness.dark,
      primary: primaryBlue,
      onPrimary: Colors.white,
      secondary: softBlue,
      onSecondary: Colors.white,
      error: Colors.red.shade400,
      onError: Colors.black,
      background: darkBackground,
      onBackground: darkOnBackground,
      surface: darkSurface,
      onSurface: darkOnSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.background,
      appBarTheme: AppBarTheme(
        backgroundColor: cs.background,
        elevation: 0,
        iconTheme: IconThemeData(color: cs.onBackground),
        titleTextStyle: TextStyle(
          color: cs.onBackground,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(color: cs.onBackground, fontWeight: FontWeight.bold),
        headlineSmall: TextStyle(color: cs.onBackground, fontWeight: FontWeight.bold),
        bodyMedium: TextStyle(color: cs.onBackground),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          elevation: 0,
        ),
      ),
      cardColor: cs.surface,
      iconTheme: IconThemeData(color: cs.onBackground),
      // tweak visual density / brightness hints if needed
    );
  }
}

/// Helper shadows for Neumorphism; kept generic — widgets will pick appropriate colors.
List<BoxShadow> neumorphicShadows({
  Color lightShadow = Colors.white,
  Color darkShadow = const Color(0xFF8AAFE0),
  double blur = 18,
  double offset = 6,
  double opacityDark = 0.12,
  double opacityLight = 0.9,
}) {
  return [
    BoxShadow(
      color: lightShadow.withOpacity(opacityLight),
      offset: Offset(-offset, -offset),
      blurRadius: blur,
    ),
    BoxShadow(
      color: darkShadow.withOpacity(opacityDark),
      offset: Offset(offset, offset),
      blurRadius: blur,
    ),
  ];
}

/// Neumorphic container (raised / inset approximation)
class NeumorphicContainer extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final bool inset;
  final double depth;
  final Gradient? gradient;

  const NeumorphicContainer({
    super.key,
    required this.child,
    this.radius = 20,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.color,
    this.inset = false,
    this.depth = 1.0,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = color ?? theme.colorScheme.surface;
    final isDark = theme.brightness == Brightness.dark;

    // adapt shadow colors for light/dark mode to keep contrast comfortable
    final double offsetVal = 6.0 * depth;
    final double blurVal = 18.0 * depth;
    final Color lightShadowColor = isDark ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.9);
    final Color darkShadowColor = isDark ? Colors.black.withOpacity(0.6) : Colors.black.withOpacity(0.12);

    final List<BoxShadow> shadows = inset
        ? [
            BoxShadow(color: darkShadowColor.withOpacity(0.06), offset: Offset(-offsetVal, -offsetVal), blurRadius: blurVal),
            BoxShadow(color: lightShadowColor.withOpacity(0.9), offset: Offset(offsetVal, offsetVal), blurRadius: blurVal),
          ]
        : [
            BoxShadow(color: lightShadowColor, offset: Offset(-offsetVal, -offsetVal), blurRadius: blurVal),
            BoxShadow(color: darkShadowColor.withOpacity(isDark ? 0.45 : 0.12), offset: Offset(offsetVal, offsetVal), blurRadius: blurVal),
          ];

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? bg : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadows,
      ),
      child: child,
    );
  }
}

/// Simple Neumorphic button (pressed visual via animated shadow/scale)
class NeumorphicButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Gradient? gradient;

  const NeumorphicButton({
    super.key,
    required this.child,
    required this.onTap,
    this.radius = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    this.color,
    this.gradient,
  });

  @override
  State<NeumorphicButton> createState() => _NeumorphicButtonState();
}

class _NeumorphicButtonState extends State<NeumorphicButton> {
  bool _pressed = false;

  void _setPressed(bool v) => setState(() => _pressed = v);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = widget.color ?? theme.colorScheme.primary;

    final lightShadowColor = isDark ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.9);
    final darkShadowColor = isDark ? Colors.black.withOpacity(0.6) : theme.colorScheme.primary.withOpacity(0.85);

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) {
        _setPressed(false);
        widget.onTap?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: widget.gradient == null ? bg : null,
          gradient: widget.gradient,
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: _pressed
              ? [
                  // pressed: softer reverse shadow
                  BoxShadow(color: darkShadowColor.withOpacity(0.08), offset: const Offset(2, 2), blurRadius: 6),
                ]
              : [
                  BoxShadow(color: lightShadowColor, offset: const Offset(-6, -6), blurRadius: 14),
                  BoxShadow(color: darkShadowColor.withOpacity(isDark ? 0.45 : 0.12), offset: const Offset(6, 6), blurRadius: 14),
                ],
        ),
        child: DefaultTextStyle(
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}