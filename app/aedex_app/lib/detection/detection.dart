import 'dart:ui';

/// One box the model found, in the original photo's pixels.
class Detection {
  const Detection({
    required this.label,
    required this.classIndex,
    required this.score,
    required this.box,
  });

  /// Class name from labels.txt, e.g. "Tire".
  final String label;
  final int classIndex;

  /// How sure the model is, 0 to 1.
  final double score;
  final Rect box;
}

/// Boxes -> the scan record's `counts` (class name -> how many).
Map<String, int> countByLabel(List<Detection> detections) {
  final counts = <String, int>{};
  for (final d in detections) {
    counts[d.label] = (counts[d.label] ?? 0) + 1;
  }
  return counts;
}
