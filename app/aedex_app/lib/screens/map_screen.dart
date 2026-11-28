import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/location.dart';
import '../filters/scan_filter.dart';
import '../models/scan.dart';
import '../theme.dart';
import '../widgets/base_map.dart';
import '../widgets/glass_controls.dart';
import '../widgets/glass_panel.dart';
import '../widgets/scan_card.dart';
import '../widgets/scan_pin.dart';
import '../widgets/patak.dart';

/// One pin per saved scan, coloured by risk; tap a pin for its card.
class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.allScans,
    required this.filter,
    required this.onFilterChanged,
    required this.onOpenFilters,
    required this.onAdvance,
    required this.focus,
    this.locate = currentPosition,
  });

  /// Every saved scan; the map shows those that pass [filter].
  final List<Scan> allScans;
  final ScanFilter filter;
  final ValueChanged<ScanFilter> onFilterChanged;
  final VoidCallback onOpenFilters;
  final ValueChanged<String> onAdvance;

  /// Set to a scan id to open its card and move the map there
  /// (used right after a new scan is saved).
  final ValueNotifier<String?> focus;

  /// Where the phone is (the locate button). Replaceable in tests.
  final Future<LatLng> Function() locate;

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
    for (final s in widget.allScans) {
      if (s.id == id && _mapReady) _controller.move(s.location, 17);
    }
    widget.focus.value = null;
  }

  Future<void> _goToMe() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final here = await widget.locate();
      if (_mapReady) _controller.move(here, 17);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  /// Status chips: "All" or exactly one status.
  void _pickStatus(ScanStatus? status) {
    widget.onFilterChanged(
      widget.filter.copyWith(
        statuses: status == null ? {...ScanStatus.values} : {status},
      ),
    );
    setState(() => _selectedId = null);
  }

  @override
  Widget build(BuildContext context) {
    final scans = widget.filter.apply(widget.allScans);
    Scan? selected;
    for (final s in scans) {
      if (s.id == _selectedId) selected = s;
    }
    final statuses = widget.filter.statuses;
    final showingAll = statuses.length == ScanStatus.values.length;

    return Stack(
      children: [
        Positioned.fill(
          child: BaseMap(
            controller: _controller,
            points: [for (final s in scans) s.location],
            onTap: () => setState(() => _selectedId = null),
            onMapReady: () => _mapReady = true,
            topPadding: 120,
            bottomPadding: 160,
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
                            .withValues(alpha: 0.16),
                        borderColor: AedexColors.forRisk(s.risk)
                            .withValues(alpha: 0.6),
                        borderStrokeWidth: 1,
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
          left: 0,
          right: 0,
          top: 0,
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: GlassPanel(
                          borderRadius: 21,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.place_outlined,
                                size: 18,
                                color: AedexColors.muted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _countText(scans.length),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Badge(
                        isLabelVisible: widget.filter.activeCount > 0,
                        label: Text('${widget.filter.activeCount}'),
                        child: GlassIconButton(
                          icon: Icons.tune,
                          tooltip: 'Filters',
                          tinted: true,
                          size: 44,
                          onPressed: widget.onOpenFilters,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 46,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    children: [
                      GlassChip(
                        label: 'All',
                        trailing: '${widget.allScans.length}',
                        selected: showingAll,
                        onTap: () => _pickStatus(null),
                      ),
                      for (final st in ScanStatus.values) ...[
                        const SizedBox(width: 6),
                        GlassChip(
                          label:
                              st.name[0].toUpperCase() + st.name.substring(1),
                          trailing:
                              '${widget.allScans.where((s) => s.status == st).length}',
                          selected:
                              !showingAll &&
                              statuses.length == 1 &&
                              statuses.contains(st),
                          onTap: () => _pickStatus(st),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            top: false,
            // The Scaffold already reports the tab bar as bottom padding
            // (extendBody), so SafeArea alone keeps the card above it.
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // The locate button rides just above the card, out of
                // the way of the bars at the top.
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 12, 8),
                  child: GlassIconButton(
                    icon: Icons.my_location,
                    tooltip: 'Show my location',
                    size: 40,
                    onPressed: _goToMe,
                  ),
                ),
                if (selected != null)
                  ScanCard(
                    scan: selected,
                    onClose: () => setState(() => _selectedId = null),
                    onAdvance: () => widget.onAdvance(selected!.id),
                    bottomMargin: 8,
                  )
                else
                  _Summary(scans: scans, totalScans: widget.allScans.length),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _countText(int shown) {
    final total = widget.allScans.length;
    if (total == 0) return 'No scans yet';
    if (shown == total) {
      return '$total ${total == 1 ? 'scan' : 'scans'} on the map';
    }
    return '$shown of $total scans shown';
  }
}

/// Shown when no pin is selected: a slim strip with the totals and what the
/// pin colours mean. It stays on screen, so it is kept small.
class _Summary extends StatelessWidget {
  const _Summary({required this.scans, required this.totalScans});

  final List<Scan> scans;
  final int totalScans;

  @override
  Widget build(BuildContext context) {
    Widget stat(String value, String label) => Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AedexColors.muted),
            ),
          ),
        ],
      ),
    );

    Widget dot(Color c, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );

    Widget divider() =>
        Container(width: 1, height: 18, color: const Color(0x291F3FBF));

    final containers = scans.fold(0, (n, s) => n + s.totalContainers);
    final high = scans.where((s) => s.risk == RiskLevel.high).length;
    // Only say something when the user has to do something.
    final hint = totalScans == 0
        ? 'Open Scan and take a photo. It appears here as a pin.'
        : scans.isEmpty
        ? 'No scans match the filters.'
        : null;

    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      borderRadius: 22,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              stat('${scans.length}', 'scans'),
              divider(),
              stat('$containers', 'containers'),
              divider(),
              stat('$high', 'high-risk'),
            ],
          ),
          const SizedBox(height: 8),
          if (hint != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Patak(pose: PatakPose.sleepy, size: 36),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    hint,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AedexColors.muted,
                    ),
                  ),
                ),
              ],
            )
          else
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                dot(AedexColors.clear, 'None'),
                dot(AedexColors.some, '1–3'),
                dot(AedexColors.high, '4+'),
                const Text(
                  'Tap a pin for details',
                  style: TextStyle(fontSize: 11, color: AedexColors.muted),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
