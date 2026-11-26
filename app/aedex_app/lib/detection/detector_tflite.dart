import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'detector.dart';
import 'model_config.dart';
import 'postprocess.dart';
import 'preprocess.dart';

ContainerDetector createPlatformDetector(ModelFiles files) =>
    TfliteDetector(files);

/// Runs aedex-vN.tflite on the phone with TensorFlow Lite.
class TfliteDetector implements ContainerDetector {
  TfliteDetector(this.files);

  final ModelFiles files;
  Interpreter? _interpreter;
  late List<String> _labels;
  late ModelSettings _settings;

  @override
  bool get isSupported => true;

  Future<Interpreter> _load() async {
    if (_interpreter != null) return _interpreter!;
    try {
      await rootBundle.load(files.model);
    } on FlutterError {
      throw ModelMissingException(files.model);
    }
    _labels = parseLabels(await rootBundle.loadString(files.labels));
    try {
      _settings = ModelSettings.fromInfoJson(
        await rootBundle.loadString(files.info),
      );
    } on FlutterError {
      _settings = ModelSettings.defaults;
    }
    return _interpreter = await Interpreter.fromAsset(files.model);
  }

  @override
  Future<DetectionResult> detect(Uint8List photoBytes) async {
    final interpreter = await _load();
    final decoded = img.decodeImage(photoBytes);
    if (decoded == null) {
      throw const FormatException('Could not read this photo.');
    }
    // Phones store "rotated" in a tag; apply it so boxes match the view.
    final photo = img.bakeOrientation(decoded);

    // Read the layout from the model itself instead of trusting a note:
    // [1, 3, 640, 640] = channels first, [1, 640, 640, 3] = channels last.
    final inShape = interpreter.getInputTensor(0).shape;
    final channelsFirst = inShape.length == 4 && inShape[1] == 3;
    final size = channelsFirst ? inShape[2] : inShape[1];

    final input = letterbox(photo, size, channelsFirst: channelsFirst);
    final outTensor = interpreter.getOutputTensor(0);
    final outShape = outTensor.shape;
    final outCount = outShape.fold<int>(1, (a, b) => a * b);
    final outBuffer = Float32List(outCount);

    interpreter.run(input.data.buffer, outBuffer.buffer);

    final detections = decodeYolo(
      output: outBuffer,
      shape: outShape,
      labels: _labels,
      confThreshold: _settings.confThreshold,
      iouThreshold: _settings.iouThreshold,
      imageSize: size,
      scale: input.scale,
      padX: input.padX,
      padY: input.padY,
      photoWidth: photo.width,
      photoHeight: photo.height,
    );
    return DetectionResult(
      detections: detections,
      photoWidth: photo.width,
      photoHeight: photo.height,
      inputShape: inShape,
    );
  }

  @override
  void dispose() => _interpreter?.close();
}
