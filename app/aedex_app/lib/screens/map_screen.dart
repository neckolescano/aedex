import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/scan_repository.dart';
import '../models/scan.dart';
import '../theme.dart';
import '../widgets/glass_panel.dart';
import '../widgets/scan_card.dart';
import '../widgets/scan_pin.dart';

/// Phase 1: one pin per scan, coloured by risk; tap a pin for its card.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.repository});

  /// Leave empty to use the bundled sample scans.
  final ScanRepository? repository;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final Future<List<Scan>> _scans;
  Scan? _selected;

  @override
  void initState() {
    super.initState();
    _scans = (widget.repository ?? ScanRepository()).loadScans();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Scan>>(
        future: _scans,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Could not load scans: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildMap(snapshot.data!);
        },
      ),
    );
  }

  Widget _buildMap(List<Scan> scans) {
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: _centerOf(scans),
            initialZoom: 16,
            // Zoom so every scan fits, leaving room for the card at the bottom.
            initialCameraFit: scans.length < 2
                ? null
                : CameraFit.coordinates(
                    coordinates: [for (final s in scans) s.location],
                    padding: const EdgeInsets.fromLTRB(48, 64, 48, 200),
                    maxZoom: 17,
                  ),
            // Tapping empty map closes the card.
            onTap: (_, _) => setState(() => _selected = null),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'ph.aedex.aedex_app',
            ),
            // Street-level scans get a soft circle: "somewhere around here",
            // so nobody can point at one house.
            CircleLayer(
              circles: [
                for (final s in scans)
                  if (s.precision == LocationPrecision.street)
                    CircleMarker(
                      point: s.location,
                      radius: 60,
                      useRadiusInMeter: true,
                      color: AedexColors.forRisk(s.risk)
                          .withValues(alpha: 0.15),
                      borderColor: AedexColors.forRisk(s.risk),
                      borderStrokeWidth: 1.5,
                    ),
              ],
            ),
            MarkerLayer(
              markers: [
                for (final s in scans)
                  Marker(
                    point: s.location,
                    width: s.risk == RiskLevel.high ? 44 : 40,
                    height: s.risk == RiskLevel.high ? 44 : 40,
                    child: ScanPin(
                      scan: s,
                      selected: identical(s, _selected),
                      onTap: () => setState(() => _selected = s),
                    ),
                  ),
              ],
            ),
            const SimpleAttributionWidget(
              source: Text('OpenStreetMap contributors'),
            ),
          ],
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            top: false,
            child: _selected == null
                ? const _Legend()
                : ScanCard(
                    scan: _selected!,
                    onClose: () => setState(() => _selected = null),
                  ),
          ),
        ),
      ],
    );
  }

  /// Middle of all scans, so the map opens where the data is.
  LatLng _centerOf(List<Scan> scans) {
    if (scans.isEmpty) return const LatLng(14.5995, 120.9842);
    final lat = scans.map((s) => s.location.latitude).reduce((a, b) => a + b);
    final lng = scans.map((s) => s.location.longitude).reduce((a, b) => a + b);
    return LatLng(lat / scans.length, lng / scans.length);
  }
}

/// Shown when no pin is selected: what the colours mean.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );

    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Containers found',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              dot(AedexColors.clear, 'None'),
              dot(AedexColors.some, '1 to 3'),
              dot(AedexColors.high, '4 or more'),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Tap a pin to see what was found there.',
            style: TextStyle(fontSize: 13, color: AedexColors.muted),
          ),
        ],
      ),
    );
  }
}
