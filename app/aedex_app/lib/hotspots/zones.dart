import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/scan.dart';

/// A hotspot: scans that sit in the same ~150 m square.
class Zone {
  Zone({required this.name, required this.scans});

  final String name;
  final List<Scan> scans;

  LatLng get center {
    final lat = scans.fold(0.0, (s, x) => s + x.location.latitude);
    final lng = scans.fold(0.0, (s, x) => s + x.location.longitude);
    return LatLng(lat / scans.length, lng / scans.length);
  }

  int get containers => scans.fold(0, (s, x) => s + x.totalContainers);

  /// Containers still waiting: reported or assigned, not yet cleaned.
  int get waiting => scans
      .where(
        (s) =>
            s.status == ScanStatus.reported || s.status == ScanStatus.assigned,
      )
      .fold(0, (s, x) => s + x.totalContainers);

  /// Risk colour from what is still waiting.
  RiskLevel get risk => riskFor(waiting);

  int countWithStatus(ScanStatus status) =>
      scans.where((s) => s.status == status).length;

  /// Most-found class names, biggest first, e.g. [Bottle, Tire].
  List<MapEntry<String, int>> get topClasses {
    final totals = <String, int>{};
    for (final s in scans) {
      s.counts.forEach((k, v) => totals[k] = (totals[k] ?? 0) + v);
    }
    return totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }
}

/// Groups scans into squares of [cellMeters] and ranks them by containers
/// still waiting, so the list reads "clean these first".
///
/// Why squares: simple, fast, and the same scans always land in the same
/// zone. The cost: two scans 10 m apart can fall on either side of a line.
List<Zone> findZones(List<Scan> scans, {double cellMeters = 150}) {
  if (scans.isEmpty) return [];
  final latStep = cellMeters / 111320; // metres per degree of latitude
  final midLat = scans.first.location.latitude * math.pi / 180;
  final lngStep = cellMeters / (111320 * math.cos(midLat));

  final cells = <String, List<Scan>>{};
  for (final s in scans) {
    final key =
        '${(s.location.latitude / latStep).floor()}:'
        '${(s.location.longitude / lngStep).floor()}';
    cells.putIfAbsent(key, () => []).add(s);
  }

  final groups = cells.values.toList()
    ..sort((a, b) {
      int w(List<Scan> g) => Zone(name: '', scans: g).waiting;
      int c(List<Scan> g) => Zone(name: '', scans: g).containers;
      final byWaiting = w(b).compareTo(w(a));
      return byWaiting != 0 ? byWaiting : c(b).compareTo(c(a));
    });

  return [
    for (var i = 0; i < groups.length; i++)
      Zone(name: 'Zone ${_letter(i)}', scans: groups[i]),
  ];
}

String _letter(int i) => i < 26 ? String.fromCharCode(65 + i) : '${i + 1}';
