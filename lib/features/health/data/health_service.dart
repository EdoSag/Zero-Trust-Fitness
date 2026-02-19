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
    // In 13.x, types and permissions must match in length if permissions are provided
    final permissions = types.map((_) => HealthDataAccess.READ).toList();
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

  /// This checks if Health Connect is installed/available on Android.
  /// On iOS, it will generally return true as HealthKit is a system service.
  Future<bool> isHealthConnectAvailable() async {
    try {
      final status = await _health.getHealthConnectSdkStatus();
      return status == HealthConnectSdkStatus.sdkAvailable;
    } catch (e) {
      // Fallback for iOS or platforms where this check isn't applicable
      return false;
    }
  }
}