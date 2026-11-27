import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../hotspots/zones.dart';
import '../models/scan.dart';
import '../theme.dart';
import '../widgets/base_map.dart';
import '../widgets/glass_panel.dart';
import 'home_screen.dart' show shortClassName;

/// Status colours that read well on dark glass.
const statusColorsDark = {
  ScanStatus.reported: Color(0xFFFF7A6B),
  ScanStatus.assigned: Color(0xFFF2C14E),
  ScanStatus.cleaned: Color(0xFF6FD39B),
  ScanStatus.verified: Color(0xFF8DB8F2),
};

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

    return ColoredBox(
      color: AedexDark.ground,
      child: Stack(
        children: [
          Positioned.fill(
            child: BaseMap(
              controller: _controller,
              dark: true,
              points: [for (final z in zones) z.center],
              topPadding: 100,
              bottomPadding: 250,
              layers: [
                if (_heat)
                  CircleLayer(
                    circles: [
                      // Three soft rings per zone look like a glow.
                      for (final z in zones)
                        for (final ring in const [1.0, 0.66, 0.36])
                          CircleMarker(
                            point: z.center,
                            radius: _heatRadius(z) * ring,
                            useRadiusInMeter: true,
                            color: _heatColor(z).withValues(alpha: 0.22),
                            borderStrokeWidth: 0,
                          ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    for (var i = 0; i < zones.length; i++)
                      Marker(
                        point: zones[i].center,
                        width: 44,
                        height: 44,
                        child: Semantics(
                          button: true,
                          label:
                              '${zones[i].name}, ${zones[i].waiting} containers to clean',
                          child: GestureDetector(
                            onTap: () => setState(() => _selected = i),
                            child: _ZoneBadge(
                              letter: zones[i].name.replaceFirst('Zone ', ''),
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
            left: 12,
            right: 12,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GlassPanel(
                      dark: true,
                      borderRadius: 20,
                      padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.scans.length} ${widget.scans.length == 1 ? 'scan' : 'scans'} · '
                            '${zones.length} ${zones.length == 1 ? 'zone' : 'zones'}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AedexDark.muted,
                            ),
                          ),
                          Text(
                            'Hotspots',
                            style: aedexHeading(
                              context,
                              const TextStyle(
                                fontSize: 22,
                                height: 1.15,
                                color: AedexDark.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    GlassPanel(
                      dark: true,
                      borderRadius: 20,
                      padding: const EdgeInsets.only(left: 12, right: 0),
                      child: Row(
                        children: [
                          const Text(
                            'Heat',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AedexDark.text,
                            ),
                          ),
                          Switch(
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            value: _heat,
                            activeTrackColor: AedexColors.butter,
                            activeThumbColor: AedexColors.ink,
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
                padding: const EdgeInsets.only(bottom: 62),
                child: zones.isEmpty
                    ? const GlassPanel(
                        dark: true,
                        margin: EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Text(
                          'No hotspots yet. They appear when scans are saved '
                          'close together.',
                          style: TextStyle(color: AedexDark.muted),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const GlassPanel(
                            dark: true,
                            borderRadius: 18,
                            margin: EdgeInsets.fromLTRB(12, 0, 12, 8),
                            padding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Clean these first',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AedexDark.text,
                                  ),
                                ),
                                Spacer(),
                                Text(
                                  'Areas, never single homes',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AedexDark.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _ZoneCards(
                            zones: zones,
                            selected: _selected,
                            onSelect: (i) {
                              setState(() => _selected = i);
                              _controller.move(zones[i].center, 17);
                            },
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 80 m for a few containers, growing slowly to at most 260 m.
  double _heatRadius(Zone z) =>
      math.min(260, 80 + 30 * math.sqrt(math.max(z.waiting, z.containers)));

  Color _heatColor(Zone z) => switch (z.risk) {
    RiskLevel.high => const Color(0xFFFF5C48),
    RiskLevel.some => const Color(0xFFF2C14E),
    RiskLevel.clear => const Color(0xFF6FD39B),
  };
}

class _ZoneBadge extends StatelessWidget {
  const _ZoneBadge({required this.letter, required this.selected});

  final String letter;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x47FFFFFF), Color(0x1AFFFFFF)],
        ),
        color: AedexDark.glass,
        border: Border.all(
          color: selected ? Colors.white : const Color(0x5CFFFFFF),
          width: selected ? 2.5 : 1.5,
        ),
        boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 14)],
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
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
    // Cards fit narrow phones and leave a peek of the next one.
    final cardWidth = (MediaQuery.sizeOf(context).width - 56).clamp(
      200.0,
      270.0,
    );
    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: zones.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) => SizedBox(
          width: cardWidth,
          child: GestureDetector(
            onTap: () => onSelect(i),
            child: _ZoneCard(zone: zones[i], selected: i == selected),
          ),
        ),
      ),
    );
  }
}

class _ZoneCard extends StatelessWidget {
  const _ZoneCard({required this.zone, required this.selected});

  final Zone zone;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final (tag, tagColor) = switch (zone.risk) {
      RiskLevel.high => ('HIGH RISK', const Color(0xFFFFA398)),
      RiskLevel.some => ('WATCH', const Color(0xFFF2C14E)),
      RiskLevel.clear => ('ALL CLEAN', const Color(0xFF9BE3B8)),
    };
    final parts = [
      for (final st in ScanStatus.values)
        if (zone.countWithStatus(st) > 0) (st, zone.countWithStatus(st)),
    ];
    final top = zone.topClasses
        .take(2)
        .map((e) => shortClassName(e.key).toLowerCase())
        .join(' and ');

    return GlassPanel(
      dark: true,
      borderRadius: 22,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
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
                      tag,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: tagColor,
                      ),
                    ),
                    Text(
                      zone.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AedexDark.text,
                        decoration: selected ? TextDecoration.underline : null,
                        decorationColor: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${zone.waiting}',
                    style: aedexHeading(
                      context,
                      const TextStyle(
                        fontSize: 26,
                        height: 1,
                        color: AedexDark.text,
                      ),
                    ),
                  ),
                  const Text(
                    'to clean',
                    style: TextStyle(fontSize: 10, color: AedexDark.muted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // How far along the clean-up is: one coloured piece per status.
          Semantics(
            label: [for (final p in parts) '${p.$2} ${p.$1.name}'].join(', '),
            excludeSemantics: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                height: 7,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var k = 0; k < parts.length; k++) ...[
                      if (k > 0) const SizedBox(width: 2),
                      Expanded(
                        flex: parts[k].$2,
                        child: ColoredBox(
                          color: statusColorsDark[parts[k].$1]!,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '${zone.scans.length} ${zone.scans.length == 1 ? 'scan' : 'scans'} · '
            '${[for (final p in parts) '${p.$2} ${p.$1.name}'].join(', ')}'
            '${top.isEmpty ? '' : ' · mostly $top'}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AedexDark.muted),
          ),
        ],
      ),
    );
  }
}
