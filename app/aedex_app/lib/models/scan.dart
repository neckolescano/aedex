import 'package:latlong2/latlong.dart';

/// Where a scan sits on the clean-up flow from the team guide.
enum ScanStatus { reported, assigned, cleaned, verified }

/// `street` = a private home, rounded to street level (never the exact house).
/// `exact` = a public place such as a vacant lot or a canal.
enum LocationPrecision { street, exact }

/// Risk from the total number of containers found (task file, Phase 1 step 4).
enum RiskLevel { clear, some, high }

/// 0 containers = clear, 1 to 3 = some, 4 or more = high.
RiskLevel riskFor(int totalContainers) {
  if (totalContainers <= 0) return RiskLevel.clear;
  if (totalContainers <= 3) return RiskLevel.some;
  return RiskLevel.high;
}

/// One scan record: the contract between the model and the app.
/// See docs/tasks/member-3-hotspot-map.md for each field.
class Scan {
  const Scan({
    required this.id,
    required this.time,
    required this.location,
    required this.precision,
    required this.counts,
    required this.status,
  });

  final String id;
  final DateTime time;
  final LatLng location;
  final LocationPrecision precision;

  /// Class name -> how many the model found. Names match CLAUDE.md exactly.
  final Map<String, int> counts;
  final ScanStatus status;

  int get totalContainers => counts.values.fold(0, (sum, n) => sum + n);

  RiskLevel get risk => riskFor(totalContainers);

  factory Scan.fromJson(Map<String, dynamic> json) {
    final rawCounts = (json['counts'] as Map<String, dynamic>? ?? const {});
    return Scan(
      id: json['id'] as String,
      time: DateTime.parse(json['time'] as String),
      location: LatLng(
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
      ),
      precision: LocationPrecision.values.byName(
        json['location_precision'] as String,
      ),
      counts: rawCounts.map((k, v) => MapEntry(k, (v as num).toInt())),
      status: ScanStatus.values.byName(json['status'] as String),
    );
  }

  /// The same record shape as the task file, so saved scans and the
  /// model side always agree.
  Map<String, dynamic> toJson() => {
    'id': id,
    'time': time.toIso8601String(),
    'lat': location.latitude,
    'lng': location.longitude,
    'location_precision': precision.name,
    'counts': counts,
    'status': status.name,
  };

  /// A copy with a new status (the clean-up flow moves a scan forward).
  Scan copyWith({ScanStatus? status}) => Scan(
    id: id,
    time: time,
    location: location,
    precision: precision,
    counts: counts,
    status: status ?? this.status,
  );
}

/// The step after [status] in the clean-up flow, or null at the end.
ScanStatus? nextStatus(ScanStatus status) {
  final i = status.index + 1;
  return i < ScanStatus.values.length ? ScanStatus.values[i] : null;
}
