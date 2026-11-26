import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../data/location.dart';
import '../data/scan_builder.dart';
import '../detection/detection.dart';
import '../detection/detector.dart';
import '../models/scan.dart';
import '../theme.dart';
import '../widgets/glass_background.dart';
import '../widgets/glass_panel.dart';

/// Take or pick a photo, let the model find containers, save it as a scan.
class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    required this.detector,
    required this.onSave,
    this.locate = currentPosition,
    this.pickPhoto,
  });

  final ContainerDetector detector;

  /// Called with the finished scan record.
  final Future<void> Function(Scan scan) onSave;

  /// Where the phone is. Replaceable in tests.
  final Future<LatLng> Function() locate;

  /// Photo source. Null = the phone's camera or gallery (image_picker).
  final Future<Uint8List?> Function(ImageSource source)? pickPhoto;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

enum _Step { start, working, result, saving }

class _ScanScreenState extends State<ScanScreen> {
  _Step _step = _Step.start;
  Uint8List? _photo;
  DetectionResult? _result;
  String? _error;
  bool _privateHome = true;

  Future<Uint8List?> _pick(ImageSource source) async {
    if (widget.pickPhoto != null) return widget.pickPhoto!(source);
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
    );
    return file?.readAsBytes();
  }

  Future<void> _scan(ImageSource source) async {
    setState(() => _error = null);
    final bytes = await _pick(source);
    if (bytes == null) return;
    setState(() {
      _photo = bytes;
      _step = _Step.working;
    });
    try {
      final result = await widget.detector.detect(bytes);
      setState(() {
        _result = result;
        _step = _Step.result;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _step = _Step.start;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _step = _Step.saving);
    try {
      final position = await widget.locate();
      final scan = buildScan(
        detections: _result!.detections,
        position: position,
        privateHome: _privateHome,
        now: DateTime.now(),
      );
      await widget.onSave(scan);
      if (mounted) _reset();
    } catch (e) {
      setState(() {
        _error = '$e';
        _step = _Step.result;
      });
    }
  }

  void _reset() => setState(() {
    _step = _Step.start;
    _photo = null;
    _result = null;
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          child: switch (_step) {
            _Step.start => _buildStart(),
            _Step.working => _buildWorking(),
            _Step.result || _Step.saving => _buildResult(),
          },
        ),
      ),
    );
  }

  Widget _errorBox() => _error == null
      ? const SizedBox.shrink()
      : GlassPanel(
          margin: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: AedexColors.high),
              const SizedBox(width: 10),
              Expanded(child: Text(_error!)),
            ],
          ),
        );

  Widget _buildStart() {
    final supported = widget.detector.isSupported;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Scan a spot',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Take a clear photo of the area. The app finds containers that can '
          'hold rainwater and puts the result on the map. The photo itself is '
          'not saved.',
          style: TextStyle(color: AedexColors.muted, height: 1.4),
        ),
        const Spacer(),
        if (!supported)
          const GlassPanel(
            child: Text(
              'Scanning runs in the phone app. In the browser you can look at '
              'the map, hotspots and filters.',
            ),
          )
        else ...[
          SizedBox(
            height: 64,
            child: FilledButton.icon(
              onPressed: () => _scan(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Take a photo', style: TextStyle(fontSize: 17)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () => _scan(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose from gallery'),
            ),
          ),
        ],
        _errorBox(),
      ],
    );
  }

  Widget _buildWorking() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      if (_photo != null)
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.memory(_photo!, height: 320, fit: BoxFit.cover),
        ),
      const SizedBox(height: 20),
      const CircularProgressIndicator(),
      const SizedBox(height: 12),
      const Text('Looking for containers…'),
    ],
  );

  Widget _buildResult() {
    final r = _result!;
    final counts = countByLabel(r.detections);
    final total = r.detections.length;
    final risk = riskFor(total);
    final saving = _step == _Step.saving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: r.photoWidth / r.photoHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(_photo!, fit: BoxFit.fill),
                    CustomPaint(
                      painter: BoxPainter(
                        detections: r.detections,
                        photoWidth: r.photoWidth,
                        photoHeight: r.photoHeight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        GlassPanel(
          margin: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AedexColors.forRisk(risk),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$total',
                      style: TextStyle(
                        color: AedexColors.onRisk(risk),
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      total == 0
                          ? 'No containers found'
                          : '$total possible breeding ${total == 1 ? 'site' : 'sites'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              if (counts.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final e in counts.entries)
                      Chip(
                        label: Text(
                          '${e.key.replaceAll('-', ' ')} × ${e.value}',
                        ),
                      ),
                  ],
                ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _privateHome,
                onChanged: saving
                    ? null
                    : (v) => setState(() => _privateHome = v),
                title: const Text(
                  'Private home',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  _privateHome
                      ? 'Saved at street level (about 100 m), never the exact house.'
                      : 'Public place: saved at the exact spot.',
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: saving ? null : _reset,
                      child: const Text('Retake'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: saving ? null : _save,
                      child: Text(saving ? 'Saving…' : 'Save to map'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _errorBox(),
      ],
    );
  }
}

/// Draws the model's boxes and class names over the photo.
class BoxPainter extends CustomPainter {
  BoxPainter({
    required this.detections,
    required this.photoWidth,
    required this.photoHeight,
  });

  final List<Detection> detections;
  final int photoWidth;
  final int photoHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / photoWidth;
    final sy = size.height / photoHeight;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFFF2C14E);
    for (final d in detections) {
      final r = Rect.fromLTRB(
        d.box.left * sx,
        d.box.top * sy,
        d.box.right * sx,
        d.box.bottom * sy,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(6)),
        stroke,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: ' ${d.label} ${(d.score * 100).round()}% ',
          style: const TextStyle(
            color: Color(0xFF3A2A00),
            backgroundColor: Color(0xFFF2C14E),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(r.left, (r.top - tp.height).clamp(0, size.height)),
      );
    }
  }

  @override
  bool shouldRepaint(BoxPainter old) =>
      old.detections != detections ||
      old.photoWidth != photoWidth ||
      old.photoHeight != photoHeight;
}
