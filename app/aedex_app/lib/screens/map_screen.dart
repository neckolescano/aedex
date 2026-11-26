import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../filters/scan_filter.dart';
import '../models/scan.dart';
import '../theme.dart';
import '../widgets/base_map.dart';
import '../widgets/glass_panel.dart';
import '../widgets/scan_card.dart';
import '../widgets/scan_pin.dart';

/// One pin per saved scan, coloured by risk; tap a pin for its card.
class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.scans,
    required this.filter,
    required this.totalScans,
    required this.onOpenFilters,
    required this.onAdvance,
    required this.focus,
  });

  /// Scans that pass [filter], newest first.
  final List<Scan> scans;
  final ScanFilter filter;

  /// All saved scans, before the filter (for the empty states).
  final int totalScans;
  final VoidCallback onOpenFilters;
  final ValueChanged<String> onAdvance;

  /// Set to a scan id to open its card and move the map there
  /// (used right after a new scan is saved).
  final ValueNotifier<String?> focus;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _controller = MapController();
  String? _selectedId;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    widget.focus.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.focus.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    final id = widget.focus.value;
    if (id == null) return;
    setState(() => _selectedId = id);
    for (final s in widget.scans) {
      if (s.id == id && _mapReady) _controller.move(s.location, 17);
    }
    widget.focus.value = null;
  }

  @override
  Widget build(BuildContext context) {
    final scans = widget.scans;
    Scan? selected;
    for (final s in scans) {
      if (s.id == _selectedId) selected = s;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: BaseMap(
            controller: _controller,
            points: [for (final s in scans) s.location],
            onTap: () => setState(() => _selectedId = null),
            onMapReady: () => _mapReady = true,
            layers: [
              // Street-level scans get a soft circle: "somewhere around
              // here", so nobody can point at one house.
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
                        selected: s.id == _selectedId,
                        onTap: () => setState(() => _selectedId = s.id),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _TopBar(
                shown: scans.length,
                total: widget.totalScans,
                activeFilters: widget.filter.activeCount,
                onOpenFilters: widget.onOpenFilters,
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            top: false,
            child: Padding(
              // Room for the floating tab bar.
              padding: const EdgeInsets.only(bottom: 84),
              child: selected != null
                  ? ScanCard(
                      scan: selected,
                      onClose: () => setState(() => _selectedId = null),
                      onAdvance: () => widget.onAdvance(selected!.id),
                    )
                  : _BottomHint(
                      totalScans: widget.totalScans,
                      shown: scans.length,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.shown,
    required this.total,
    required this.activeFilters,
    required this.onOpenFilters,
  });

  final int shown;
  final int total;
  final int activeFilters;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GlassPanel(
            borderRadius: 26,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Text(
              total == 0
                  ? 'No scans yet'
                  : shown == total
                  ? '$total ${total == 1 ? 'scan' : 'scans'} on the map'
                  : '$shown of $total scans shown',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AedexColors.ink,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Badge(
          isLabelVisible: activeFilters > 0,
          label: Text('$activeFilters'),
          child: Tooltip(
            message: 'Filters',
            child: SizedBox(
              width: 52,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                ),
                onPressed: onOpenFilters,
                child: const Icon(Icons.tune),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shown when no pin is selected: what the colours mean, or what to do next.
class _BottomHint extends StatelessWidget {
  const _BottomHint({required this.totalScans, required this.shown});

  final int totalScans;
  final int shown;

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

    final message = totalScans == 0
        ? 'Open the Scan tab and take a photo of a spot. Its result appears here as a pin.'
        : shown == 0
        ? 'No scans match the filters. Open Filters to show more.'
        : 'Tap a pin to see what was found there.';

    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: AedexColors.muted),
          ),
        ],
      ),
    );
  }
}
