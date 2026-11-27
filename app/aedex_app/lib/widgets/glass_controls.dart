import 'package:flutter/material.dart';

import '../theme.dart';

/// The deep-green "tinted glass" look for main actions and selected items:
/// a green gradient, a bright top edge and a soft green shadow.
BoxDecoration tintDecoration({double radius = 25}) => BoxDecoration(
  borderRadius: BorderRadius.circular(radius),
  gradient: const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xEB267052), Color(0xF014402F)],
  ),
  border: Border.all(color: const Color(0x61FFFFFF)),
  boxShadow: const [
    BoxShadow(color: Color(0x5914402F), blurRadius: 22, offset: Offset(0, 8)),
  ],
);

/// Frosted white, without blur: cheap enough for many small items.
BoxDecoration frostDecoration({double radius = 19, bool dark = false}) =>
    BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: dark ? const Color(0x1FFFFFFF) : const Color(0xB3FFFFFF),
      border: Border.all(
        color: dark ? const Color(0x38FFFFFF) : const Color(0xE6FFFFFF),
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14102219),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    );

/// Main action button: a green glass pill.
class TintButton extends StatelessWidget {
  const TintButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 46,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: DecoratedBox(
          decoration: tintDecoration(radius: height / 2),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onPressed,
              child: SizedBox(
                height: height,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A round glass icon button (search bar, close, locate...).
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.tinted = false,
    this.dark = false,
    this.size = 42,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool tinted;
  final bool dark;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: tinted
            ? tintDecoration(radius: size / 2)
            : frostDecoration(radius: size / 2, dark: dark),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                icon,
                size: size * 0.45,
                color: tinted || dark ? Colors.white : AedexColors.brand,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A pill chip: tinted green when selected, frosted white otherwise.
class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// A smaller number after the label, e.g. a count.
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AedexColors.ink;
    return Semantics(
      button: true,
      selected: selected,
      child: DecoratedBox(
        decoration: selected
            ? tintDecoration(radius: 20)
            : frostDecoration(radius: 20),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      trailing!,
                      style: TextStyle(
                        color: color.withValues(alpha: 0.75),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small coloured square with the container count (lists and cards).
class CountBadge extends StatelessWidget {
  const CountBadge({
    super.key,
    required this.count,
    required this.color,
    required this.textColor,
    this.size = 44,
  });

  final int count;
  final Color color;
  final Color textColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        // Glossy highlight like the pins.
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 0.9,
          colors: [Color.lerp(color, Colors.white, 0.4)!, color],
          stops: const [0, 0.6],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}
