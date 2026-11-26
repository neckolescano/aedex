import 'package:flutter/material.dart';

import '../hotspots/zones.dart';
import '../models/scan.dart';
import '../theme.dart';
import '../widgets/glass_background.dart';
import '../widgets/glass_panel.dart';
import '../widgets/scan_card.dart';
import '../widgets/scan_pin.dart';

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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aedex',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AedexColors.brand,
                    ),
                  ),
                  Text(
                    'Barangay overview',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            if (scans.isEmpty) _empty() else ..._summary(),
          ],
        ),
      ),
    );
  }

  Widget _empty() => GlassPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'No scans yet',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Scan a yard, a canal or a vacant lot. Every scan becomes a pin on '
          'the map, and places with many containers become hotspots.',
          style: TextStyle(height: 1.4),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onOpenScan,
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Make the first scan'),
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
      GlassPanel(
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              height: 92,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: done / scans.length,
                    strokeWidth: 10,
                    color: AedexColors.clear,
                    backgroundColor: const Color(0x2914402F),
                  ),
                  Center(
                    child: Text(
                      '$done/${scans.length}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$done ${done == 1 ? 'spot' : 'spots'} cleaned so far',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reported + assigned == 0
                        ? 'Nothing is waiting for a clean-up team.'
                        : '$reported reported and $assigned assigned still '
                              'need a clean-up team.',
                    style: const TextStyle(color: AedexColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (first != null)
        GlassPanel(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CLEAN FIRST',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF9E2A1E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                first.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${first.waiting} containers waiting · ${first.scans.length} '
                '${first.scans.length == 1 ? 'scan' : 'scans'}',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in first.topClasses.take(4))
                    Chip(
                      label: Text('${e.key.replaceAll('-', ' ')} ${e.value}'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onOpenHotspots,
                  child: const Text('See all hotspots'),
                ),
              ),
            ],
          ),
        ),
      GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Latest scans',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            for (final s in scans.take(3))
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => onShowOnMap(s.id),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AedexColors.forRisk(s.risk),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${s.totalContainers}',
                    style: TextStyle(
                      color: AedexColors.onRisk(s.risk),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(
                  scanLabel(s),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('${formatScanTime(s.time)} · ${s.status.name}'),
                trailing: const Icon(Icons.chevron_right),
              ),
          ],
        ),
      ),
    ];
  }
}
