import 'dart:typed_data';

import 'detection.dart';
import 'detector_unsupported.dart'
    if (dart.library.ffi) 'detector_tflite.dart'
    as platform;
import 'model_config.dart';

/// Finds containers in a photo.
abstract class ContainerDetector {
  /// False in the browser: TensorFlow Lite runs only in the phone app.
  bool get isSupported;

  /// Photo bytes (JPEG/PNG) -> boxes. Throws [ModelMissingException] when
  /// the .tflite file was not copied into assets/models/.
  Future<DetectionResult> detect(Uint8List photoBytes);

  void dispose();
}

class DetectionResult {
  const DetectionResult({
    required this.detections,
    required this.photoWidth,
    required this.photoHeight,
    required this.inputShape,
  });

  final List<Detection> detections;
  final int photoWidth;
  final int photoHeight;

  /// The model's input shape, shown so the channels question is visible.
  final List<int> inputShape;
}

class ModelMissingException implements Exception {
  const ModelMissingException(this.asset);
  final String asset;

  @override
  String toString() =>
      'The model file $asset is missing. Copy it from the app-model '
      'Drive folder into app/aedex_app/assets/models/ and rebuild.';
}

/// The real detector on phones, a placeholder in the browser.
ContainerDetector createDetector([ModelFiles files = ModelFiles.current]) =>
    platform.createPlatformDetector(files);
