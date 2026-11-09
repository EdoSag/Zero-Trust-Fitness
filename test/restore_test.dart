import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_fitness/core/services/export_service.dart';

import 'support.dart';

void main() {
  test('restoring an export into the same vault adds no copies', () async {
    final vault = testVault();
    final run = {'type': 'Running', 'duration': 30, 'timestamp': '2026-11-01T07:00:00.000'};
    // Logged in this version, so it has a random id.
    await vault.saveWorkout(run);
    final export = jsonEncode({
      'version': 1,
      'exported_at': '2026-11-09T00:00:00Z',
      'workouts': [
        run,
        {'type': 'Yoga', 'duration': 20, 'timestamp': '2026-11-02T08:00:00.000'},
      ],
    });

    await ExportService().restoreFromJson(export, vault);
    await ExportService().restoreFromJson(export, vault);

    final types = [for (final w in await vault.fetchWorkouts()) w.data['type']];
    expect(types, unorderedEquals(['Running', 'Yoga']));
  });
}
