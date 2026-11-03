import 'package:flutter/material.dart';
import 'package:starq_app/app/theme/app_theme.dart';

/// A button that reacts to:
/// - Mouse hover (desktop/web) via MouseRegion
/// - Touch press (mobile) via GestureDetector + AnimatedScale
class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? color;
  final Color? textColor;
  final Color? borderColor;
  final bool outlined;
  final double? width;
  final IconData? trailingIcon;
  final bool isLoading;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color,
    this.textColor,
    this.borderColor,
    this.outlined = false,
    this.width,
    this.trailingIcon,
    this.isLoading = false,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Color baseColor = widget.color ?? AppColors.primary;
    final BorderRadius radius = BorderRadius.circular(10);

    final Color bgColor = widget.outlined
        ? Colors.transparent
        : (_isHovered ? baseColor.withOpacity(0.92) : baseColor);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Material(
        color: bgColor,
        borderRadius: radius,
        // InkWell needs a Material ancestor to draw its ripple — this
        // Material widget also paints the button's background color,
        // so the ripple appears correctly clipped to the button shape.
        child: InkWell(
          onTap: widget.isLoading ? null : widget.onPressed,
          borderRadius: radius,
          splashColor: widget.outlined
              ? baseColor.withOpacity(0.15)
              : Colors.white.withOpacity(0.25),
          highlightColor: widget.outlined
              ? baseColor.withOpacity(0.08)
              : Colors.white.withOpacity(0.1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: widget.width ?? double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: widget.outlined
                  ? Border.all(
                      color: _isHovered
                          ? baseColor
                          : (widget.borderColor ?? AppColors.textDark),
                      width: 1.5,
                    )
                  : null,
              boxShadow: (!widget.outlined && _isHovered)
                  ? [
                      BoxShadow(
                        color: baseColor.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                else
                Text(
                  widget.text,
                  style: AppTextStyles.button.copyWith(
                    color: widget.outlined
                        ? (widget.textColor ?? AppColors.textDark)
                        : (widget.textColor ?? Colors.white),
                  ),
                ),
                if (widget.trailingIcon != null) ...[
                  const SizedBox(width: 8),
                  Icon(widget.trailingIcon,
                      color: widget.outlined
                          ? (widget.textColor ?? AppColors.textDark)
                          : (widget.textColor ?? Colors.white),
                      size: 18),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A generic hoverable/pressable card wrapper — use this to wrap any
/// list item, service card, or option card that needs the same
/// hover-lift + tap-ripple behavior.
class HoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const HoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
  });

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(16);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            transform: _hovered
                ? (Matrix4.identity()..translate(0.0, -2.0))
                : Matrix4.identity(),
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}