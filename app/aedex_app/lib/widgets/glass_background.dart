import 'package:flutter/material.dart';

import '../theme.dart';

/// Soft Patak blue and butter glows for screens without a map, so the
/// glass panels have colour behind them to blur.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget glow(Alignment a, Color c, double size) => Align(
      alignment: a,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [c, c.withValues(alpha: 0)]),
        ),
      ),
    );

    return DecoratedBox(
      decoration: const BoxDecoration(color: AedexColors.skyWash),
      child: Stack(
        children: [
          glow(const Alignment(-1.3, -1.1), const Color(0x993F7BFF), 380),
          glow(const Alignment(1.4, -0.1), const Color(0x731F3FBF), 340),
          glow(const Alignment(-1.2, 1.1), const Color(0xB3FFD84D), 360),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}
