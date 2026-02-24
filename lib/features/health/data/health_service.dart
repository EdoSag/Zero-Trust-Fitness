import 'package:flutter/foundation.dart';
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

  Future<List<HealthDataPoint>> fetchLatestData({
    List<HealthDataType>? requestedTypes,
  }) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final dataTypes = requestedTypes ?? types;
    if (dataTypes.isEmpty) {
      return const <HealthDataPoint>[];
    }

    return await _health.getHealthDataFromTypes(
      types: dataTypes,
      startTime: startOfDay,
      endTime: now,
    );
  }

  /// This checks if Health Connect is installed/available on Android.
  /// On iOS, it will generally return true as HealthKit is a system service.
  Future<bool> isHealthConnectAvailable() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return true;
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }

    try {
      final status = await _health.getHealthConnectSdkStatus();
      return status == HealthConnectSdkStatus.sdkAvailable;
    } catch (_) {
      // On Android, failure here should be treated as unavailable.
      return false;
    }
  }
}
