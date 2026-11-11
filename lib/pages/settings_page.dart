import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_fitness/app/vault_providers.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/core/utils/units_formatter.dart';
import 'package:zerotrust_fitness/features/achievements/domain/achievement_service.dart';
import 'package:zerotrust_fitness/features/achievements/presentation/achievements_page.dart';
import 'package:zerotrust_fitness/features/achievements/presentation/medal_chip.dart';
import 'package:zerotrust_fitness/features/health/data/health_writeback.dart';
import 'package:zerotrust_fitness/features/wear/wear_companion.dart';
import 'package:zerotrust_fitness/pages/export_restore_page.dart';
import 'package:zerotrust_fitness/pages/google_fit_import_page.dart';
import 'package:zerotrust_fitness/pages/goals_page.dart';
import 'package:zerotrust_fitness/pages/gpx_import_page.dart';
import 'package:zerotrust_fitness/pages/offline_maps_page.dart';
import 'package:zerotrust_fitness/pages/permissions_page.dart';
import 'package:zerotrust_fitness/pages/privacy_dashboard_page.dart';
import 'package:zerotrust_fitness/pages/reminders_page.dart';
import 'package:zerotrust_fitness/pages/share_report_page.dart';
import 'package:zerotrust_fitness/pages/templates_page.dart';
import 'package:zerotrust_fitness/l10n/l10n.dart';

/// The shared Zero-Trust settings (account, security, auto-lock, appearance,
/// sync, other apps), plus Fitness' own rows.
class FitnessSettingsPage extends ConsumerStatefulWidget {
  const FitnessSettingsPage({
    super.key,
    required this.earnedMedals,
    required this.onDataDeleted,
  });

  final List<UnlockedAchievement> earnedMedals;

  /// Called after "Delete activity data", so the dashboard reloads.
  final VoidCallback onDataDeleted;

  @override
  ConsumerState<FitnessSettingsPage> createState() =>
      _FitnessSettingsPageState();
}

class _FitnessSettingsPageState extends ConsumerState<FitnessSettingsPage> {
  DistanceUnit _distanceUnit = UnitsFormatter().distanceUnit;
  TimeFormat _timeFormat = UnitsFormatter().timeFormat;
  bool _deleting = false;
  bool _writeback = false;
  bool _writebackBusy = false;
  bool _watch = false;

  @override
  void initState() {
    super.initState();
    HealthWriteback.instance.isEnabled.then((on) {
      if (mounted) setState(() => _writeback = on);
    });
    WearCompanion.instance.isEnabled.then((on) {
      if (mounted) setState(() => _watch = on);
    });
  }

  Future<void> _setWriteback(bool on) async {
    final healthName = Theme.of(context).platform == TargetPlatform.iOS
        ? 'Apple Health'
        : 'Health Connect';
    setState(() => _writebackBusy = true);
    try {
      if (!on) {
        await HealthWriteback.instance.disable();
        if (mounted) setState(() => _writeback = false);
        return;
      }
      final granted = await ref
          .read(vaultControllerProvider.notifier)
          .whileShowingSystemUi(HealthWriteback.instance.enable);
      if (!mounted) return;
      setState(() => _writeback = granted);
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.l10n.healthDidntAllow(healthName))));
        return;
      }
      final vault = ref.read(openFitnessVaultProvider);
      if (vault == null) return;
      final copyPast = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.l10n.copyPastWorkoutsToo),
          content: Text(context.l10n.newWorkoutsSavedTo(healthName)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.l10n.onlyNewOnes)),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(context.l10n.copyThem)),
          ],
        ),
      );
      if (copyPast != true) return;
      final count = await HealthWriteback.instance.backfill(vault);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.l10n.copiedWorkoutsTo(count, healthName))));
      }
    } finally {
      if (mounted) setState(() => _writebackBusy = false);
    }
  }

  List<UnlockedAchievement> get _medals => widget.earnedMedals;

  void _openMedals() => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AchievementsPage()),
      );

  void _push(Widget Function(FitnessVault vault) page) {
    final vault = ref.read(openFitnessVaultProvider);
    if (vault == null) return;
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page(vault)));
  }

  Future<void> _showUnitsPicker(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.unitsFormat,
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 12),
                Text(context.l10n.distance,
                    style: Theme.of(ctx)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: Theme.of(ctx).hintColor)),
                RadioListTile<DistanceUnit>(
                  title: Text(context.l10n.metricKmKg),
                  value: DistanceUnit.metric,
                  groupValue: _distanceUnit,
                  onChanged: (v) async {
                    await UnitsFormatter().setDistanceUnit(v!);
                    setSheet(() {});
                    if (mounted) setState(() => _distanceUnit = v);
                  },
                ),
                RadioListTile<DistanceUnit>(
                  title: Text(context.l10n.imperialMiLbs),
                  value: DistanceUnit.imperial,
                  groupValue: _distanceUnit,
                  onChanged: (v) async {
                    await UnitsFormatter().setDistanceUnit(v!);
                    setSheet(() {});
                    if (mounted) setState(() => _distanceUnit = v);
                  },
                ),
                const SizedBox(height: 8),
                Text(context.l10n.timeFormat,
                    style: Theme.of(ctx)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: Theme.of(ctx).hintColor)),
                RadioListTile<TimeFormat>(
                  title: const Text('24-hour'),
                  value: TimeFormat.h24,
                  groupValue: _timeFormat,
                  onChanged: (v) async {
                    await UnitsFormatter().setTimeFormat(v!);
                    setSheet(() {});
                    if (mounted) setState(() => _timeFormat = v);
                  },
                ),
                RadioListTile<TimeFormat>(
                  title: Text(context.l10n.s12HourAmPm),
                  value: TimeFormat.h12,
                  groupValue: _timeFormat,
                  onChanged: (v) async {
                    await UnitsFormatter().setTimeFormat(v!);
                    setSheet(() {});
                    if (mounted) setState(() => _timeFormat = v);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMedalsCard(BuildContext context) {
    final theme = Theme.of(context);
    final medals = _medals.take(10).toList();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
              ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_outlined, size: 18),
              const SizedBox(width: 8),
              Text(
                context.l10n.medals,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _openMedals,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  context.l10n.viewAllCount(_medals.length),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (medals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                context.l10n.noMedalsYetKeepMoving,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            )
          else
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: medals.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) => MedalChip(
                  definition: medals[i].definition,
                  size: 64,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteActivityData() async {
    final vault = ref.read(openFitnessVaultProvider);
    if (vault == null || _deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.deleteActivityData),
        content: Text(
          context.l10n.deletesYourWorkoutsDailyMetrics,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deleting = true);
    try {
      await vault.clearActivityData();
      widget.onDataDeleted();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.activityDataDeleted)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ztErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = ref.watch(openFitnessVaultProvider) != null;
    return ZtSettingsPage(
      onSignedOut: () =>
          Navigator.of(context).popUntil((route) => route.isFirst),
      showSyncStatus: true,
      appSection: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: _buildMedalsCard(context),
        ),
        ListTile(
          leading: const Icon(Icons.flag_outlined),
          title: Text(context.l10n.goals),
          subtitle: Text(context.l10n.setDailyAndWeeklyTargets),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const GoalsPage()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: Text(context.l10n.reminders),
          subtitle: Text(context.l10n.weeklySummaryMovementWaterWorkouts),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const RemindersPage()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.library_books_outlined),
          title: Text(context.l10n.workoutTemplates),
          subtitle: Text(context.l10n.createAndReuseWorkoutRoutines),
          enabled: unlocked,
          onTap: () => _push((v) => TemplatesPage(vault: v)),
        ),
        ListTile(
          leading: const Icon(Icons.health_and_safety_outlined),
          title: Text(context.l10n.healthPermissions),
          subtitle: Text(context.l10n.chooseWhatFitnessMayRead),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const PermissionsPage()),
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.sync_alt),
          title: Text(Theme.of(context).platform == TargetPlatform.iOS
              ? context.l10n.saveWorkoutsToAppleHealth
              : context.l10n.saveWorkoutsToHealthConnect),
          subtitle: Text(
              context.l10n.workoutsYouLogOrRecord),
          value: _writeback,
          onChanged: _writebackBusy || !unlocked ? null : _setWriteback,
        ),
        if (Theme.of(context).platform == TargetPlatform.android)
          SwitchListTile(
            secondary: const Icon(Icons.watch_outlined),
            title: Text(context.l10n.showOnWearOsWatch),
            subtitle: Text(
                context.l10n.todaysHeartPointsStepsAnd),
            value: _watch,
            onChanged: (on) async {
              await WearCompanion.instance.setEnabled(on);
              if (mounted) setState(() => _watch = on);
            },
          ),
        ListTile(
          leading: const Icon(Icons.straighten_outlined),
          title: Text(context.l10n.unitsFormatX),
          subtitle: Text(
              '${_distanceUnit == DistanceUnit.metric ? context.l10n.unitMetric : context.l10n.unitImperial} · '
              '${_timeFormat == TimeFormat.h24 ? '24h' : '12h'}'),
          onTap: () => _showUnitsPicker(context),
        ),
        ListTile(
          leading: const Icon(Icons.map_outlined),
          title: Text(context.l10n.offlineMaps),
          subtitle: Text(context.l10n.keepRouteMapsOnThis),
          enabled: unlocked,
          onTap: () => _push((v) => OfflineMapsPage(vault: v)),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: Text(context.l10n.privacyDashboardX),
          subtitle: Text(context.l10n.whatYourVaultHoldsAnd),
          enabled: unlocked,
          onTap: () => _push((v) => PrivacyDashboardPage(vault: v)),
        ),
      ],
      backupSection: [
        ListTile(
          leading: const Icon(Icons.import_export_outlined),
          title: Text(context.l10n.exportRestoreX),
          subtitle: Text(context.l10n.backUpToAFile),
          enabled: unlocked,
          onTap: () => _push((v) => ExportRestorePage(vault: v)),
        ),
        ListTile(
          leading: const Icon(Icons.move_to_inbox_outlined),
          title: Text(context.l10n.importFromGoogleFit),
          subtitle: Text(context.l10n.yourHistoryFromAGoogle),
          enabled: unlocked,
          onTap: () => _push((v) => GoogleFitImportPage(vault: v)),
        ),
        ListTile(
          leading: const Icon(Icons.route_outlined),
          title: Text(context.l10n.importGpxRoutes),
          subtitle: Text(context.l10n.fromStravaKomootGarminAnd),
          enabled: unlocked,
          onTap: () => _push((v) => GpxImportPage(vault: v)),
        ),
        ListTile(
          leading: const Icon(Icons.share_outlined),
          title: Text(context.l10n.shareReport),
          subtitle: Text(context.l10n.aScopedHealthReportTo),
          enabled: unlocked,
          onTap: () => _push((v) => ShareReportPage(vault: v)),
        ),
        ListTile(
          leading: Icon(Icons.delete_outline,
              color: Theme.of(context).colorScheme.error),
          title: Text(context.l10n.deleteActivityDataX),
          subtitle: Text(context.l10n.workoutsMetricsAndMedalsOn),
          enabled: unlocked && !_deleting,
          onTap: _deleteActivityData,
        ),
      ],
    );
  }
}
