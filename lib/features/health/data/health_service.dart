import 'package:health/health.dart';
import 'package:nowa_runtime/nowa_runtime.dart';

@NowaGenerated()
class HealthService {
  HealthService._();

  factory HealthService() => _instance;

  static final HealthService _instance = HealthService._();
  final Health _health = Health();

  final List<HealthDataType> types = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.EXERCISE_TIME,
  ];

  Future<bool> requestPermissions() async {
    final permissions = types.map((_) => HealthDataAccess.READ).toList();
    return _health.requestAuthorization(types, permissions: permissions);
  }

  Future<List<HealthDataPoint>> fetchLatestData() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(hours: 24));
    return _health.getHealthDataFromTypes(
      types: types,
      startTime: yesterday,
      endTime: now,
    );
  }

  Future<bool> isHealthConnectAvailable() {
    return _health.hasPrivacyService(HealthDataType.STEPS);
  }
}
