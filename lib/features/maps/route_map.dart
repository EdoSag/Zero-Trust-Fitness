import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:zerotrust_fitness/features/health/data/gps_tracking_service.dart';
import 'package:zerotrust_fitness/features/maps/tile_cache.dart';

/// A saved workout's route on a map, framed to fit. Tiles come from the
/// phone's map cache first (see [TileCache]).
class RouteMap extends StatelessWidget {
  const RouteMap({super.key, required this.points, this.height = 220});

  final List<GpsRoutePoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    final latLngs = [for (final p in points) LatLng(p.latitude, p.longitude)];
    if (latLngs.length < 2) return const SizedBox.shrink();
    final color = Theme.of(context).colorScheme.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.coordinates(
              coordinates: latLngs,
              padding: const EdgeInsets.all(24),
              maxZoom: 17,
            ),
            interactionOptions: const InteractionOptions(
              flags:
                  InteractiveFlag.pinchZoom |
                  InteractiveFlag.drag |
                  InteractiveFlag.doubleTapZoom,
            ),
          ),
          children: [
            ztTileLayer(),
            PolylineLayer(
              polylines: [
                Polyline(points: latLngs, color: color, strokeWidth: 4),
              ],
            ),
            MarkerLayer(
              markers: [
                _dot(latLngs.first, Colors.green),
                _dot(latLngs.last, Colors.red),
              ],
            ),
            ztMapAttribution(),
          ],
        ),
      ),
    );
  }

  Marker _dot(LatLng at, Color color) => Marker(
    point: at,
    width: 14,
    height: 14,
    child: Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    ),
  );
}
