import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A frosted "liquid glass" panel: it blurs whatever is behind it,
/// adds a see-through white tint, a thin bright edge and a soft shadow.
///
/// Blur is the expensive part on cheap phones, so use it for a few
/// floating panels (the card at the bottom), not for every list item.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = 28,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.blur = 20,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  /// How strongly the background is blurred (the blur's sigma).
  final double blur;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return Padding(
      padding: margin,
      // The shadow sits outside the clip, so it is not cut off.
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: const [
            BoxShadow(
              color: Color(0x29102219),
              blurRadius: 30,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            // Blur only what is behind this panel.
            filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                // Fairly solid white keeps text readable over a busy map.
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xC7FFFFFF), Color(0x85FFFFFF)],
                ),
                border: Border.all(color: const Color(0xBFFFFFFF)),
              ),
              child: Stack(
                children: [
                  // A thin highlight along the top edge, like light on glass.
                  Positioned(
                    left: borderRadius / 2,
                    right: borderRadius / 2,
                    top: 0,
                    height: 1.5,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0x00FFFFFF),
                            Color(0xF2FFFFFF),
                            Color(0x00FFFFFF),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // A see-through Material so list tiles and buttons inside
                  // can draw their tap ripple on the glass.
                  Material(
                    type: MaterialType.transparency,
                    child: Padding(padding: padding, child: child),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
