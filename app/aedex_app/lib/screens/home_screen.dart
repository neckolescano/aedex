import 'package:flutter/material.dart';

import '../hotspots/zones.dart';
import '../models/scan.dart';
import '../theme.dart';
import '../widgets/glass_background.dart';
import '../widgets/glass_controls.dart';
import '../widgets/glass_panel.dart';
import '../widgets/scan_card.dart';
import '../widgets/scan_pin.dart';

/// Short class names for tight spaces: "Coconut-Exocarp" -> "Coconut".
String shortClassName(String name) => name.split('-').first;

/// Overview of all saved scans: progress, where to clean first, latest scans.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.scans,
    required this.onOpenScan,
    required this.onOpenHotspots,
    required this.onShowOnMap,
  });

  /// All saved scans, newest first.
  final List<Scan> scans;
  final VoidCallback onOpenScan;
  final VoidCallback onOpenHotspots;
  final ValueChanged<String> onShowOnMap;

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 80),
          children: [
            _Header(scans: scans),
            const SizedBox(height: 10),
            if (scans.isEmpty) _empty() else ..._summary(),
          ],
        ),
      ),
    );
  }

  Widget _empty() => GlassPanel(
    borderRadius: 24,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'No scans yet',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Scan a yard, a canal or a vacant lot. Every scan becomes a pin on '
          'the map, and places with many containers become hotspots.',
          style: TextStyle(height: 1.45, color: Color(0xFF2E3833)),
        ),
        const SizedBox(height: 16),
        TintButton(
          label: 'Make the first scan',
          icon: Icons.photo_camera_outlined,
          onPressed: onOpenScan,
        ),
      ],
    ),
  );

  List<Widget> _summary() {
    final done = scans
        .where(
          (s) =>
              s.status == ScanStatus.cleaned || s.status == ScanStatus.verified,
        )
        .length;
    final reported = scans.where((s) => s.status == ScanStatus.reported).length;
    final assigned = scans.where((s) => s.status == ScanStatus.assigned).length;
    final zones = findZones(scans);
    final first = zones.isNotEmpty && zones.first.waiting > 0
        ? zones.first
        : null;

    return [
      _ProgressCard(
        done: done,
        total: scans.length,
        reported: reported,
        assigned: assigned,
      ),
      if (first != null) ...[
        const SizedBox(height: 10),
        _CleanFirstCard(zone: first, onOpenHotspots: onOpenHotspots),
      ],
      const SizedBox(height: 10),
      _LatestScans(scans: scans.take(3).toList(), onShowOnMap: onShowOnMap),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.scans});

  final List<Scan> scans;

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    String title;
    if (scans.isEmpty) {
      title = loc.formatMediumDate(DateTime.now());
    } else {
      final newest = scans.first.time.toLocal();
      final oldest = scans.last.time.toLocal();
      title = DateUtils.isSameDay(newest, oldest)
          ? loc.formatShortMonthDay(newest)
          : '${loc.formatShortMonthDay(oldest)} – ${loc.formatShortMonthDay(newest)}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Barangay overview',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E3A2D),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.done,
    required this.total,
    required this.reported,
    required this.assigned,
  });

  final int done;
  final int total;
  final int reported;
  final int assigned;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: 24,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Semantics(
            label: '$done of $total spots cleaned or verified',
            excludeSemantics: true,
            child: SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: total == 0 ? 0 : done / total,
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    color: AedexColors.clear,
                    backgroundColor: const Color(0x1F14402F),
                  ),
                  Center(
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xCCFFFFFF),
                        boxShadow: [
                          BoxShadow(color: Color(0x1F102219), blurRadius: 8),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text.rich(
                        TextSpan(
                          text: '$done',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                          children: [
                            TextSpan(
                              text: '/$total',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AedexColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$done ${done == 1 ? 'spot' : 'spots'} cleaned so far',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reported + assigned == 0
                      ? 'Nothing is waiting for a clean-up team.'
                      : '$reported reported and $assigned assigned still '
                            'need a clean-up team.',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Color(0xFF2E3833),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CleanFirstCard extends StatelessWidget {
  const _CleanFirstCard({required this.zone, required this.onOpenHotspots});

  final Zone zone;
  final VoidCallback onOpenHotspots;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: 24,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'CLEAN FIRST',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Color(0xFF9E2A1E),
                  ),
                ),
              ),
              DecoratedBox(
                decoration: frostDecoration(radius: 12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: Text(
                    '${zone.scans.length} ${zone.scans.length == 1 ? 'scan' : 'scans'}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            zone.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${zone.waiting}',
                style: const TextStyle(
                  fontSize: 34,
                  height: 0.95,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFB3301F),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'containers waiting\nto be cleaned',
                style: TextStyle(fontSize: 12, color: Color(0xFF2E3833)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in zone.topClasses.take(4))
                DecoratedBox(
                  decoration: frostDecoration(radius: 14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Text(
                      '${shortClassName(e.key)} ${e.value}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TintButton(
            label: 'See all hotspots',
            icon: Icons.arrow_forward,
            onPressed: onOpenHotspots,
            height: 42,
          ),
        ],
      ),
    );
  }
}

class _LatestScans extends StatelessWidget {
  const _LatestScans({required this.scans, required this.onShowOnMap});

  final List<Scan> scans;
  final ValueChanged<String> onShowOnMap;

  String _capitalize(String s) => s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: 24,
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Latest scans',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
          for (final s in scans) ...[
            const Divider(height: 1, color: Color(0xCCFFFFFF)),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onShowOnMap(s.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    CountBadge(
                      count: s.totalContainers,
                      color: AedexColors.forRisk(s.risk),
                      textColor: AedexColors.onRisk(s.risk),
                      size: 34,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.counts.isEmpty
                                ? '${scanLabel(s)} · clear'
                                : '${scanLabel(s)} · '
                                      '${s.counts.keys.map(shortClassName).join(', ')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${formatScanTime(s.time)} · ${_capitalize(s.status.name)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF3E4943),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AedexColors.muted),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
