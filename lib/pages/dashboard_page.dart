import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zerotrust_fitness/features/health/data/health_service.dart';
import 'package:zerotrust_fitness/components/manual_ingestion_bottom_sheet.dart';
import 'package:zerotrust_fitness/features/app/providers.dart';
import 'package:zerotrust_fitness/components/security_barrier.dart';
import 'package:flutter/services.dart';
import 'package:zerotrust_fitness/components/shimmer_loader.dart';
import 'package:zerotrust_fitness/components/hero_ring.dart';
import 'package:zerotrust_fitness/globals/app_state.dart';
import 'package:zerotrust_fitness/main.dart';

@NowaGenerated()
class DashboardPage extends StatefulWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() {
    return _DashboardPageState();
  }
}

@NowaGenerated()
class _DashboardPageState extends State<DashboardPage> {
  bool _isLoading = false;

  List<HealthDataPoint> _healthData = [];

  @override
  void initState() {
    super.initState();
    _loadHealthData();
  }

  Future<void> _loadHealthData() async {
    if (!mounted) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      final healthService = HealthService();
      final hasPermission = await healthService.requestPermissions();
      if (hasPermission) {
        final data = await healthService.fetchLatestData();
        if (!mounted) {
          return;
        }
        setState(() => _healthData = data);
      }
    } catch (e) {
      debugPrint('Error loading health data: ${e}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getMetricValue(HealthDataType type, {String unit = ''}) {
    final points = _healthData.where((p) => p.type == type).toList();
    if (points.isEmpty) {
      return '0';
    }
    double sum = 0;
    for (var p in points) {
      if (p.value is NumericHealthValue) {
        sum += (p.value as NumericHealthValue).numericValue;
      }
    }
    if (type == HealthDataType.STEPS) {
      return sum.toInt().toString();
    }
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


  Future<void> _unlockVault(dynamic ref) async {
    final passphraseController = TextEditingController();
    final passphrase = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlock Vault'),
        content: TextField(
          controller: passphraseController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Passphrase'),
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

    if (passphrase == null || passphrase.isEmpty) {
      return;
    }

    final unlocked = await ref
        .read(securityEnclaveProvider.notifier)
        .initialize(passphrase);

    if (!unlocked) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication failed.')),
        );
      }
      return;
    }

    final tasksInitialized = sharedPrefs.getBool('bg_tasks_initialized') ?? false;
    if (!tasksInitialized) {
      await AppState.of(context, listen: false).initializeBackgroundTasks();
      await sharedPrefs.setBool('bg_tasks_initialized', true);
    }

    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer(
      builder: (context, ref, child) {
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
                              progress: _getMetricProgress(
                                HealthDataType.STEPS,
                                10000,
                              ),
                              value: _getMetricValue(HealthDataType.STEPS),
                              color: const Color(0xFF6366F1),
                              icon: Icons.directions_walk,
                            ),
                            HeroRing(
                              label: 'Heart Points',
                              progress: _getMetricProgress(
                                HealthDataType.EXERCISE_TIME,
                                30,
                              ),
                              value: _getMetricValue(
                                HealthDataType.EXERCISE_TIME,
                                unit: 'pts',
                              ),
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
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
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
      },
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
              color: Colors.black.withValues(alpha: 0.2),
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
              backgroundColor: theme.colorScheme.secondary.withValues(
                alpha: 0.1,
              ),
              child: Icon(Icons.bolt, color: theme.colorScheme.secondary),
            ),
            title: Text(index == 0 ? 'High Intensity Run' : 'Morning Walk'),
            subtitle: const Text('Secured in local vault'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
              ),
              child: const Text(
                'VAULTED',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
