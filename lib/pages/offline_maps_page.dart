import 'package:flutter/material.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/features/health/data/gps_tracking_service.dart';
import 'package:zerotrust_fitness/features/maps/tile_cache.dart';

/// Map tiles on the phone: save the areas of past routes, go offline-only so
/// the tile server never learns where you are, or free the space.
class OfflineMapsPage extends StatefulWidget {
  const OfflineMapsPage({super.key, required this.vault});

  final FitnessVault vault;

  @override
  State<OfflineMapsPage> createState() => _OfflineMapsPageState();
}

class _OfflineMapsPageState extends State<OfflineMapsPage> {
  bool _offlineOnly = false;
  ({int tiles, int bytes})? _usage;
  int _routes = 0;
  double? _progress;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cache = await TileCache.instance();
    final offline = await TileCache.offlineOnly();
    final usage = await cache.usage();
    final routes = (await widget.vault.fetchWorkouts())
        .where((w) => GpsRoutePoint.listFrom(w.data['route']).length >= 2)
        .length;
    if (!mounted) return;
    setState(() {
      _offlineOnly = offline;
      _usage = usage;
      _routes = routes;
    });
  }

  Future<void> _saveRoutes() async {
    setState(() {
      _progress = 0;
      _message = null;
    });
    final cache = await TileCache.instance();
    var fetched = 0;
    var capped = false;
    try {
      final workouts = await widget.vault.fetchWorkouts();
      final routes = [
        for (final w in workouts)
          if (GpsRoutePoint.listFrom(w.data['route']) case final r
              when r.length >= 2)
            r,
      ];
      for (final (i, r) in routes.indexed) {
        if (fetched >= TileCache.maxDownloadTiles) {
          capped = true;
          break;
        }
        fetched += await cache.saveArea(r);
        if (mounted) setState(() => _progress = (i + 1) / routes.length);
      }
      _message = fetched == 0
          ? 'Your routes\' maps were already on this phone.'
          : 'Saved $fetched map tiles.'
                '${capped ? ' That\'s the most at once; run it again later for the rest.' : ''}';
    } catch (e) {
      _message = ztErrorMessage(e);
    }
    if (!mounted) return;
    setState(() => _progress = null);
    await _load();
  }

  Future<void> _clear() async {
    await (await TileCache.instance()).clear();
    PaintingBinding.instance.imageCache.clear();
    await _load();
  }

  String _size(int bytes) => bytes >= 1024 * 1024
      ? '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).round()} KB';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usage = _usage;
    final busy = _progress != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Offline maps')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Route maps come from OpenStreetMap. Each map tile is kept on '
              'this phone the first time it is shown, so the map server is '
              'asked once at most, not every time you open a workout.',
              style: TextStyle(color: theme.hintColor),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.cloud_off_outlined),
            title: const Text('Offline maps only'),
            subtitle: const Text(
              'Never contact the map server. Areas you haven\'t saved '
              'show the route on a blank background.',
            ),
            value: _offlineOnly,
            onChanged: (v) async {
              await TileCache.setOfflineOnly(v);
              PaintingBinding.instance.imageCache.clear();
              setState(() => _offlineOnly = v);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.download_for_offline_outlined),
            title: const Text('Save maps of my routes'),
            subtitle: Text(
              _routes == 0
                  ? 'No GPS routes yet'
                  : 'The areas around your $_routes '
                        '${_routes == 1 ? 'route' : 'routes'}, ready offline',
            ),
            enabled: !busy && !_offlineOnly && _routes > 0,
            onTap: _saveRoutes,
          ),
          if (busy)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(value: _progress),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(_message!),
            ),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: const Text('Delete saved maps'),
            subtitle: Text(
              usage == null
                  ? '…'
                  : '${usage.tiles} tiles, ${_size(usage.bytes)}',
            ),
            enabled: !busy && (usage?.tiles ?? 0) > 0,
            onTap: _clear,
          ),
        ],
      ),
    );
  }
}
