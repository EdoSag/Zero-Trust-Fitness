import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/components/compact_metric_card.dart';
import 'package:zerotrust_fitness/components/empty_state_widget.dart';
import 'package:zerotrust_fitness/components/shimmer_loader.dart';
import 'package:zerotrust_fitness/components/status_indicator.dart';
import 'package:zerotrust_fitness/features/dashboard/metric_card_specs.dart';
import 'package:zerotrust_fitness/components/insights_summary_card.dart';
import 'package:zerotrust_fitness/components/momentum_card.dart';
import 'package:zerotrust_fitness/features/health/domain/momentum_engine.dart';
import 'package:zerotrust_fitness/core/services/insights_service.dart';
import 'package:zerotrust_fitness/features/goals/goals_provider.dart';
import 'package:zerotrust_fitness/features/health/data/gps_tracking_service.dart';
import 'package:zerotrust_fitness/pages/all_metrics_page.dart';
import 'package:zerotrust_fitness/pages/metric_detail_page.dart';
import 'package:zerotrust_fitness/pages/water_food_page.dart';
import 'package:zerotrust_fitness/core/utils/units_formatter.dart';
import 'package:zerotrust_fitness/l10n/l10n.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({
    super.key,
    required this.todayMetrics,
    required this.heartPointsTotal,
    this.momentum,
    required this.isLoading,
    required this.syncStatus,
    required this.gpsSnapshot,
    required this.vault,
    required this.unreadableMetricKeys,
    required this.onToggleGps,
    required this.onManualEntry,
    required this.onRefresh,
    required this.onOpenPermissions,
    required this.onLock,
    this.goalsState,
    this.streaks,
    this.weeklySteps,
  });

  final Map<String, num> todayMetrics;
  final int heartPointsTotal;

  /// Null while the vault is locked.
  final MomentumResult? momentum;
  final bool isLoading;
  /// The core's shared sync status.
  final SyncStatus syncStatus;
  final GpsTrackingSnapshot gpsSnapshot;
  final FitnessVault? vault;
  final Set<String> unreadableMetricKeys;
  final Future<void> Function() onToggleGps;
  final VoidCallback onManualEntry;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenPermissions;
  final VoidCallback onLock;
  final GoalsState? goalsState;
  final StreakResult? streaks;
  final WeeklyComparison? weeklySteps;

  String _formatElapsed(Duration duration) {
    final mins = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${duration.inHours.toString().padLeft(2, '0')}:$mins:$secs';
  }

  Widget _buildStatusRow(BuildContext context) {
    final theme = Theme.of(context);
    final isUnlocked = vault != null;
    final syncing = syncStatus.isSyncing;
    final failed = syncStatus.error != null;
    final syncLabel = syncing
        ? context.l10n.syncing
        : failed
            ? context.l10n.notSynced
            : syncStatus.lastSyncedAt != null
                ? context.l10n.synced
                : context.l10n.syncPending;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          StatusIndicator(
            icon: isUnlocked ? Icons.lock_open_outlined : Icons.lock_outline,
            label: isUnlocked ? context.l10n.vaultUnlocked : context.l10n.vaultLocked,
            color: isUnlocked ? Colors.green : theme.colorScheme.error,
            semanticsLabel: isUnlocked
                ? context.l10n.vaultIsUnlockedAndData
                : context.l10n.vaultIsLockedTapUnlock,
          ),
          const SizedBox(width: 16),
          StatusIndicator(
            icon: syncing
                ? Icons.cloud_sync_outlined
                : failed
                    ? Icons.cloud_off_outlined
                    : Icons.cloud_done_outlined,
            label: syncLabel,
            color: syncing
                ? theme.colorScheme.primary
                : failed
                    ? theme.colorScheme.error
                    : theme.hintColor,
          ),
          if (gpsSnapshot.isTracking) ...[
            const SizedBox(width: 16),
            StatusIndicator(
              icon: Icons.gps_fixed,
              label: context.l10n.gpsActive,
              color: Colors.green,
              semanticsLabel: context.l10n.gpsTrackingIsActive,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricHighlights(ThemeData theme) {
    final steps = (todayMetrics['steps'] ?? 0).toInt().toString();
    final points =
        (todayMetrics['heart_points'] ?? heartPointsTotal).toInt().toString();
    return Row(
      children: [
        Expanded(
          child: StatCard(
            title: currentL10n.stepsToday,
            value: steps,
            icon: Icons.directions_walk,
            gradientColors: const [Color(0xFF3B82F6), Color(0xFF6366F1)],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            title: currentL10n.heartToday,
            value: points,
            icon: Icons.favorite,
            gradientColors: const [Color(0xFFF43F5E), Color(0xFFFB7185)],
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityMetrics(BuildContext context) {
    final theme = Theme.of(context);
    final specs = metricCardSpecs
        .where((s) => priorityMetricKeys.contains(s.key))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(context.l10n.keyMetrics, style: theme.textTheme.titleMedium),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AllMetricsPage(
                    todayMetrics: todayMetrics,
                    onManualEntry: onManualEntry,
                    vault: vault,
                  ),
                ),
              ),
              child: Text(context.l10n.moreMetrics),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: specs.map((spec) {
            final rawValue = todayMetrics[spec.key] ?? 0;
            final isUnreadable = unreadableMetricKeys.contains(spec.key);
            if (isUnreadable) {
              return SizedBox(
                width: (MediaQuery.of(context).size.width - 60) / 2,
                child: EmptyStateWidget.permissionRequired(
                  spec.title,
                  onGrant: onOpenPermissions,
                ),
              );
            }
            final progress = goalsState?.progressFor(spec.key, rawValue);
            final sk = vault;
            return SizedBox(
              width: (MediaQuery.of(context).size.width - 60) / 2,
              child: CompactMetricCard(
                title: spec.title,
                value: formatMetricValue(spec.key, rawValue, spec.unit),
                icon: spec.icon,
                gradientColors: spec.gradientColors,
                goalProgress: progress,
                onTap: sk == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => MetricDetailPage(
                              metricKey: spec.key,
                              metricTitle: spec.title,
                              unit: spec.unit,
                              gradientColors: spec.gradientColors,
                              vault: sk,
                            ),
                          ),
                        ),
              ),
            );
          }).toList(growable: false),
        ),
      ],
    );
  }

  /// Today's water and food, with a one-tap glass of water.
  Widget _buildWaterFood(BuildContext context) {
    final theme = Theme.of(context);
    final units = UnitsFormatter();
    final water = todayMetrics['water_l'] ?? 0;
    final goal = goalsState?.forKey('water_l')?.targetValue ??
        defaultWaterGoalLiters;
    final entries = (todayMetrics['nutrition_entries'] ?? 0).toInt();
    final glass = units.waterPresets.first;
    final sk = vault;
    void open(int tab) => Navigator.of(context).push(
          MaterialPageRoute<void>(
              builder: (_) => WaterFoodPage(initialTab: tab)),
        );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: sk == null ? null : () => open(0),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 4, 14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        value: goal <= 0
                            ? 0
                            : (water / goal).clamp(0.0, 1.0).toDouble(),
                        strokeWidth: 4,
                        color: const Color(0xFF0EA5E9),
                        backgroundColor:
                            const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(units.formatWater(water),
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          Text(context.l10n.water,
                              style: TextStyle(color: theme.hintColor)),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: context.l10n.addWaterAmount(glass.label.substring(1)),
                      icon: const Icon(Icons.add),
                      onPressed: sk == null
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              sk.addWater(
                                  FitnessVault.dateKeyOf(DateTime.now()),
                                  glass.liters);
                            },
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(width: 1, height: 48, color: theme.dividerColor),
          Expanded(
            child: InkWell(
              onTap: sk == null ? null : () => open(1),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  children: [
                    const Icon(Icons.restaurant_menu_outlined,
                        color: Color(0xFF22C55E), size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$entries',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          Text(entries == 1 ? context.l10n.foodEntry : context.l10n.foodEntries,
                              style: TextStyle(color: theme.hintColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGpsSection(ThemeData theme) {
    final isActive = gpsSnapshot.isTracking;
    return InkWell(
      onTap: onToggleGps,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isActive ? Icons.gps_fixed : Icons.directions_run,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isActive ? currentL10n.gpsWorkoutActive : currentL10n.startGpsWorkout,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isActive
                        ? '${(gpsSnapshot.distanceMeters / 1000).toStringAsFixed(2)} km · ${_formatElapsed(gpsSnapshot.elapsed)}'
                        : currentL10n.trackRoutePaceDistance,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zero-Trust Fitness'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: context.l10n.permissionsCenter,
            onPressed: onOpenPermissions,
          ),
          IconButton(
            icon: const Icon(Icons.lock_outline_rounded),
            tooltip: context.l10n.lockVault,
            onPressed: () async {
              HapticFeedback.heavyImpact();
              onLock();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: isLoading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 220, child: Center(child: ShimmerLoader())),
                ],
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusRow(context),
                    const SizedBox(height: 16),
                    if (streaks != null && weeklySteps != null) ...[
                      InsightsSummaryCard(
                        streaks: streaks!,
                        weeklySteps: weeklySteps!,
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildMetricHighlights(theme),
                    const SizedBox(height: 16),
                    if (momentum != null) ...[
                      MomentumCard(momentum: momentum!),
                      const SizedBox(height: 16),
                    ],
                    _buildPriorityMetrics(context),
                    const SizedBox(height: 16),
                    _buildWaterFood(context),
                    const SizedBox(height: 20),
                    _buildGpsSection(theme),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        // Today and Activities are both kept alive in the tab stack.
        heroTag: 'fab-today',
        onPressed: onManualEntry,
        tooltip: context.l10n.logAWorkoutOrHealth,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
