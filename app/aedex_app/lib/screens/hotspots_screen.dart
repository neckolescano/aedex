import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../hotspots/zones.dart';
import '../models/scan.dart';
import '../theme.dart';
import '../widgets/base_map.dart';
import '../widgets/glass_panel.dart';

/// Where many containers sit close together, ranked "clean these first".
class HotspotsScreen extends StatefulWidget {
  const HotspotsScreen({super.key, required this.scans});

  final List<Scan> scans;

  @override
  State<HotspotsScreen> createState() => _HotspotsScreenState();
}

class _HotspotsScreenState extends State<HotspotsScreen> {
  final _controller = MapController();
  bool _heat = true;
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final zones = findZones(widget.scans);
    if (_selected >= zones.length) _selected = 0;

    return Stack(
      children: [
        Positioned.fill(
          child: BaseMap(
            controller: _controller,
            points: [for (final z in zones) z.center],
            bottomPadding: 300,
            layers: [
              if (_heat)
                CircleLayer(
                  circles: [
                    for (final z in zones) ...[
                      // Outer glow: bigger when more containers wait there.
                      CircleMarker(
                        point: z.center,
                        radius: _heatRadius(z),
                        useRadiusInMeter: true,
                        color: AedexColors.forRisk(z.risk)
                            .withValues(alpha: 0.22),
                        borderStrokeWidth: 0,
                      ),
                      CircleMarker(
                        point: z.center,
                        radius: _heatRadius(z) * 0.5,
                        useRadiusInMeter: true,
                        color: AedexColors.forRisk(z.risk)
                            .withValues(alpha: 0.35),
                        borderStrokeWidth: 0,
                      ),
                    ],
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (var i = 0; i < zones.length; i++)
                    Marker(
                      point: zones[i].center,
                      width: 48,
                      height: 48,
                      child: Semantics(
                        button: true,
                        label: '${zones[i].name}, ${zones[i].waiting} to clean',
                        child: GestureDetector(
                          onTap: () => setState(() => _selected = i),
                          child: _ZoneBadge(
                            zone: zones[i],
                            selected: i == _selected,
                          ),
                        ),
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
              child: Row(
                children: [
                  const Expanded(
                    child: GlassPanel(
                      borderRadius: 26,
                      padding: EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      child: Text(
                        'Hotspots',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GlassPanel(
                    borderRadius: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        const Text(
                          'Heat',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Switch(
                          value: _heat,
                          onChanged: (v) => setState(() => _heat = v),
                        ),
                      ],
                    ),
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
              padding: const EdgeInsets.only(bottom: 84),
              child: zones.isEmpty
                  ? const GlassPanel(
                      margin: EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Text(
                        'No hotspots yet. They appear when scans are saved '
                        'close together.',
                        style: TextStyle(color: AedexColors.muted),
                      ),
                    )
                  : _ZoneCards(
                      zones: zones,
                      selected: _selected,
                      onSelect: (i) {
                        setState(() => _selected = i);
                        _controller.move(zones[i].center, 17);
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }

  /// 80 m for one container, growing slowly to at most 250 m.
  double _heatRadius(Zone z) =>
      math.min(250, 80 + 30 * math.sqrt(math.max(z.waiting, z.containers)));
}

class _ZoneBadge extends StatelessWidget {
  const _ZoneBadge({required this.zone, required this.selected});

  final Zone zone;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.85),
        border: Border.all(
          color: selected ? AedexColors.brand : AedexColors.forRisk(zone.risk),
          width: selected ? 4 : 3,
        ),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 8)],
      ),
      alignment: Alignment.center,
      child: Text(
        zone.name.replaceFirst('Zone ', ''),
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
      ),
    );
  }
}

class _ZoneCards extends StatelessWidget {
  const _ZoneCards({
    required this.zones,
    required this.selected,
    required this.onSelect,
  });

  final List<Zone> zones;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 172,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: zones.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final z = zones[i];
          final top = z.topClasses.take(2).map((e) => e.key).join(' and ');
          final statusLine = [
            for (final st in ScanStatus.values)
              if (z.countWithStatus(st) > 0)
                '${z.countWithStatus(st)} ${st.name}',
          ].join(', ');
          return SizedBox(
            width: 280,
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: GlassPanel(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                i == 0 && z.waiting > 0
                                    ? 'CLEAN FIRST'
                                    : 'RANK ${i + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: i == selected
                                      ? AedexColors.brand
                                      : AedexColors.muted,
                                ),
                              ),
                              Text(
                                z.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${z.waiting}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Text(
                              'to clean',
                              style: TextStyle(
                                fontSize: 12,
                                color: AedexColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${z.scans.length} ${z.scans.length == 1 ? 'scan' : 'scans'}: $statusLine',
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (top.isNotEmpty)
                      Text(
                        'Mostly ${top.replaceAll('-', ' ')}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AedexColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
