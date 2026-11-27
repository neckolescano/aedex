import 'dart:typed_data';

import 'detector.dart';
import 'model_config.dart';

/// Browser stand-in: TensorFlow Lite needs the phone app.
ContainerDetector createPlatformDetector(ModelFiles files) =>
    _UnsupportedDetector();

class _UnsupportedDetector implements ContainerDetector {
  @override
  bool get isSupported => false;

  @override
  Future<DetectionResult> detect(Uint8List photoBytes) =>
      throw UnsupportedError(
        'Scanning runs in the phone app, not the browser.',
      );

  @override
  void dispose() {}
}
