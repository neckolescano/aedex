import 'dart:convert';

/// The model files, in ONE place (docs/model-for-app.md, swap rule 3).
/// Swapping in model v2 = change [current] to 'v2' and drop in the files.
class ModelFiles {
  const ModelFiles(this.version);

  static const current = ModelFiles('v1');

  final String version;

  String get model => 'assets/models/aedex-$version.tflite';
  String get labels => 'assets/models/labels.txt';
  String get info => 'assets/models/aedex-$version-info.json';
}

/// Settings read from the model's info file, so thresholds come from
/// Member 1's export, not from numbers copied into the app.
class ModelSettings {
  const ModelSettings({
    required this.confThreshold,
    required this.iouThreshold,
    required this.imageSize,
  });

  /// Fallbacks match docs/model-for-app.md.
  static const defaults = ModelSettings(
    confThreshold: 0.15,
    iouThreshold: 0.45,
    imageSize: 640,
  );

  final double confThreshold;
  final double iouThreshold;
  final int imageSize;

  factory ModelSettings.fromInfoJson(String text) {
    final j = jsonDecode(text) as Map<String, dynamic>;
    return ModelSettings(
      confThreshold:
          (j['conf_threshold'] as num?)?.toDouble() ?? defaults.confThreshold,
      iouThreshold:
          (j['iou_threshold'] as num?)?.toDouble() ?? defaults.iouThreshold,
      imageSize: (j['imgsz'] as num?)?.toInt() ?? defaults.imageSize,
    );
  }
}

/// labels.txt -> class names, one per line, in label-number order
/// (swap rules 1 and 2: names and class count come from this file).
List<String> parseLabels(String text) => text
    .split(RegExp(r'\r?\n'))
    .map((l) => l.trim())
    .where((l) => l.isNotEmpty)
    .toList();
