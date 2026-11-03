import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zerotrust_fitness/core/security/encryption_service.dart';
import 'package:zerotrust_fitness/core/services/supabase_service.dart';
import 'package:zerotrust_fitness/core/storage/local_vault.dart';

class BackgroundBackupService {
  BackgroundBackupService._();
  factory BackgroundBackupService() => _instance;
  static final BackgroundBackupService _instance =
      BackgroundBackupService._();

  static const String _kAutoBackupEnabled = 'auto_backup_enabled';
  static const String _kAutoBackupFreqDays = 'auto_backup_frequency_days';
  static const String _kLastKnownRemoteTs = 'last_known_remote_updated_at';

  Future<bool> get isEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAutoBackupEnabled) ?? false;
  }

  Future<int> get frequencyDays async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kAutoBackupFreqDays) ?? 1;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoBackupEnabled, value);
  }

  Future<void> setFrequencyDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAutoBackupFreqDays, days);
  }

  /// Performs a full vault backup to Supabase.
  /// Safe to call from a workmanager background task.
  Future<String> performVaultBackup(SecretKey secretKey) async {
    await _ensureSupabaseInitialized();

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated — skipping backup');

    final workoutRows = await LocalVault().fetchWorkouts(secretKey);
    final workouts = <Map<String, dynamic>>[];
    for (final row in workoutRows) {
      try {
        final decrypted =
            await EncryptionService().decryptString(row, secretKey);
        final decoded = jsonDecode(decrypted);
        if (decoded is Map<String, dynamic>) {
          workouts.add(decoded);
        } else if (decoded is Map) {
          workouts.add(decoded.map((k, v) => MapEntry('$k', v)));
        }
      } catch (_) {}
    }

    final dailyMetrics = await LocalVault().fetchDailyMetrics(secretKey);
    final dailyMetricMap = <String, Map<String, num>>{};
    for (final row in dailyMetrics) {
      final dateKey = row['date_key']?.toString();
      if (dateKey == null || dateKey.isEmpty) continue;
      final metricsRaw = row['metrics'];
      if (metricsRaw is Map) {
        final parsed = <String, num>{};
        metricsRaw.forEach((k, v) {
          if (v is num) {
            parsed['$k'] = v;
          } else if (v is String) {
            final n = num.tryParse(v);
            if (n != null) parsed['$k'] = n;
          }
        });
        if (parsed.isNotEmpty) dailyMetricMap[dateKey] = parsed;
      }
    }

    final achievements = await LocalVault().fetchAchievements(secretKey);

    final payload = <String, dynamic>{
      'version': 2,
      'synced_at': DateTime.now().toUtc().toIso8601String(),
      'workouts_count': workouts.length,
      'steps_count': 0,
      'heart_points_total': 0,
      'daily_metrics': dailyMetrics,
      'daily_metric_map': dailyMetricMap,
      'workouts': workouts,
      'steps': <dynamic>[],
      'heart_points': {'total': 0, 'records': <dynamic>[]},
      'achievements': achievements,
    };

    final payloadJson = jsonEncode(payload);
    final encrypted =
        await EncryptionService().encryptString(payloadJson, secretKey);
    await SupabaseService().upsertEncryptedVaultBlobForCurrentUser(encrypted);

    final now = DateTime.now().toUtc().toIso8601String();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastKnownRemoteTs, now);

    final summary =
        '${workouts.length} workouts, ${dailyMetrics.length} metric days';

    await LocalVault().insertBackupHistory(
      backupType: 'auto_cloud_backup',
      status: 'success',
      details: summary,
      secretKey: secretKey,
    );

    return summary;
  }

  Future<void> _ensureSupabaseInitialized() async {
    try {
      Supabase.instance.client;
    } catch (_) {
      await dotenv.load(fileName: '.env');
      final url = dotenv.env['SUPABASE_URL'] ?? '';
      final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
      await Supabase.initialize(url: url, anonKey: anonKey);
    }
  }
}
