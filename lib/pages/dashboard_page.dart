import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:provider/provider.dart' as legacy; // Prefix to avoid Riverpod collision
import 'package:zerotrust_fitness/features/health/data/health_service.dart';
import 'package:zerotrust_fitness/components/manual_ingestion_bottom_sheet.dart';
import 'package:zerotrust_fitness/features/app/providers.dart';
import 'package:zerotrust_fitness/components/security_barrier.dart';
import 'package:flutter/services.dart';
import 'package:zerotrust_fitness/components/shimmer_loader.dart';
import 'package:zerotrust_fitness/components/hero_ring.dart';
import 'package:zerotrust_fitness/globals/app_state.dart';
import 'package:zerotrust_fitness/main.dart';
import 'package:zerotrust_fitness/widget_service.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
final LocalAuthentication _auth = LocalAuthentication();
final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadHealthData();
  }

Future<void> _loadHealthData() async {
  if (!mounted) return;
  
  final secretKey = ref.read(securityEnclaveProvider);
  if (secretKey == null) {
    await WidgetService.redactWidget();
    return;
  }

  setState(() => _isLoading = true);
  try {
    final healthService = HealthService();
    final hasPermissions = await healthService.requestPermissions();
    if (!hasPermissions) {
      debugPrint('Health permissions denied.');
      return;
    }

    final healthData = await healthService.fetchLatestData();
    final deduplicated = Health().removeDuplicates(healthData);

    if (!mounted) return;
    setState(() => _healthData = deduplicated);

    final totalSteps = deduplicated
        .where((p) => p.type == HealthDataType.STEPS)
        .fold<int>(0, (sum, p) => sum + _extractNumericValue(p).toInt());

    final heartPoints = deduplicated
        .where((p) => p.type == HealthDataType.EXERCISE_TIME)
        .fold<int>(0, (sum, p) => sum + _extractNumericValue(p).toInt());

    await WidgetService.updateWidgetData(
      steps: totalSteps,
      heartPoints: heartPoints,
      isLocked: false,
    );
  } catch (e) {
    debugPrint('Error loading health data: $e');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  double _extractNumericValue(HealthDataPoint point) {
    final value = point.value;

    // 1. Handle NumericHealthValue (most common for steps/calories)
    if (value is NumericHealthValue) {
      return value.numericValue.toDouble(); // Added .toDouble()
    }

    // 2. Handle cases where value might already be a num (int or double)
    if (value is num) {
      return (value as NumericHealthValue).numericValue.toDouble(); // Cast to NumericHealthValue to access numericValue
    }

    // 3. Fallback for unexpected types
    return double.tryParse(value.toString()) ?? 0.0;
  }

  String _getMetricValue(HealthDataType type, {String unit = ''}) {
    final points = _healthData.where((p) => p.type == type).toList();
    if (points.isEmpty) return '0';
    double sum = 0;
    for (var p in points) {
      sum += _extractNumericValue(p);
    }
    if (type == HealthDataType.STEPS) return sum.toInt().toString();
    return sum.toStringAsFixed(0);
  }

  double _getMetricProgress(HealthDataType type, double goal) {
    final valStr = _getMetricValue(type);
    final value = double.tryParse(valStr.replaceAll(',', '')) ?? 0;
    return (value / goal).clamp(0, 1);
  }

  void _showManualIngestion(BuildContext context, SecretKey? secretKey) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ManualIngestionBottomSheet(secretKey: secretKey),
    );
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
              icon: const Icon(Icons.lock_outline_rounded),
              onPressed: () {
                HapticFeedback.heavyImpact();
                ref.read(securityEnclaveProvider.notifier).lock();
              },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: ShimmerLoader())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        HeroRing(
                          label: 'Steps',
                          progress: _getMetricProgress(HealthDataType.STEPS, 10000),
                          value: _getMetricValue(HealthDataType.STEPS),
                          color: const Color(0xFF6366F1),
                          icon: Icons.directions_walk,
                        ),
                        HeroRing(
                          label: 'Heart Points',
                          progress: _getMetricProgress(HealthDataType.EXERCISE_TIME, 30),
                          value: _getMetricValue(HealthDataType.EXERCISE_TIME, unit: 'pts'),
                          color: const Color(0xFFF43F5E),
                          icon: Icons.favorite,
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    _buildAnalyticsSection(theme),
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
          onPressed: () => _showManualIngestion(context, secretKey),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildAnalyticsSection(ThemeData theme) {
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
              Text('Analytics', style: theme.textTheme.titleMedium),
              const Icon(Icons.insights, color: Color(0xFF6366F1)),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                'Performance Charts Loading...',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityFeed(ThemeData theme) {
    return Column(
      children: List.generate(
        3,
        (index) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.secondary.withOpacity(0.1),
              child: Icon(Icons.bolt, color: theme.colorScheme.secondary),
            ),
            title: Text(index == 0 ? 'High Intensity Run' : 'Morning Walk'),
            subtitle: const Text('Secured in local vault'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.5)),
              ),
              child: const Text(
                'VAULTED',
                style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
