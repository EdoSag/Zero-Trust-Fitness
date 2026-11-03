import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:health/health.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zerotrust_fitness/core/security/encryption_service.dart';
import 'package:zerotrust_fitness/core/storage/local_vault.dart';
import 'package:zerotrust_fitness/features/health/data/health_service.dart';
import 'package:zerotrust_fitness/features/health/domain/heart_points_service.dart';
import 'package:zerotrust_fitness/features/health/domain/momentum_service.dart';
import 'package:zerotrust_fitness/features/achievements/domain/achievement_service.dart';
import 'package:zerotrust_fitness/widget_service.dart';

@NowaGenerated()
class IntegrationService {
  IntegrationService._();

  factory IntegrationService() => _instance;

  static final IntegrationService _instance = IntegrationService._();

  Future<void> syncHealthToVault(SecretKey secretKey) async {
    final healthService = HealthService();
    final health = Health();
    final readableTypes = <HealthDataType>[];
    for (final type in healthService.types) {
      try {
        final status = await health.hasPermissions(
          [type],
          permissions: [HealthDataAccess.READ],
        );
        if (status != false) {
          readableTypes.add(type);
        }
      } catch (_) {
        // Some metrics are unsupported on specific devices.
      }
    }

    if (readableTypes.isEmpty) {
      return;
    }

    final healthData = await healthService.fetchLatestData(
      requestedTypes: readableTypes,
    );
    final deduplicated = health.removeDuplicates(healthData);

    final now = DateTime.now();
    var totalSteps = 0;

    for (final point in deduplicated) {
      final jsonString = jsonEncode({
        'type': point.type.toString(),
        'value': point.value.toString(),
        'date': point.dateFrom.toIso8601String(),
      });

      final encryptedBlob = await EncryptionService().encryptString(
        jsonString,
        secretKey,
      );
      await LocalVault().saveWorkout(encryptedBlob, secretKey);

      // The widget shows today's totals, so only count today's steps.
      if (point.type == HealthDataType.STEPS && _isToday(point.dateFrom, now)) {
        totalSteps += HeartPointsService.numericValue(point).toInt();
      }
    }
    final totalHeartPoints = HeartPointsService.forDay(deduplicated, now).total;

    final momentum = await MomentumService.forToday(
      secretKey,
      todayPoints: totalHeartPoints,
    );
    await WidgetService.updateWidgetData(
      steps: totalSteps,
      heartPoints: totalHeartPoints,
      isLocked: false,
      momentum: momentum.momentum,
      momentumLabel: momentum.label,
      heartTarget: momentum.target,
    );

    await AchievementService().checkAndUnlockAchievements(secretKey);
  }

  bool _isToday(DateTime time, DateTime now) {
    final local = time.toLocal();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }
}
