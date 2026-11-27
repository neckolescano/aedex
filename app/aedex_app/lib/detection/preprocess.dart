import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// The photo turned into the numbers the model reads, plus what is needed
/// to map the model's boxes back onto the original photo.
class ModelInput {
  const ModelInput({
    required this.data,
    required this.scale,
    required this.padX,
    required this.padY,
  });

  /// size x size x 3 values from 0 to 1.
  final Float32List data;

  /// original pixels * scale = model pixels.
  final double scale;

  /// Grey border added left/right and top/bottom (model pixels).
  final double padX;
  final double padY;
}

/// "Letterbox": shrink the photo so its long side is [size], keep its
/// shape, and fill the rest with grey (what YOLO saw during training).
///
/// [channelsFirst] picks the memory layout:
/// - true  -> [1, 3, size, size]: all red values, then all green, then all blue
/// - false -> [1, size, size, 3]: red, green, blue of pixel 1, then pixel 2...
/// Feeding the wrong layout does not crash; the model just sees noise.
ModelInput letterbox(img.Image photo, int size, {required bool channelsFirst}) {
  final scale =
      size / (photo.width > photo.height ? photo.width : photo.height);
  final w = (photo.width * scale).round().clamp(1, size);
  final h = (photo.height * scale).round().clamp(1, size);
  final resized = img.copyResize(
    photo,
    width: w,
    height: h,
    interpolation: img.Interpolation.linear,
  );
  final padX = (size - w) / 2;
  final padY = (size - h) / 2;
  final left = padX.floor();
  final top = padY.floor();

  const grey = 114 / 255;
  final plane = size * size;
  final data = Float32List(plane * 3)..fillRange(0, plane * 3, grey);

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = resized.getPixel(x, y);
      final max = p.maxChannelValue;
      final r = p.r / max, g = p.g / max, b = p.b / max;
      final pos = (y + top) * size + (x + left);
      if (channelsFirst) {
        data[pos] = r.toDouble();
        data[plane + pos] = g.toDouble();
        data[2 * plane + pos] = b.toDouble();
      } else {
        data[pos * 3] = r.toDouble();
        data[pos * 3 + 1] = g.toDouble();
        data[pos * 3 + 2] = b.toDouble();
      }
    }
  }
  return ModelInput(
    data: data,
    scale: scale,
    padX: left.toDouble(),
    padY: top.toDouble(),
  );
}
