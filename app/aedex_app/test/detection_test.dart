import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:aedex_app/data/scan_builder.dart';
import 'package:aedex_app/detection/detection.dart';
import 'package:aedex_app/detection/model_config.dart';
import 'package:aedex_app/detection/postprocess.dart';
import 'package:aedex_app/detection/preprocess.dart';
import 'package:aedex_app/models/scan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';

void main() {
  final labels = parseLabels(
    File('assets/models/labels.txt').readAsStringSync(),
  );

  group('labels.txt and the info file', () {
    test('7 classes in the fixed order from CLAUDE.md', () {
      expect(labels, [
        'Bottle',
        'Coconut-Exocarp',
        'Drain-Inlet',
        'Tire',
        'Vase',
        'Cup',
        'Plastic-Container',
      ]);
    });

    test('blank lines and Windows line endings are ignored', () {
      expect(parseLabels('A\r\nB\r\n\r\n'), ['A', 'B']);
    });

    test('thresholds come from the info file', () {
      final s = ModelSettings.fromInfoJson(
        File('assets/models/aedex-v1-info.json').readAsStringSync(),
      );
      expect(s.confThreshold, 0.15);
      expect(s.iouThreshold, 0.45);
      expect(s.imageSize, 640);
    });

    test('a new model version is a one-line change', () {
      const v2 = ModelFiles('v2');
      expect(v2.model, 'assets/models/aedex-v2.tflite');
      expect(v2.labels, 'assets/models/labels.txt');
    });
  });

  group('letterbox (photo -> model input)', () {
    // A 4x2 photo: left half red, right half blue.
    final photo = img.Image(width: 4, height: 2);
    for (var y = 0; y < 2; y++) {
      for (var x = 0; x < 4; x++) {
        photo.setPixelRgb(x, y, x < 2 ? 255 : 0, 0, x < 2 ? 0 : 255);
      }
    }

    test('keeps the shape and pads top and bottom with grey', () {
      final m = letterbox(photo, 8, channelsFirst: true);
      expect(m.scale, 2); // 4 wide -> 8 wide
      expect(m.padX, 0);
      expect(m.padY, 2); // 4 tall in an 8 tall square: 2 rows each side
      expect(m.data[0], closeTo(114 / 255, 1e-6)); // top-left is padding
    });

    test('channels first: all red, then all green, then all blue', () {
      final m = letterbox(photo, 8, channelsFirst: true);
      const plane = 64;
      final pos = 2 * 8 + 0; // row 2 (first photo row), column 0: red
      expect(m.data[pos], closeTo(1, 1e-6));
      expect(m.data[plane + pos], closeTo(0, 1e-6));
      expect(m.data[2 * plane + pos], closeTo(0, 1e-6));
    });

    test('channels last: red, green, blue side by side per pixel', () {
      final m = letterbox(photo, 8, channelsFirst: false);
      final pos = (2 * 8 + 7) * 3; // row 2, column 7: blue
      expect(m.data.sublist(pos, pos + 3), [0, 0, 1]);
    });
  });

  group('decodeYolo (model output -> boxes)', () {
    // 3 candidate boxes, layout [1, 4 + 7, 3] like the real [1, 11, 8400].
    Float32List output(List<List<double>> boxes) {
      final n = boxes.length, c = 4 + labels.length;
      final out = Float32List(c * n);
      for (var i = 0; i < n; i++) {
        for (var k = 0; k < c; k++) {
          out[k * n + i] = boxes[i][k];
        }
      }
      return out;
    }

    List<double> box(
      double cx,
      double cy,
      double w,
      double h,
      int cls,
      double score,
    ) {
      final v = [cx, cy, w, h, ...List.filled(labels.length, 0.0)];
      v[4 + cls] = score;
      return v;
    }

    List<Detection> run(Float32List out, List<int> shape) => decodeYolo(
      output: out,
      shape: shape,
      labels: labels,
      confThreshold: 0.15,
      iouThreshold: 0.45,
      imageSize: 640,
      scale: 0.5, // photo was 1280 wide
      padX: 0,
      padY: 80,
      photoWidth: 1280,
      photoHeight: 960,
    );

    test('drops weak boxes and merges duplicates of one object', () {
      final out = output([
        box(320, 320, 100, 100, 3, 0.90), // tire
        box(322, 318, 100, 100, 3, 0.60), // same tire again
        box(100, 100, 50, 50, 5, 0.10), // cup, too unsure (< 0.15)
      ]);
      final d = run(out, [1, 11, 3]);
      expect(d, hasLength(1));
      expect(d.single.label, 'Tire');
      expect(d.single.score, closeTo(0.9, 1e-6));
    });

    test('two different objects in the same place both stay', () {
      final out = output([
        box(320, 320, 100, 100, 3, 0.90), // tire
        box(320, 320, 100, 100, 5, 0.80), // cup in the tire
      ]);
      expect(run(out, [1, 11, 2]).map((e) => e.label), ['Tire', 'Cup']);
    });

    test('boxes are moved back onto the original photo', () {
      final d = run(output([box(320, 320, 100, 100, 3, 0.9)]), [1, 11, 1]);
      // (320 - 0) / 0.5 = 640 ; (320 - 80) / 0.5 = 480
      expect(d.single.box.center, const Offset(640, 480));
      expect(d.single.box.width, 200);
    });

    test('box numbers given as 0..1 are scaled to pixels', () {
      final d = run(output([box(0.5, 0.5, 0.15625, 0.15625, 3, 0.9)]), [
        1,
        11,
        1,
      ]);
      expect(d.single.box.center, const Offset(640, 480));
    });

    test('the transposed layout [1, N, 11] works too', () {
      final v = box(320, 320, 100, 100, 0, 0.7);
      final d = run(Float32List.fromList(v), [1, 1, 11]);
      expect(d.single.label, 'Bottle');
    });

    test('a labels.txt that does not fit the model is reported', () {
      expect(() => run(Float32List(12 * 2), [1, 12, 2]), throwsArgumentError);
    });

    test('iou: same box 1, no overlap 0', () {
      const a = Rect.fromLTWH(0, 0, 10, 10);
      expect(iou(a, a), 1);
      expect(iou(a, const Rect.fromLTWH(20, 20, 5, 5)), 0);
    });
  });

  group('boxes -> scan record', () {
    final detections = [
      for (final l in ['Tire', 'Tire', 'Cup'])
        Detection(label: l, classIndex: 0, score: 0.9, box: Rect.zero),
    ];
    final now = DateTime.utc(2026, 11, 27, 1, 30);

    test('counts per class name, status reported', () {
      final s = buildScan(
        detections: detections,
        position: const LatLng(14.60123, 120.98456),
        privateHome: false,
        now: now,
      );
      expect(s.counts, {'Tire': 2, 'Cup': 1});
      expect(s.status, ScanStatus.reported);
      expect(s.precision, LocationPrecision.exact);
      expect(s.location, const LatLng(14.60123, 120.98456));
    });

    test('a private home is rounded to street level', () {
      final s = buildScan(
        detections: detections,
        position: const LatLng(14.60123, 120.98456),
        privateHome: true,
        now: now,
      );
      expect(s.precision, LocationPrecision.street);
      expect(s.location.latitude, closeTo(14.601, 1e-9));
      expect(s.location.longitude, closeTo(120.985, 1e-9));
    });

    test('no boxes = an empty, clear scan', () {
      final s = buildScan(
        detections: const [],
        position: const LatLng(14.6, 121),
        privateHome: false,
        now: now,
      );
      expect(s.counts, isEmpty);
      expect(s.risk, RiskLevel.clear);
    });
  });
}
