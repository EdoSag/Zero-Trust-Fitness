import 'package:nowa_runtime/nowa_runtime.dart';

@NowaGenerated()
class HealthService {
  HealthService._();

  factory HealthService() {
    return _instance;
  }

  final Health _health = Health();

  final List<HealthDataType> types = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.EXERCISE_TIME,
  ];

  static final HealthService _instance = HealthService._();

  Future<bool> requestPermissions() async {
    final permissions = types.map((e) => HealthDataAccess.READ).toList();
    return await _health.requestAuthorization(types, permissions: permissions);
  }

  Future<List<HealthDataPoint>> fetchLatestData() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(hours: 24));
    return await _health.getHealthDataFromTypes(
      types: types,
      startTime: yesterday,
      endTime: now,
    );
  }

  Future<bool> isHealthConnectAvailable() async {
    return await _health.hasPrivacyService(HealthDataType.STEPS);
  }
}
