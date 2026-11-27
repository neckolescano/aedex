import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'detection.dart';

/// Turns YOLO's raw output into real boxes.
///
/// The output holds N candidate boxes (8,400 for a 640 photo). Each has
/// 4 box numbers (centre x, centre y, width, height) and one score per class.
/// Shape [1, 4 + classes, N] (our export) or [1, N, 4 + classes] both work.
///
/// Steps: keep each box's best class, drop boxes under [confThreshold],
/// remove duplicates of the same object (non-maximum suppression, [iouThreshold]),
/// then undo the letterbox so boxes sit on the original photo.
List<Detection> decodeYolo({
  required Float32List output,
  required List<int> shape,
  required List<String> labels,
  required double confThreshold,
  required double iouThreshold,
  required int imageSize,
  required double scale,
  required double padX,
  required double padY,
  required int photoWidth,
  required int photoHeight,
}) {
  final channels = 4 + labels.length;
  late final int n;
  late final double Function(int box, int channel) at;
  if (shape.length == 3 && shape[1] == channels) {
    n = shape[2];
    at = (i, c) => output[c * n + i];
  } else if (shape.length == 3 && shape[2] == channels) {
    n = shape[1];
    at = (i, c) => output[i * channels + c];
  } else {
    throw ArgumentError(
      'Output shape $shape does not fit ${labels.length} classes '
      '(expected 4 + ${labels.length} = $channels values per box). '
      'Is labels.txt the one exported with this model?',
    );
  }

  final candidates = <Detection>[];
  var maxCoord = 0.0;
  for (var i = 0; i < n; i++) {
    var best = -1;
    var bestScore = confThreshold;
    for (var c = 0; c < labels.length; c++) {
      final s = at(i, 4 + c);
      if (s >= bestScore) {
        bestScore = s;
        best = c;
      }
    }
    if (best < 0) continue;
    final cx = at(i, 0), cy = at(i, 1), w = at(i, 2), h = at(i, 3);
    maxCoord = math.max(maxCoord, math.max(cx + w / 2, cy + h / 2));
    candidates.add(
      Detection(
        label: labels[best],
        classIndex: best,
        score: bestScore,
        box: Rect.fromCenter(center: Offset(cx, cy), width: w, height: h),
      ),
    );
  }

  // Some exports give box numbers as 0..1 instead of pixels: scale them up.
  final unit = maxCoord <= 1.5 ? imageSize.toDouble() : 1.0;

  final kept = nonMaxSuppression(candidates, iouThreshold);
  return [
    for (final d in kept)
      Detection(
        label: d.label,
        classIndex: d.classIndex,
        score: d.score,
        box: _toPhoto(d.box, unit, scale, padX, padY, photoWidth, photoHeight),
      ),
  ];
}

Rect _toPhoto(
  Rect r,
  double unit,
  double scale,
  double padX,
  double padY,
  int photoWidth,
  int photoHeight,
) {
  double x(double v) =>
      ((v * unit - padX) / scale).clamp(0, photoWidth.toDouble());
  double y(double v) =>
      ((v * unit - padY) / scale).clamp(0, photoHeight.toDouble());
  return Rect.fromLTRB(x(r.left), y(r.top), x(r.right), y(r.bottom));
}

/// Keeps the strongest box among overlapping boxes of the SAME class.
/// Two tires side by side stay two; one tire seen 5 times becomes one.
List<Detection> nonMaxSuppression(List<Detection> boxes, double iouThreshold) {
  final sorted = [...boxes]..sort((a, b) => b.score.compareTo(a.score));
  final kept = <Detection>[];
  for (final d in sorted) {
    final duplicate = kept.any(
      (k) => k.classIndex == d.classIndex && iou(k.box, d.box) > iouThreshold,
    );
    if (!duplicate) kept.add(d);
  }
  return kept;
}

/// Intersection over union: how much two boxes overlap, 0 (none) to 1 (same).
double iou(Rect a, Rect b) {
  final inter = a.intersect(b);
  if (inter.width <= 0 || inter.height <= 0) return 0;
  final i = inter.width * inter.height;
  final u = a.width * a.height + b.width * b.height - i;
  return u <= 0 ? 0 : i / u;
}
