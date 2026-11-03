import 'package:flutter/material.dart';

/// Displays the official STARQ logo at a given size.
/// - For light backgrounds (default: isDark = false): uses the black/red logo (assets/images/logo.png).
/// - For dark backgrounds (isDark = true): uses the white/red logo (assets/images/onboarding_logo.png).
class StarqLogo extends StatelessWidget {
  final double fontSize;
  final bool isDark;
  final double? height;
  final double? width;
  final BoxFit fit;

  const StarqLogo({
    super.key,
    this.fontSize = 34,
    this.isDark = false,
    this.height,
    this.width,
    this.fit = BoxFit.contain,
  });

  /// Convenience constructor for dark backgrounds (white/red logo).
  const StarqLogo.dark({
    super.key,
    this.fontSize = 34,
    this.height,
    this.width,
    this.fit = BoxFit.contain,
  }) : isDark = true;

  /// Convenience constructor for light backgrounds (black/red logo).
  const StarqLogo.light({
    super.key,
    this.fontSize = 34,
    this.height,
    this.width,
    this.fit = BoxFit.contain,
  }) : isDark = false;

  @override
  Widget build(BuildContext context) {
    final assetPath = isDark
        ? 'assets/images/onboarding_logo.png'
        : 'assets/images/logo.png';

    return Image.asset(
      assetPath,
      height: height ?? (fontSize * 1.3),
      width: width,
      fit: fit,
    );
  }
}