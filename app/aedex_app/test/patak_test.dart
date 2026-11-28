import 'package:aedex_app/theme.dart';
import 'package:aedex_app/widgets/patak.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: buildAedexTheme(useGoogleFont: false),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(body: Center(child: child)),
  ),
);

Iterable<String> _assetsShown(WidgetTester tester) => tester
    .widgetList<SvgPicture>(find.byType(SvgPicture))
    .map((w) => (w.bytesLoader as SvgAssetLoader).assetName);

void main() {
  testWidgets('every pose shows its own art and a screen-reader label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    for (final pose in PatakPose.values) {
      await tester.pumpWidget(_host(Patak(pose: pose, size: 80)));
      expect(_assetsShown(tester), [pose.asset]);
      expect(find.bySemanticsLabel(pose.label), findsOneWidget);
      expect(tester.getSize(find.byType(Patak)), const Size(80, 80));
    }
    semantics.dispose();
  });

  testWidgets('every SVG file loads and parses', (tester) async {
    final assets = [
      for (final p in PatakPose.values) p.asset,
      'assets/brand/patak-submark.svg',
      'assets/brand/parts/patak-search-body.svg',
      'assets/brand/parts/patak-search-tool.svg',
    ];
    for (final a in assets) {
      final info = await tester.runAsync(
        () => vg.loadPicture(SvgAssetLoader(a), null),
      );
      expect(info, isNotNull, reason: a);
      expect(info!.size, const Size(100, 100), reason: a);
      info.picture.dispose();
    }
  });

  testWidgets('animated searching moves only the magnifier layer', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const Patak(animate: true)));
    expect(_assetsShown(tester), [
      'assets/brand/parts/patak-search-tool.svg',
      'assets/brand/parts/patak-search-body.svg',
    ]);
    // The loop is running: a frame is always scheduled.
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 700));
  });

  testWidgets('reduce motion turns the animation off', (tester) async {
    await tester.pumpWidget(
      _host(
        const Patak(pose: PatakPose.wave, animate: true),
        reduceMotion: true,
      ),
    );
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpAndSettle(); // would time out if anything moved
    expect(_assetsShown(tester), [PatakPose.wave.asset]);
  });

  testWidgets(
    'on dark, searching uses the layers so the magnifier can be butter',
    (tester) async {
      await tester.pumpWidget(_host(const Patak(onDark: true)));
      expect(_assetsShown(tester), [
        'assets/brand/parts/patak-search-tool.svg',
        'assets/brand/parts/patak-search-body.svg',
      ]);
      final loaders = tester
          .widgetList<SvgPicture>(find.byType(SvgPicture))
          .map((w) => w.bytesLoader as SvgAssetLoader);
      expect(loaders.every((l) => l.colorMapper != null), isTrue);
    },
  );

  testWidgets('a custom label replaces the pose label', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        const Patak(pose: PatakPose.happy, semanticLabel: 'Patak, all clear'),
      ),
    );
    expect(find.bySemanticsLabel('Patak, all clear'), findsOneWidget);
    expect(find.bySemanticsLabel('Patak, happy'), findsNothing);
    semantics.dispose();
  });

  testWidgets('logo lockup: Patak plus "aedex", read as "Aedex"', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_host(const PatakLogo()));
    expect(find.text('aedex'), findsOneWidget);
    expect(find.byType(Patak), findsOneWidget);
    expect(find.bySemanticsLabel('Aedex'), findsOneWidget);
    final style = tester.widget<Text>(find.text('aedex')).style!;
    expect(style.color, AedexColors.forest);

    await tester.pumpWidget(_host(const PatakLogo(onDark: true)));
    expect(
      tester.widget<Text>(find.text('aedex')).style!.color,
      AedexColors.butter,
    );
    semantics.dispose();
  });
}
