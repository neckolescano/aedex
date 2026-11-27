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
import '../widgets/glass_controls.dart';
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
    return switch (_step) {
      _Step.start => GlassBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 72),
            child: _buildStart(),
          ),
        ),
      ),
      _Step.working || _Step.result || _Step.saving => _buildPhotoView(),
    };
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
        Text(
          'Scan a spot',
          style: aedexHeading(context, const TextStyle(fontSize: 26)),
        ),
        const SizedBox(height: 6),
        const Text(
          'Take a clear photo of the area. The app finds containers that can '
          'hold rainwater and puts the result on the map. The photo itself is '
          'not saved.',
          style: TextStyle(fontSize: 13, color: AedexColors.muted, height: 1.4),
        ),
        const Spacer(),
        GlassPanel(
          borderRadius: 24,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.tips_and_updates_outlined,
                    color: AedexColors.brand,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Stand back so the whole yard or canal fits. '
                      'Keep faces and house numbers out of the photo.',
                      style: TextStyle(fontSize: 12, height: 1.35),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!supported)
                const Text(
                  'Scanning runs in the phone app. In the browser you can look '
                  'at the map, hotspots and filters.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                )
              else ...[
                TintButton(
                  label: 'Take a photo',
                  icon: Icons.photo_camera_outlined,
                  height: 50,
                  onPressed: () => _scan(ImageSource.camera),
                ),
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: frostDecoration(radius: 22),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => _scan(ImageSource.gallery),
                      child: const SizedBox(
                        height: 44,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              color: AedexColors.brand,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Choose from gallery',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AedexColors.brand,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        _errorBox(),
      ],
    );
  }

  /// The photo fills the screen; the result floats over it on glass.
  Widget _buildPhotoView() {
    final r = _result;
    final working = _step == _Step.working;
    final saving = _step == _Step.saving;

    return ColoredBox(
      color: AedexDark.ground,
      child: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: r == null
                  ? Image.memory(_photo!, fit: BoxFit.contain)
                  : AspectRatio(
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
          Positioned(
            left: 12,
            right: 12,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    GlassIconButton(
                      icon: Icons.close,
                      tooltip: 'Retake',
                      dark: true,
                      onPressed: working || saving ? null : _reset,
                    ),
                    const Spacer(),
                    if (!working)
                      _PrecisionChip(
                        privateHome: _privateHome,
                        onTap: saving
                            ? null
                            : () =>
                                  setState(() => _privateHome = !_privateHome),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 70),
                child: working
                    ? const GlassPanel(
                        dark: true,
                        borderRadius: 26,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 14),
                            Text(
                              'Looking for containers…',
                              style: TextStyle(
                                color: AedexDark.text,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [_resultSheet(r!, saving), _errorBox()],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultSheet(DetectionResult r, bool saving) {
    final counts = countByLabel(r.detections);
    final total = r.detections.length;
    final risk = riskFor(total);
    final (tag, tagColor) = switch (risk) {
      RiskLevel.high => ('HIGH RISK', const Color(0xFF9E2A1E)),
      RiskLevel.some => ('SOME RISK', const Color(0xFF7A5A00)),
      RiskLevel.clear => ('ALL CLEAR', AedexColors.brand),
    };

    return GlassPanel(
      borderRadius: 24,
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tag,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: tagColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            total == 0
                ? 'No containers found'
                : '$total possible breeding ${total == 1 ? 'site' : 'sites'}',
            style: aedexHeading(context, const TextStyle(fontSize: 20)),
          ),
          if (counts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in counts.entries)
                  DecoratedBox(
                    decoration: frostDecoration(radius: 14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      child: Text(
                        '${e.key.replaceAll('-', ' ')} × ${e.value}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _privateHome ? Icons.shield_outlined : Icons.place_outlined,
                size: 18,
                color: AedexColors.brand,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _privateHome
                      ? 'Private home: saved at street level (about 100 m), '
                            'never the exact house.'
                      : 'Public place: saved at the exact spot.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AedexColors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    backgroundColor: const Color(0x99FFFFFF),
                    side: const BorderSide(color: Color(0xE6FFFFFF)),
                  ),
                  onPressed: saving ? null : _reset,
                  child: const Text('Retake'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TintButton(
                  label: saving ? 'Saving…' : 'Save to map',
                  icon: Icons.add_location_alt_outlined,
                  height: 44,
                  onPressed: saving ? null : _save,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Street level" (private home) or "Exact spot" (public place). Tap to switch.
class _PrecisionChip extends StatelessWidget {
  const _PrecisionChip({required this.privateHome, required this.onTap});

  final bool privateHome;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: privateHome
          ? 'Street level, private home. Tap for exact spot.'
          : 'Exact spot, public place. Tap for street level.',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: frostDecoration(radius: 24, dark: true),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    privateHome ? Icons.shield_outlined : Icons.place_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    privateHome ? 'Street level' : 'Exact spot',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.swap_horiz, color: Colors.white70, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
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
    // A blurred wide line under a sharp thin one looks like a glow.
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = const Color(0x99F2C14E)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = const Color(0xFFFFD66B);
    final labelFill = Paint()..color = const Color(0xB30B1330);
    final labelEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x66FFFFFF);
    for (final d in detections) {
      final r = Rect.fromLTRB(
        d.box.left * sx,
        d.box.top * sy,
        d.box.right * sx,
        d.box.bottom * sy,
      );
      final box = RRect.fromRectAndRadius(r, const Radius.circular(10));
      canvas.drawRRect(box, glow);
      canvas.drawRRect(box, stroke);

      // A small smoky glass label: "Tire 94%".
      final tp = TextPainter(
        text: TextSpan(
          text: '${d.label.replaceAll('-', ' ')} ${(d.score * 100).round()}%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final w = tp.width + 16, h = tp.height + 8;
      final top = (r.top - h - 4).clamp(0.0, size.height - h);
      final left = r.left.clamp(0.0, (size.width - w).clamp(0.0, size.width));
      final pill = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, w, h),
        Radius.circular(h / 2),
      );
      canvas.drawRRect(pill, labelFill);
      canvas.drawRRect(pill, labelEdge);
      tp.paint(canvas, Offset(left + 8, top + 4));
    }
  }

  @override
  bool shouldRepaint(BoxPainter old) =>
      old.detections != detections ||
      old.photoWidth != photoWidth ||
      old.photoHeight != photoHeight;
}
