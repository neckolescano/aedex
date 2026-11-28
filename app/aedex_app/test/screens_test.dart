import 'dart:io';
import 'dart:typed_data';

import 'package:aedex_app/data/scan_store.dart';
import 'package:aedex_app/detection/detection.dart';
import 'package:aedex_app/detection/detector.dart';
import 'package:aedex_app/models/scan.dart';
import 'package:aedex_app/screens/filter_screen.dart';
import 'package:aedex_app/filters/scan_filter.dart';
import 'package:aedex_app/screens/home_screen.dart';
import 'package:aedex_app/screens/scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';
import 'package:aedex_app/widgets/patak.dart';

/// Pretends to be the model: always finds 2 tires and a cup.
class FakeDetector implements ContainerDetector {
  @override
  bool get isSupported => true;

  @override
  Future<DetectionResult> detect(Uint8List photoBytes) async =>
      const DetectionResult(
        detections: [
          Detection(
            label: 'Tire',
            classIndex: 3,
            score: 0.9,
            box: Rect.fromLTWH(10, 10, 40, 40),
          ),
          Detection(
            label: 'Tire',
            classIndex: 3,
            score: 0.8,
            box: Rect.fromLTWH(60, 10, 40, 40),
          ),
          Detection(
            label: 'Cup',
            classIndex: 5,
            score: 0.7,
            box: Rect.fromLTWH(10, 60, 20, 20),
          ),
        ],
        photoWidth: 120,
        photoHeight: 90,
        inputShape: [1, 3, 640, 640],
      );

  @override
  void dispose() {}
}

// Reduce motion is on, as a phone user can choose: Patak stands still, so
// pumpAndSettle can finish. Patak's motion is tested in patak_test.dart.
Widget wrap(Widget child) => MaterialApp(
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: Scaffold(body: child),
    ),
  ),
);

void main() {
  final sample = parseScans(File('../sample_scans.json').readAsStringSync());

  testWidgets('Home: empty state points to the Scan tab', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      wrap(
        HomeScreen(
          scans: const [],
          onOpenScan: () => opened = true,
          onOpenHotspots: () {},
          onShowOnMap: (_) {},
        ),
      ),
    );
    expect(find.text('No scans yet'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is Patak && w.pose == PatakPose.sleepy),
      findsOneWidget,
    );
    await tester.tap(find.text('Scan your first photo'));
    expect(opened, isTrue);
  });

  testWidgets('Home: progress and the zone to clean first', (tester) async {
    await tester.pumpWidget(
      wrap(
        HomeScreen(
          scans: sample,
          onOpenScan: () {},
          onOpenHotspots: () {},
          onShowOnMap: (_) {},
        ),
      ),
    );
    // 2 cleaned + 1 verified out of 10.
    expect(find.text('3/10'), findsOneWidget);
    expect(find.text('CLEAN FIRST'), findsOneWidget);
    expect(find.text('Zone A'), findsOneWidget);
  });

  testWidgets('Scan: photo -> boxes -> saved scan record', (tester) async {
    final photo = Uint8List.fromList(
      img.encodePng(img.Image(width: 120, height: 90)),
    );
    Scan? saved;
    await tester.pumpWidget(
      wrap(
        ScanScreen(
          detector: FakeDetector(),
          pickPhoto: (_) async => photo,
          locate: () async => const LatLng(14.60123, 120.98456),
          onSave: (s) async => saved = s,
        ),
      ),
    );

    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();
    expect(find.text('3 possible breeding sites'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is Patak && w.pose == PatakPose.worried),
      findsOneWidget,
    );
    expect(find.text('Tire × 2'), findsOneWidget);

    await tester.tap(find.text('Save to map'));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.counts, {'Tire': 2, 'Cup': 1});
    expect(saved!.status, ScanStatus.reported);
    // "Private home" is on by default: rounded to street level.
    expect(saved!.precision, LocationPrecision.street);
    expect(saved!.location.latitude, closeTo(14.601, 1e-9));
  });

  testWidgets('Scan: nothing found -> happy Patak, all clear', (tester) async {
    final photo = Uint8List.fromList(
      img.encodePng(img.Image(width: 120, height: 90)),
    );
    await tester.pumpWidget(
      wrap(
        ScanScreen(
          detector: _NothingFound(),
          pickPhoto: (_) async => photo,
          locate: () async => const LatLng(14.6, 120.98),
          onSave: (_) async {},
        ),
      ),
    );
    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();
    expect(find.text('All clear!'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is Patak && w.pose == PatakPose.happy),
      findsOneWidget,
    );
  });

  testWidgets('Scan: a missing model file is explained', (tester) async {
    await tester.pumpWidget(
      wrap(
        ScanScreen(
          detector: _MissingModel(),
          pickPhoto: (_) async => Uint8List(1),
          onSave: (_) async {},
        ),
      ),
    );
    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('aedex-v1.tflite is missing'), findsOneWidget);
  });

  testWidgets('Filters: the button counts matching scans', (tester) async {
    ScanFilter? result;
    // A tall phone-like screen, so every tile is visible above the button.
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await Navigator.push(
              context,
              MaterialPageRoute<ScanFilter>(
                builder: (_) =>
                    FilterScreen(initial: ScanFilter.all, scans: sample),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Show 10 scans'), findsOneWidget);

    // Untick Cleaned and Verified: 5 reported + 2 assigned remain.
    await tester.tap(find.text('Cleaned'));
    await tester.tap(find.text('Verified'));
    await tester.pumpAndSettle();
    expect(find.text('Show 7 scans'), findsOneWidget);

    await tester.tap(find.text('Show 7 scans'));
    await tester.pumpAndSettle();
    expect(result!.statuses, {ScanStatus.reported, ScanStatus.assigned});
  });
}

class _NothingFound extends FakeDetector {
  @override
  Future<DetectionResult> detect(Uint8List photoBytes) async =>
      const DetectionResult(
        detections: [],
        photoWidth: 120,
        photoHeight: 90,
        inputShape: [1, 3, 640, 640],
      );
}

class _MissingModel extends FakeDetector {
  @override
  Future<DetectionResult> detect(Uint8List photoBytes) async =>
      throw const ModelMissingException('assets/models/aedex-v1.tflite');
}
