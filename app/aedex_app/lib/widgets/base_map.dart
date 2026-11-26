import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Where the map opens when there are no scans yet (Manila).
const defaultMapCenter = LatLng(14.5995, 120.9842);

/// OpenStreetMap tiles + the credit line OSM requires, with [layers] on top.
/// Shared by the Map and Hotspots tabs.
class BaseMap extends StatelessWidget {
  const BaseMap({
    super.key,
    required this.points,
    required this.layers,
    this.controller,
    this.onTap,
    this.onMapReady,
    this.bottomPadding = 220,
  });

  /// Called once the map can be moved with [controller].
  final VoidCallback? onMapReady;

  /// Places the camera should fit when the map opens.
  final List<LatLng> points;
  final List<Widget> layers;
  final MapController? controller;
  final VoidCallback? onTap;

  /// Room kept free at the bottom for cards and the tab bar.
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: points.isEmpty ? defaultMapCenter : points.first,
        initialZoom: 16,
        initialCameraFit: points.length < 2
            ? null
            : CameraFit.coordinates(
                coordinates: points,
                padding: EdgeInsets.fromLTRB(48, 140, 48, bottomPadding),
                maxZoom: 17,
              ),
        onTap: onTap == null ? null : (_, _) => onTap!(),
        onMapReady: onMapReady,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'ph.aedex.aedex_app',
        ),
        ...layers,
        // OSM requires visible credit: kept just below the top bar.
        const SafeArea(
          child: Padding(
            padding: EdgeInsets.only(top: 76),
            child: SimpleAttributionWidget(
              source: Text('OpenStreetMap contributors'),
              alignment: Alignment.topRight,
            ),
          ),
        ),
      ],
    );
  }
}
