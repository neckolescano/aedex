import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// The phone's current position. Asks for permission the first time.
/// Throws [LocationProblem] with a message the user can act on.
Future<LatLng> currentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const LocationProblem('Turn on Location in the phone settings.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw const LocationProblem(
      'Aedex needs your location to put this scan on the map.',
    );
  }
  final p = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  );
  return LatLng(p.latitude, p.longitude);
}

class LocationProblem implements Exception {
  const LocationProblem(this.message);
  final String message;

  @override
  String toString() => message;
}
