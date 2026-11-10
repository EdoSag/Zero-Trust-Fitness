import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zerotrust_fitness/features/health/data/gps_tracking_service.dart';
import 'package:zerotrust_fitness/features/maps/tile_cache.dart';

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('tiles'));
  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('tile maths matches the OpenStreetMap scheme', () {
    // Berlin at zoom 10 is tile 550/335.
    expect(TileCache.lonToTileX(13.405, 10), 550);
    expect(TileCache.latToTileY(52.52, 10), 335);
  });

  test('a route needs its tiles plus a margin at each zoom', () {
    final tiles = TileCache.tilesCovering(
      const [GpsRoutePoint(52.52, 13.405), GpsRoutePoint(52.521, 13.406)],
      minZoom: 14,
      maxZoom: 15,
    );
    expect(tiles.where((t) => t.z == 14), hasLength(9));
    expect(tiles.toSet(), hasLength(tiles.length));
  });

  test('a tile is fetched once, then served from the phone', () async {
    var requests = 0;
    String? agent;
    final cache = TileCache(
      dir,
      client: MockClient((req) async {
        requests++;
        agent = req.headers['User-Agent'];
        return http.Response.bytes(Uint8List.fromList([1, 2, 3]), 200);
      }),
    );
    expect(await cache.load(1, 0, 0, offlineOnly: false), [1, 2, 3]);
    expect(await cache.load(1, 0, 0, offlineOnly: false), [1, 2, 3]);
    expect(requests, 1);
    expect(agent, contains('ZeroTrustFitness'));
    expect((await cache.usage()).tiles, 1);
  });

  test('offline only never asks the server', () async {
    var requests = 0;
    final cache = TileCache(
      dir,
      client: MockClient((req) async {
        requests++;
        return http.Response('', 200);
      }),
    );
    expect(await cache.load(3, 1, 1, offlineOnly: true), isNull);
    expect(requests, 0);
  });

  test(
    'saving an area skips tiles already here and respects the cap',
    () async {
      var requests = 0;
      final cache = TileCache(
        dir,
        client: MockClient((req) async {
          requests++;
          return http.Response.bytes(Uint8List.fromList([9]), 200);
        }),
      );
      const route = [GpsRoutePoint(52.52, 13.405), GpsRoutePoint(52.53, 13.42)];
      final first = await cache.saveArea(route, minZoom: 13, maxZoom: 14);
      expect(first, requests);
      final again = await cache.saveArea(route, minZoom: 13, maxZoom: 14);
      expect(again, 0);
      final wide = await cache.saveArea(
        const [GpsRoutePoint(50, 10), GpsRoutePoint(52, 14)],
        minZoom: 10,
        maxZoom: 12,
      );
      expect(wide, TileCache.maxDownloadTiles);
      await cache.clear();
      expect((await cache.usage()).tiles, 0);
    },
  );
}
