import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';

/// Patak's moods. Each one is an SVG in `assets/brand/` drawn on the same
/// 100 x 100 body; only the eyes, mouth, arms and props change.
enum PatakPose {
  searching('assets/brand/patak.svg', 'Patak, searching with a magnifier'),
  worried('assets/brand/patak-worried.svg', 'Patak, looking worried'),
  happy('assets/brand/patak-happy.svg', 'Patak, happy'),
  sleepy('assets/brand/patak-sleepy.svg', 'Patak, sleeping'),
  wave('assets/brand/patak-wave.svg', 'Patak, waving');

  const PatakPose(this.asset, this.label);

  final String asset;

  /// What a screen reader says.
  final String label;
}

/// The Patak mascot. Every screen uses this widget instead of calling
/// SvgPicture itself, so the art, sizes, motion and labels stay the same.
///
/// `animate: true` adds a gentle bob (plus a magnifier sweep when searching).
/// It turns itself off when the phone asks for less motion.
class Patak extends StatefulWidget {
  const Patak({
    super.key,
    this.pose = PatakPose.searching,
    this.size = 96,
    this.animate = false,
    this.onDark = false,
    this.semanticLabel,
  });

  final PatakPose pose;
  final double size;
  final bool animate;

  /// On ink backgrounds the ink props (magnifier, "z z", wave lines) turn
  /// butter so they stay visible. Eyes and mouth stay ink.
  final bool onDark;

  /// Overrides [PatakPose.label], for example "Patak, all clear".
  final String? semanticLabel;

  @override
  State<Patak> createState() => _PatakState();
}

class _PatakState extends State<Patak> with SingleTickerProviderStateMixin {
  // One slow loop drives every motion; sin() turns it into a smooth sway.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );

  bool _moving(BuildContext context) =>
      widget.animate && !MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoop();
  }

  @override
  void didUpdateWidget(Patak old) {
    super.didUpdateWidget(old);
    _syncLoop();
  }

  void _syncLoop() {
    if (_moving(context)) {
      if (!_loop.isAnimating) _loop.repeat();
    } else {
      _loop
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  Widget _svg(String asset, {bool allProps = false}) => SvgPicture(
    SvgAssetLoader(
      asset,
      colorMapper: widget.onDark ? _PropsOnDark(all: allProps) : null,
    ),
    width: widget.size,
    height: widget.size,
    excludeFromSemantics: true,
  );

  @override
  Widget build(BuildContext context) {
    final moving = _moving(context);
    final pose = widget.pose;
    final size = widget.size;

    Widget art;
    // Searching is drawn in two layers when it moves, and on dark
    // backgrounds (so the magnifier layer can turn butter).
    final layered = pose == PatakPose.searching && (moving || widget.onDark);
    if (layered) {
      // Two layers: the magnifier (with its arm) under the body, so only
      // the magnifier sweeps. It turns around the shoulder at (74, 70).
      art = Stack(
        children: [
          AnimatedBuilder(
            animation: _loop,
            builder: (context, child) => Transform.rotate(
              angle: math.sin(_loop.value * 4 * math.pi) * 0.17, // ~10 deg
              alignment: const Alignment(0.48, 0.40),
              child: child,
            ),
            child: _svg(
              'assets/brand/parts/patak-search-tool.svg',
              allProps: true,
            ),
          ),
          _svg('assets/brand/parts/patak-search-body.svg'),
        ],
      );
    } else {
      art = _svg(pose.asset);
    }

    if (moving) {
      final still = art;
      art = AnimatedBuilder(
        animation: _loop,
        builder: (context, child) {
          final wave = math.sin(_loop.value * 2 * math.pi);
          final fast = math.sin(_loop.value * 4 * math.pi);
          // Small wiggle for worried and waving; everyone bobs.
          final tilt = switch (pose) {
            PatakPose.worried => fast * 0.05,
            PatakPose.wave => fast * 0.07,
            _ => 0.0,
          };
          return Transform.translate(
            offset: Offset(0, wave * size * 0.03),
            child: Transform.rotate(
              angle: tilt,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          );
        },
        child: still,
      );
    }

    return Semantics(
      image: true,
      label: widget.semanticLabel ?? pose.label,
      child: SizedBox(width: size, height: size, child: art),
    );
  }
}

/// Swaps ink for butter in the props of an SVG: everything in the
/// magnifier layer, or only shapes tagged `id="prop"` in a pose file.
class _PropsOnDark extends ColorMapper {
  const _PropsOnDark({required this.all});

  final bool all;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) => (all || id == 'prop') && color == AedexColors.ink
      ? AedexColors.butter
      : color;

  // Equal mappers let flutter_svg reuse its cached drawing.
  @override
  bool operator ==(Object other) => other is _PropsOnDark && other.all == all;

  @override
  int get hashCode => all.hashCode;
}

/// The logo lockup: Patak followed by "aedex" in Lilita One. Built in
/// Flutter, not as SVG text, because flutter_svg cannot load Google Fonts.
/// Cobalt on light backgrounds, butter on ink backgrounds.
class PatakLogo extends StatelessWidget {
  const PatakLogo({super.key, this.height = 36, this.onDark = false});

  final double height;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Aedex',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Patak(size: height, onDark: onDark),
          SizedBox(width: height * 0.15),
          Text(
            'aedex',
            style: aedexHeading(
              context,
              TextStyle(
                fontSize: height * 0.78,
                height: 1,
                color: onDark ? AedexColors.butter : AedexColors.cobalt,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
