import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerotrust_fitness/features/health/data/gps_tracking_service.dart';

/// The map tiles this app uses, and who it says it is to the tile server
/// (OpenStreetMap asks every app to identify itself).
const osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const mapUserAgentPackage = 'dev.sagron.zerotrustfitness';
const _userAgent = 'ZeroTrustFitness/1.0 (+$mapUserAgentPackage)';

/// Map tiles kept on the phone (app-private storage), so a route map that
/// was seen or saved once never asks the tile server again, and with
/// "Offline maps only" nothing is asked at all: the tile server can't learn
/// where the person runs.
class TileCache {
  TileCache(this.directory, {http.Client? client}) : _client = client;

  final Directory directory;
  http.Client? _client;

  static const _offlineOnlyKey = 'maps_offline_only';

  /// The most tiles one "save for offline" may fetch; OpenStreetMap's tile
  /// policy doesn't allow bulk downloads.
  static const maxDownloadTiles = 400;

  static TileCache? _instance;

  static Future<TileCache> instance() async {
    if (_instance case final c?) return c;
    final base = await getApplicationSupportDirectory();
    return _instance = TileCache(Directory('${base.path}/map_tiles'));
  }

  static Future<bool> offlineOnly() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_offlineOnlyKey) ?? false;
  }

  static Future<void> setOfflineOnly(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_offlineOnlyKey, on);
  }

  File _file(int z, int x, int y) => File('${directory.path}/$z/$x/$y.png');

  Future<Uint8List?> read(int z, int x, int y) async {
    final f = _file(z, x, y);
    try {
      return await f.exists() ? await f.readAsBytes() : null;
    } on FileSystemException {
      return null;
    }
  }

  Future<void> write(int z, int x, int y, Uint8List bytes) async {
    final f = _file(z, x, y);
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes, flush: true);
  }

  Future<bool> has(int z, int x, int y) => _file(z, x, y).exists();

  /// Downloads one tile into the cache; null when the server refused.
  Future<Uint8List?> fetch(int z, int x, int y) async {
    final url = osmTileUrl
        .replaceFirst('{z}', '$z')
        .replaceFirst('{x}', '$x')
        .replaceFirst('{y}', '$y');
    final client = _client ??= http.Client();
    final res = await client
        .get(Uri.parse(url), headers: {'User-Agent': _userAgent})
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
    await write(z, x, y, res.bodyBytes);
    return res.bodyBytes;
  }

  /// The tile from the cache, else (unless [offlineOnly]) from the server.
  Future<Uint8List?> load(
    int z,
    int x,
    int y, {
    required bool offlineOnly,
  }) async {
    final cached = await read(z, x, y);
    if (cached != null || offlineOnly) return cached;
    return fetch(z, x, y);
  }

  /// Number of tiles and bytes on the phone.
  Future<({int tiles, int bytes})> usage() async {
    var tiles = 0, bytes = 0;
    if (!await directory.exists()) return (tiles: 0, bytes: 0);
    await for (final e in directory.list(recursive: true)) {
      if (e is File) {
        tiles++;
        bytes += await e.length();
      }
    }
    return (tiles: tiles, bytes: bytes);
  }

  Future<void> clear() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  /// Saves the tiles that cover [points] (with a margin) from [minZoom] to
  /// [maxZoom] for offline use, skipping ones already here. Returns how many
  /// were fetched: at most [budget], and none once "Offline maps only" is
  /// turned on, even mid-download. Tiles are listed lazily and the scan
  /// stops early, so a very long route can't list millions of tiles.
  Future<int> saveArea(
    List<GpsRoutePoint> points, {
    int minZoom = 12,
    int maxZoom = 16,
    int budget = maxDownloadTiles,
    Future<bool> Function() stop = offlineOnly,
    void Function(int done, int budget)? onProgress,
  }) async {
    var done = 0, scanned = 0;
    for (final t in tilesCovering(points, minZoom: minZoom, maxZoom: maxZoom)) {
      if (done >= budget || ++scanned > maxScannedTiles) break;
      if (await has(t.z, t.x, t.y)) continue;
      if (await stop()) break;
      try {
        await fetch(t.z, t.x, t.y);
      } catch (_) {
        // A tile that fails is fetched again the next time it's seen.
      }
      done++;
      onProgress?.call(done, budget);
    }
    return done;
  }

  /// How many tiles one [saveArea] looks at, cached or not.
  static const maxScannedTiles = 20000;

  /// The tiles covering [points]' bounding box (plus a one-tile margin) at
  /// each zoom level, lowest zoom first, listed as they are read.
  static Iterable<TileXyz> tilesCovering(
    List<GpsRoutePoint> points, {
    required int minZoom,
    required int maxZoom,
  }) sync* {
    if (points.isEmpty) return;
    var minLat = 90.0, maxLat = -90.0, minLon = 180.0, maxLon = -180.0;
    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLon = math.min(minLon, p.longitude);
      maxLon = math.max(maxLon, p.longitude);
    }
    for (var z = minZoom; z <= maxZoom; z++) {
      final n = 1 << z;
      final x0 = math.max(0, lonToTileX(minLon, z) - 1);
      final x1 = math.min(n - 1, lonToTileX(maxLon, z) + 1);
      final y0 = math.max(0, latToTileY(maxLat, z) - 1);
      final y1 = math.min(n - 1, latToTileY(minLat, z) + 1);
      for (var x = x0; x <= x1; x++) {
        for (var y = y0; y <= y1; y++) {
          yield TileXyz(z, x, y);
        }
      }
    }
  }

  static int lonToTileX(double lon, int z) =>
      ((lon + 180) / 360 * (1 << z)).floor();

  static int latToTileY(double lat, int z) {
    final r = lat * math.pi / 180;
    return ((1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) /
            2 *
            (1 << z))
        .floor();
  }
}

@immutable
class TileXyz {
  const TileXyz(this.z, this.x, this.y);
  final int z, x, y;

  @override
  bool operator ==(Object other) =>
      other is TileXyz && other.z == z && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(z, x, y);
}

/// A flutter_map tile provider that reads through [TileCache]. With
/// "Offline maps only" on, tiles not on the phone stay blank instead of
/// being fetched.
class CachedTileProvider extends TileProvider {
  CachedTileProvider();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      CachedTileImage(coordinates.z, coordinates.x, coordinates.y);
}

/// The tile layer every map in the app uses.
TileLayer ztTileLayer() => TileLayer(
  urlTemplate: osmTileUrl,
  userAgentPackageName: mapUserAgentPackage,
  tileProvider: CachedTileProvider(),
  maxNativeZoom: 19,
);

/// OpenStreetMap's required credit.
Widget ztMapAttribution() =>
    const SimpleAttributionWidget(source: Text('OpenStreetMap contributors'));

@immutable
class CachedTileImage extends ImageProvider<CachedTileImage> {
  const CachedTileImage(this.z, this.x, this.y);

  final int z, x, y;

  @override
  Future<CachedTileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    CachedTileImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(_load(decode));

  Future<ImageInfo> _load(ImageDecoderCallback decode) async {
    final cache = await TileCache.instance();
    final bytes = await cache.load(
      z,
      x,
      y,
      offlineOnly: await TileCache.offlineOnly(),
    );
    if (bytes == null) {
      throw StateError('Map tile $z/$x/$y is not saved on this phone');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final codec = await decode(buffer);
    final frame = await codec.getNextFrame();
    return ImageInfo(image: frame.image);
  }

  @override
  bool operator ==(Object other) =>
      other is CachedTileImage && other.z == z && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(z, x, y);
}
