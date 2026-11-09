import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerotrust_fitness/features/health/data/health_writeback.dart';

import 'support.dart';

class FakeSink implements HealthWorkoutSink {
  final writes = <(String, DateTime, DateTime, double?)>[];
  final deletes = <(DateTime, DateTime)>[];
  bool grant = true;

  @override
  Future<bool> requestWriteAccess() async => grant;

  @override
  Future<bool> write({
    required String type,
    required DateTime start,
    required DateTime end,
    double? distanceMeters,
  }) async {
    writes.add((type, start, end, distanceMeters));
    return true;
  }

  @override
  Future<bool> delete({required DateTime start, required DateTime end}) async {
    deletes.add((start, end));
    return true;
  }
}

void main() {
  late FakeSink sink;
  late HealthWriteback wb;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sink = FakeSink();
    wb = HealthWriteback(sink: sink);
  });

  final run = {
    'type': 'Running',
    'duration': 30,
    'intensity': 7,
    'timestamp': '2026-11-09T07:00:00.000Z',
    'distance_m': 5000.0,
  };

  test('does nothing until turned on', () async {
    expect(await wb.sync('a', run), isFalse);
    expect(sink.writes, isEmpty);
  });

  test('refused access leaves it off', () async {
    sink.grant = false;
    expect(await wb.enable(), isFalse);
    expect(await wb.isEnabled, isFalse);
  });

  test('writes, rewrites after an edit, and removes on delete', () async {
    await wb.enable();
    expect(await wb.sync('a', run), isTrue);
    expect(sink.writes.single.$1, 'Running');
    expect(sink.writes.single.$3,
        DateTime.parse('2026-11-09T07:30:00.000Z'));
    expect(sink.writes.single.$4, 5000.0);

    await wb.sync('a', {...run, 'duration': 40});
    expect(sink.deletes, hasLength(1), reason: 'old record replaced');
    expect(sink.writes, hasLength(2));

    await wb.remove('a');
    expect(sink.deletes, hasLength(2));
    await wb.remove('a');
    expect(sink.deletes, hasLength(2), reason: 'nothing left to remove');
  });

  test('backfill copies logged workouts once, skipping imported ones',
      () async {
    final v = testVault();
    await v.saveWorkout(run, id: 'run');
    await v.saveWorkout({...run, 'source': 'google_fit'}, id: 'fit');
    await v.saveWorkout(
        {'type': 'HealthDataType.STEPS', 'value': 100, 'timestamp': run['timestamp']},
        id: 'hc');
    await wb.enable();
    expect(await wb.backfill(v), 1);
    expect(await wb.backfill(v), 0);
    expect(sink.writes, hasLength(1));
  });
}
