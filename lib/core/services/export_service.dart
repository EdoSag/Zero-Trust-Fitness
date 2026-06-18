import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;
import 'package:zerotrust_fitness/core/security/encryption_service.dart';
import 'package:zerotrust_fitness/core/storage/local_vault.dart';

class ExportPreview {
  const ExportPreview({
    required this.workoutCount,
    required this.metricDayCount,
    required this.achievementCount,
    required this.goalCount,
    required this.exportedAt,
  });
  final int workoutCount;
  final int metricDayCount;
  final int achievementCount;
  final int goalCount;
  final DateTime exportedAt;
}

class ExportService {
  factory ExportService() => _instance;
  ExportService._();
  static final ExportService _instance = ExportService._();

  // ---------------------------------------------------------------------------
  // JSON export
  // ---------------------------------------------------------------------------

  Future<void> exportJson(SecretKey secretKey) async {
    final vault = LocalVault();
    final encService = EncryptionService();

    final workoutRows = await vault.fetchWorkoutsWithIds(secretKey);
    final workouts = <Map<String, dynamic>>[];
    for (final row in workoutRows) {
      try {
        final plain = await encService.decryptString(row.encryptedData, secretKey);
        final decoded = jsonDecode(plain);
        if (decoded is Map) {
          workouts.add({...decoded.map((k, v) => MapEntry('$k', v))});
        }
      } catch (_) {}
    }

    final metricRows = await vault.fetchDailyMetrics(secretKey);
    final achievements = await vault.fetchAchievements(secretKey);
    final goals = await vault.fetchGoals(secretKey);

    final payload = {
      'version': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'workouts': workouts,
      'daily_metrics': metricRows,
      'achievements': achievements,
      'goals': goals,
    };

    final json = const JsonEncoder.withIndent('  ').convert(payload);
    final file = await _writeTemp('zerotrust_health_export.json', json);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Zero-Trust Health — full data export',
    );
  }

  // ---------------------------------------------------------------------------
  // CSV export (daily_metrics only)
  // ---------------------------------------------------------------------------

  Future<void> exportCsv(SecretKey secretKey) async {
    final rows = await LocalVault().fetchDailyMetrics(secretKey);
    if (rows.isEmpty) return;

    // Collect all metric keys across all rows.
    final keys = <String>{};
    for (final row in rows) {
      final metrics = row['metrics'];
      if (metrics is Map) keys.addAll(metrics.keys.map((k) => '$k'));
    }
    final sortedKeys = keys.toList()..sort();

    final buf = StringBuffer();
    buf.writeln(['date_key', ...sortedKeys].join(','));
    for (final row in rows) {
      final dateKey = row['date_key']?.toString() ?? '';
      final metrics = row['metrics'];
      final values = sortedKeys.map((k) {
        final v = metrics is Map ? metrics[k] : null;
        return v?.toString() ?? '';
      });
      buf.writeln([dateKey, ...values].join(','));
    }

    final file = await _writeTemp('zerotrust_health_metrics.csv', buf.toString());
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Zero-Trust Health — daily metrics CSV',
    );
  }

  // ---------------------------------------------------------------------------
  // Import / restore from JSON
  // ---------------------------------------------------------------------------

  /// Parses the JSON from [jsonContent] and returns a preview without writing anything.
  ExportPreview? parsePreview(String jsonContent) {
    try {
      final decoded = jsonDecode(jsonContent);
      if (decoded is! Map) return null;
      final version = decoded['version'];
      if (version is! int || version > 1) return null;

      final workouts = decoded['workouts'];
      final metrics = decoded['daily_metrics'];
      final achievements = decoded['achievements'];
      final goals = decoded['goals'];
      final exportedAt = DateTime.tryParse(
              decoded['exported_at']?.toString() ?? '') ??
          DateTime.now();

      return ExportPreview(
        workoutCount:
            workouts is List ? workouts.length : 0,
        metricDayCount: metrics is List ? metrics.length : 0,
        achievementCount:
            achievements is List ? achievements.length : 0,
        goalCount: goals is List ? goals.length : 0,
        exportedAt: exportedAt,
      );
    } catch (_) {
      return null;
    }
  }

  /// Restores from [jsonContent], overwriting local vault data.
  /// Returns a message describing the result.
  Future<String> restoreFromJson(
      String jsonContent, SecretKey secretKey) async {
    final decoded = jsonDecode(jsonContent) as Map;
    final vault = LocalVault();
    final encService = EncryptionService();

    // Restore workouts.
    final workoutsRaw = decoded['workouts'];
    if (workoutsRaw is List) {
      final encrypted = <String>[];
      for (final item in workoutsRaw) {
        if (item is! Map) continue;
        final plain = jsonEncode(item.map((k, v) => MapEntry('$k', v)));
        encrypted.add(await encService.encryptString(plain, secretKey));
      }
      await vault.replaceWorkouts(encrypted, secretKey);
    }

    // Restore daily_metrics.
    final metricsRaw = decoded['daily_metrics'];
    if (metricsRaw is List) {
      final rows = <Map<String, dynamic>>[];
      for (final item in metricsRaw) {
        if (item is Map) {
          rows.add(item.map((k, v) => MapEntry('$k', v)));
        }
      }
      await vault.replaceDailyMetrics(rows, secretKey);
    }

    // Restore goals (upsert each).
    final goalsRaw = decoded['goals'];
    if (goalsRaw is List) {
      for (final item in goalsRaw) {
        if (item is! Map) continue;
        final key = item['metric_key']?.toString();
        final target = item['target_value'];
        final period = item['period']?.toString() ?? 'daily';
        if (key != null && target is num) {
          await vault.upsertGoal(
            metricKey: key,
            targetValue: target,
            period: period,
            secretKey: secretKey,
          );
        }
      }
    }

    final preview = parsePreview(jsonContent);
    return 'Restored ${preview?.workoutCount ?? 0} workouts, '
        '${preview?.metricDayCount ?? 0} days of metrics, '
        '${preview?.goalCount ?? 0} goals.';
  }

  // ---------------------------------------------------------------------------
  // Scoped shareable report (4.5)
  // ---------------------------------------------------------------------------

  /// Builds a scoped plaintext report for the given [metricKeys] and
  /// [dateRange], then shares it. The report is NOT encrypted — it is
  /// intentionally human-readable for sharing with e.g. a physician.
  Future<void> generateShareableReport({
    required SecretKey secretKey,
    required List<String> metricKeys,
    required DateTimeRange dateRange,
  }) async {
    final dailyMetrics = await LocalVault().fetchDailyMetrics(secretKey);
    final workoutRows = await LocalVault().fetchWorkouts(secretKey);

    final buf = StringBuffer();
    buf.writeln('ZERO-TRUST HEALTH — PERSONAL REPORT');
    buf.writeln(
        'Period: ${_fmtDate(dateRange.start)} – ${_fmtDate(dateRange.end)}');
    buf.writeln('Generated: ${_fmtDate(DateTime.now())}');
    buf.writeln('Note: All data is self-reported and for informational purposes only.');
    buf.writeln();

    // Daily metrics table
    buf.writeln('── DAILY METRICS ──────────────────────────────');
    final header = ['Date', ...metricKeys].join('\t');
    buf.writeln(header);

    for (final row in dailyMetrics) {
      final dateKey = row['date_key']?.toString() ?? '';
      final date = DateTime.tryParse(dateKey);
      if (date == null) continue;
      if (date.isBefore(dateRange.start) || date.isAfter(dateRange.end)) continue;
      final raw = row['metrics'];
      if (raw is! Map) continue;
      final values = metricKeys.map((k) {
        final v = raw[k];
        if (v is num) return v.toStringAsFixed(v is int ? 0 : 1);
        return '—';
      }).toList();
      buf.writeln([dateKey, ...values].join('\t'));
    }

    buf.writeln();
    buf.writeln('── WORKOUTS ────────────────────────────────────');

    for (final encryptedRow in workoutRows) {
      try {
        final decrypted =
            await EncryptionService().decryptString(encryptedRow, secretKey);
        final data = jsonDecode(decrypted) as Map<String, dynamic>;
        final ts = data['timestamp']?.toString() ?? data['started_at']?.toString() ?? '';
        final date = DateTime.tryParse(ts);
        if (date == null) continue;
        if (date.isBefore(dateRange.start) || date.isAfter(dateRange.end)) continue;
        final type = data['activity_type'] ?? data['type'] ?? 'Workout';
        final dur = data['duration_minutes'] ?? data['duration'] ?? '?';
        final dist = data['distance_km'] != null
            ? ' · ${(data['distance_km'] as num).toStringAsFixed(2)} km'
            : '';
        buf.writeln('${_fmtDate(date)}  $type  ${dur}min$dist');
      } catch (_) {}
    }

    buf.writeln();
    buf.writeln('Generated by Zero-Trust Health — data encrypted on device, shared by user request.');

    final filename =
        'zt_health_report_${_fmtDate(dateRange.start)}_${_fmtDate(dateRange.end)}.txt';
    final file = await _writeTemp(filename, buf.toString());
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Health Report ${_fmtDate(dateRange.start)}–${_fmtDate(dateRange.end)}',
    );
  }

  String _fmtDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------

  Future<File> _writeTemp(String filename, String content) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content, flush: true);
    return file;
  }
}
