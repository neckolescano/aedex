import 'package:latlong2/latlong.dart';

import '../detection/detection.dart';
import '../models/scan.dart';

/// Rounds a private home's position to about 100 m (3 decimal places),
/// so the saved scan says "this street", never "this house".
LatLng roundToStreetLevel(LatLng p) => LatLng(
  (p.latitude * 1000).roundToDouble() / 1000,
  (p.longitude * 1000).roundToDouble() / 1000,
);

/// Turns the model's boxes + where and when into a scan record
/// (the contract in docs/tasks/member-3-hotspot-map.md).
/// The photo itself is NOT kept: only counts, place and time.
Scan buildScan({
  required List<Detection> detections,
  required LatLng position,
  required bool privateHome,
  required DateTime now,
}) {
  return Scan(
    id: 'scan-${now.millisecondsSinceEpoch}',
    time: now,
    location: privateHome ? roundToStreetLevel(position) : position,
    precision: privateHome ? LocationPrecision.street : LocationPrecision.exact,
    counts: countByLabel(detections),
    status: ScanStatus.reported,
  );
}
