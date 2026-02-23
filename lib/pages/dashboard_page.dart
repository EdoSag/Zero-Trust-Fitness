import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zerotrust_fitness/features/health/data/health_service.dart';
import 'package:zerotrust_fitness/features/health/data/gps_tracking_service.dart';
import 'package:zerotrust_fitness/components/manual_ingestion_bottom_sheet.dart';
import 'package:zerotrust_fitness/features/app/providers.dart';
import 'package:zerotrust_fitness/components/security_barrier.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:zerotrust_fitness/components/shimmer_loader.dart';
import 'package:zerotrust_fitness/globals/app_state.dart';
import 'package:zerotrust_fitness/main.dart';
import 'package:zerotrust_fitness/widget_service.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:zerotrust_fitness/heart_point_calculator.dart';
import 'package:zerotrust_fitness/core/security/encryption_service.dart';
import 'package:zerotrust_fitness/core/storage/local_vault.dart';
import 'package:zerotrust_fitness/pages/permissions_page.dart';

@NowaGenerated()
// Changed from StatefulWidget to ConsumerStatefulWidget
class DashboardPage extends ConsumerStatefulWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() {
    return _DashboardPageState();
  }
}

@NowaGenerated()
// Changed from State to ConsumerState
class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _isLoading = false;
  List<HealthDataPoint> _healthData = [];
  List<Map<String, dynamic>> _recentActivities = [];
  final Health _health = Health();
  final GpsTrackingService _gpsTrackingService = GpsTrackingService();
  int _heartPointsTotal = 0;
  GpsTrackingSnapshot _gpsSnapshot = GpsTrackingSnapshot(
    distanceMeters: 0,
    elapsed: Duration.zero,
    currentPaceMinutesPerKm: 0,
    isTracking: false,
  );

  @override
  void initState() {
    super.initState();
    _gpsTrackingService.snapshots.listen((snapshot) {
      if (!mounted) return;
      setState(() => _gpsSnapshot = snapshot);
    });
    _loadHealthData();
  }

Future<void> _loadHealthData() async {
  if (!mounted) return;

  setState(() => _isLoading = true);
  try {
    final healthService = HealthService();
    final isHealthConnectAvailable =
        await healthService.isHealthConnectAvailable();
    if (!isHealthConnectAvailable) {
      debugPrint(
        'Health Connect is unavailable. Install/enable it before syncing.',
      );
      setState(() => _healthData = []);
      return;
    }

    final readableTypes = await _getReadableHealthTypes();
    if (readableTypes.isEmpty) {
      debugPrint('Health permissions not granted.');
      setState(() {
        _healthData = [];
        _heartPointsTotal = 0;
      });
      return;
    }

    final healthData = await healthService.fetchLatestData(
      requestedTypes: readableTypes,
    );
    final deduplicated = Health().removeDuplicates(healthData);

    if (!mounted) return;
    final totalSteps = deduplicated
        .where((p) => p.type == HealthDataType.STEPS)
        .fold<int>(0, (sum, p) => sum + _extractNumericValue(p).toInt());

    var heartPoints = deduplicated
        .where((p) => p.type == HealthDataType.EXERCISE_TIME)
        .fold<int>(0, (sum, p) => sum + _extractNumericValue(p).toInt());

    if (heartPoints == 0) {
      heartPoints = deduplicated
          .where((p) => p.type == HealthDataType.HEART_RATE)
          .fold<int>(0, (sum, p) {
            final bpm = _extractNumericValue(p);
            return sum + _calculateHeartPointsFromHeartRate(bpm, 1);
          });
    }
    setState(() {
      _healthData = deduplicated;
      _heartPointsTotal = heartPoints;
    });

    final secretKey = ref.read(securityEnclaveProvider);
    await WidgetService.updateWidgetData(
      steps: totalSteps,
      heartPoints: heartPoints,
      isLocked: secretKey == null,
    );
    await _loadRecentActivities();
  } catch (e) {
    debugPrint('Error loading health data: $e');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  Future<List<HealthDataType>> _getReadableHealthTypes() async {
    final statuses = await Future.wait<bool?>([
      _health.hasPermissions(
        [HealthDataType.STEPS],
        permissions: [HealthDataAccess.READ],
      ),
      _health.hasPermissions(
        [HealthDataType.HEART_RATE],
        permissions: [HealthDataAccess.READ],
      ),
      _health.hasPermissions(
        [HealthDataType.EXERCISE_TIME],
        permissions: [HealthDataAccess.READ],
      ),
    ]);

    final readableTypes = <HealthDataType>[];
    if (statuses[0] != false) readableTypes.add(HealthDataType.STEPS);
    if (statuses[1] != false) readableTypes.add(HealthDataType.HEART_RATE);
    if (statuses[2] != false) readableTypes.add(HealthDataType.EXERCISE_TIME);
    return readableTypes;
  }

  Future<void> _loadRecentActivities() async {
    final secretKey = ref.read(securityEnclaveProvider);
    if (secretKey == null) {
      if (mounted) {
        setState(() => _recentActivities = []);
      }
      return;
    }

    try {
      final encryptedRows = await LocalVault().fetchWorkouts(secretKey);
      final activities = <Map<String, dynamic>>[];

      for (final encrypted in encryptedRows) {
        if (activities.length == 3) break;
        try {
          final decrypted = await EncryptionService().decryptString(
            encrypted,
            secretKey,
          );
          final decoded = jsonDecode(decrypted);
          if (decoded is Map<String, dynamic>) {
            activities.add(decoded);
          } else if (decoded is Map) {
            activities.add(decoded.map((k, v) => MapEntry('$k', v)));
          }
        } catch (_) {
          // Skip entries that fail to decrypt or parse.
        }
      }

      if (!mounted) return;
      setState(() => _recentActivities = activities);
    } catch (e) {
      debugPrint('Error loading recent activities: $e');
      if (!mounted) return;
      setState(() => _recentActivities = []);
    }
  }

  double _extractNumericValue(HealthDataPoint point) {
    final value = point.value;

    // 1. Handle NumericHealthValue (most common for steps/calories)
    if (value is NumericHealthValue) {
      return value.numericValue.toDouble();
    }

    // 2. Fallback for non-numeric HealthValue variants
    return double.tryParse(value.toString()) ?? 0.0;
  }

  int _calculateHeartPointsFromHeartRate(double bpm, int minutes) {
    // Fallback profile assumption when user age is not captured in state.
    const assumedAge = 30;
    final maxHeartRate = HeartPointCalculator.calculateMaxHeartRate(assumedAge);
    return HeartPointCalculator.calculatePoints(bpm, maxHeartRate, minutes);
  }

  String _getMetricValue(HealthDataType type) {
    final points = _healthData.where((p) => p.type == type).toList();
    if (points.isEmpty) return '0';
    double sum = 0;
    for (var p in points) {
      sum += _extractNumericValue(p);
    }
    if (type == HealthDataType.STEPS) return sum.toInt().toString();
    return sum.toStringAsFixed(0);
  }

  Future<void> _showManualIngestion(BuildContext context, SecretKey? secretKey) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ManualIngestionBottomSheet(secretKey: secretKey),
    );

    await _loadRecentActivities();
  }

  // Changed dynamic ref to WidgetRef for type safety
  Future<void> _unlockVault(WidgetRef ref) async {
  final LocalAuthentication auth = LocalAuthentication();
  const storage = FlutterSecureStorage();
  String? finalPassphrase;

  try {
    // 1. Check if biometrics are available and configured
    final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
    final bool isDeviceSupported = await auth.isDeviceSupported();

    if (canAuthenticateWithBiometrics && isDeviceSupported) {
      // 2. Attempt biometric authentication
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Scan fingerprint to unlock your health dashboard',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true, // Forces fingerprint/face specifically
        ),
      );

      if (didAuthenticate) {
        // 3. Retrieve the saved passphrase from the secure hardware enclave
        finalPassphrase = await storage.read(key: 'vault_passphrase');
      }
    }
  } catch (e) {
    debugPrint('Biometric authentication error: $e');
    // Fallback to manual if biometrics error out
  }

  // 4. Fallback: If biometrics failed or no passphrase was saved yet, show Dialog
  if (finalPassphrase == null) {
    final TextEditingController passphraseController = TextEditingController();
    finalPassphrase = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlock Vault'),
        content: TextField(
          controller: passphraseController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Master Passphrase'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(passphraseController.text),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }

  // Exit if user cancelled manual dialog
  if (finalPassphrase == null || finalPassphrase.isEmpty) return;

  // 5. Try to initialize the Enclave with the passphrase
  final unlocked = await ref
      .read(securityEnclaveProvider.notifier)
      .initialize(finalPassphrase);

  if (!unlocked) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unlock failed. Invalid passphrase.')),
      );
    }
    return;
  }

  // 6. Success! If this was a manual entry, save it for future biometric use
  await storage.write(key: 'vault_passphrase', value: finalPassphrase);

  // 7. Initialize background tasks if needed
  final tasksInitialized = sharedPrefs.getBool('bg_tasks_initialized') ?? false;
  if (!tasksInitialized) {
    await AppState.of(context, listen: false).initializeBackgroundTasks();
    await sharedPrefs.setBool('bg_tasks_initialized', true);
  }

  HapticFeedback.mediumImpact();
  await _loadHealthData();
}

  Future<void> _toggleGpsTracking() async {
    if (_gpsSnapshot.isTracking) {
      await _gpsTrackingService.stop();
      return;
    }

    try {
      await _gpsTrackingService.start();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('GPS tracking unavailable: $e')),
      );
    }
  }

  List<FlSpot> _buildChartSpots(HealthDataType type) {
    final filtered = _healthData.where((point) => point.type == type).toList()
      ..sort((a, b) => a.dateFrom.compareTo(b.dateFrom));

    return filtered.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), _extractNumericValue(entry.value));
    }).toList();
  }

  String _formatElapsed(Duration duration) {
    final mins = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${duration.inHours.toString().padLeft(2, '0')}:$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // With ConsumerState, we watch providers directly without a 'Consumer' widget
    final secretKey = ref.watch(securityEnclaveProvider);
    final isLocked = secretKey == null;

    return SecurityBarrier(
      isLocked: isLocked,
      onUnlock: () => _unlockVault(ref),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Zero-Trust Health'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Permissions Center',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PermissionsPage(),
                  ),
                );
                await _loadHealthData();
              },
            ),
            IconButton(
              icon: const Icon(Icons.lock_outline_rounded),
              onPressed: () {
                HapticFeedback.heavyImpact();
                ref.read(securityEnclaveProvider.notifier).lock();
                setState(() => _recentActivities = []);
                WidgetService.redactWidget();
              },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: ShimmerLoader())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMetricHighlights(theme),
                    const SizedBox(height: 20),
                    _buildAnalyticsSection(theme),
                    const SizedBox(height: 24),
                    _buildGpsTrackingSection(theme),
                    const SizedBox(height: 32),
                    Text(
                      'Recent Activity',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildActivityFeed(theme),
                  ],
                ),
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async => _showManualIngestion(context, secretKey),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildAnalyticsSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.15),
            theme.colorScheme.secondary.withValues(alpha: 0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Analytics', style: theme.textTheme.titleMedium),
              const Icon(Icons.insights, color: Color(0xFF6366F1)),
            ],
          ),
          const SizedBox(height: 24),
          Text('Steps Trend', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: _buildSingleChart(
              type: HealthDataType.STEPS,
              lineColor: const Color(0xFF5B7CFF),
              fillColor: const Color(0xFF5B7CFF),
            ),
          ),
          const SizedBox(height: 18),
          Text('Heart Rate Trend', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: _buildSingleChart(
              type: HealthDataType.HEART_RATE,
              lineColor: const Color(0xFFFF5D7A),
              fillColor: const Color(0xFFFF5D7A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleChart({
    required HealthDataType type,
    required Color lineColor,
    required Color fillColor,
  }) {
    final spots = _buildChartSpots(type);
    if (spots.isEmpty) {
      return const Center(child: Text('No data yet'));
    }

    return LineChart(
      LineChartData(
        minY: 0,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: null,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.white.withValues(alpha: 0.08),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: lineColor,
            barWidth: 4,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  fillColor.withValues(alpha: 0.28),
                  fillColor.withValues(alpha: 0.02),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricHighlights(ThemeData theme) {
    final steps = _getMetricValue(HealthDataType.STEPS);
    final points = _heartPointsTotal.toString();
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            theme: theme,
            title: 'Steps',
            value: steps,
            icon: Icons.directions_walk,
            gradientColors: const [Color(0xFF3B82F6), Color(0xFF6366F1)],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            theme: theme,
            title: 'Heart Points',
            value: points,
            icon: Icons.favorite,
            gradientColors: const [Color(0xFFF43F5E), Color(0xFFFB7185)],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required ThemeData theme,
    required String title,
    required String value,
    required IconData icon,
    required List<Color> gradientColors,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.95)),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildGpsTrackingSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Real-time GPS', style: theme.textTheme.titleMedium),
              FilledButton.icon(
                onPressed: _toggleGpsTracking,
                icon: Icon(_gpsSnapshot.isTracking ? Icons.stop : Icons.play_arrow),
                label: Text(_gpsSnapshot.isTracking ? 'Stop' : 'Start'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Distance: ${(_gpsSnapshot.distanceMeters / 1000).toStringAsFixed(2)} km'),
          Text('Elapsed: ${_formatElapsed(_gpsSnapshot.elapsed)}'),
          Text('Pace: ${_gpsSnapshot.currentPaceMinutesPerKm.toStringAsFixed(2)} min/km'),
        ],
      ),
    );
  }

  Widget _buildActivityFeed(ThemeData theme) {
    if (_recentActivities.isEmpty) {
      return Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.secondary.withOpacity(0.1),
            child: Icon(Icons.inbox_outlined, color: theme.colorScheme.secondary),
          ),
          title: const Text('No recent activities'),
          subtitle: const Text('Add one manually or sync from health data.'),
        ),
      );
    }

    return Column(
      children: _recentActivities.map((activity) {
        final title = _activityTitle(activity);
        final subtitle = _activitySubtitle(activity);
        final tag = _activityTag(activity);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.secondary.withOpacity(0.1),
              child: Icon(_activityIcon(activity), color: theme.colorScheme.secondary),
            ),
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.5)),
              ),
              child: Text(
                tag,
                style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _activityTitle(Map<String, dynamic> activity) {
    final rawType = (activity['type'] ?? 'Activity').toString();
    if (rawType.startsWith('HealthDataType.')) {
      final normalized = rawType
          .replaceFirst('HealthDataType.', '')
          .replaceAll('_', ' ')
          .toLowerCase();
      return normalized
          .split(' ')
          .where((part) => part.isNotEmpty)
          .map((part) => part[0].toUpperCase() + part.substring(1))
          .join(' ');
    }
    return rawType;
  }

  String _activitySubtitle(Map<String, dynamic> activity) {
    final timestampRaw = activity['timestamp'] ?? activity['date'];
    final parsedTimestamp = timestampRaw is String
        ? DateTime.tryParse(timestampRaw)?.toLocal()
        : null;

    final timeText = parsedTimestamp == null
        ? 'Unknown time'
        : '${parsedTimestamp.year.toString().padLeft(4, '0')}-'
            '${parsedTimestamp.month.toString().padLeft(2, '0')}-'
            '${parsedTimestamp.day.toString().padLeft(2, '0')} '
            '${parsedTimestamp.hour.toString().padLeft(2, '0')}:'
            '${parsedTimestamp.minute.toString().padLeft(2, '0')}';

    final duration = activity['duration'];
    final intensity = activity['intensity'];
    if (duration != null) {
      final intensityText = intensity == null ? 'n/a' : '$intensity/10';
      return '$duration min, intensity $intensityText, $timeText';
    }

    final value = activity['value'];
    if (value != null) {
      return 'Value: $value, $timeText';
    }

    return timeText;
  }

  String _activityTag(Map<String, dynamic> activity) {
    if (activity.containsKey('duration')) {
      return 'MANUAL';
    }
    return 'AUTO';
  }

  IconData _activityIcon(Map<String, dynamic> activity) {
    final type = _activityTitle(activity).toLowerCase();
    if (type.contains('run')) return Icons.directions_run;
    if (type.contains('walk')) return Icons.directions_walk;
    if (type.contains('cycl')) return Icons.directions_bike;
    if (type.contains('swim')) return Icons.pool;
    if (type.contains('heart')) return Icons.favorite;
    if (type.contains('step')) return Icons.hiking;
    return Icons.bolt;
  }
}
