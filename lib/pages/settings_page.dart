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

  @override
  void initState() {
    super.initState();
    HealthWriteback.instance.isEnabled.then((on) {
      if (mounted) setState(() => _writeback = on);
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
            content: Text('$healthName didn\'t allow Fitness to save workouts.')));
        return;
      }
      final vault = ref.read(openFitnessVaultProvider);
      if (vault == null) return;
      final copyPast = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Copy past workouts too?'),
          content: Text('New workouts are saved to $healthName from now on. '
              'Fitness can also copy the workouts already in your journal.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Only new ones')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Copy them')),
          ],
        ),
      );
      if (copyPast != true) return;
      final count = await HealthWriteback.instance.backfill(vault);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Copied $count workouts to $healthName.')));
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
                Text('Units & Format',
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 12),
                Text('Distance',
                    style: Theme.of(ctx)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: Theme.of(ctx).hintColor)),
                RadioListTile<DistanceUnit>(
                  title: const Text('Metric (km, kg)'),
                  value: DistanceUnit.metric,
                  groupValue: _distanceUnit,
                  onChanged: (v) async {
                    await UnitsFormatter().setDistanceUnit(v!);
                    setSheet(() {});
                    if (mounted) setState(() => _distanceUnit = v);
                  },
                ),
                RadioListTile<DistanceUnit>(
                  title: const Text('Imperial (mi, lbs)'),
                  value: DistanceUnit.imperial,
                  groupValue: _distanceUnit,
                  onChanged: (v) async {
                    await UnitsFormatter().setDistanceUnit(v!);
                    setSheet(() {});
                    if (mounted) setState(() => _distanceUnit = v);
                  },
                ),
                const SizedBox(height: 8),
                Text('Time format',
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
                  title: const Text('12-hour (AM/PM)'),
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
                'Medals',
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
                  'View All (${_medals.length})',
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
                'No medals yet — keep moving!',
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
        title: const Text('Delete activity data?'),
        content: const Text(
          'Deletes your workouts, daily metrics and medals on every device '
          'signed in to this account. Goals and templates stay. Health '
          'Connect data on the phone is not touched. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
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
          const SnackBar(content: Text('Activity data deleted.')),
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
          title: const Text('Goals'),
          subtitle: const Text('Set daily and weekly targets'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const GoalsPage()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: const Text('Reminders'),
          subtitle: const Text('Weekly summary, movement, water, workouts & sleep'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const RemindersPage()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.library_books_outlined),
          title: const Text('Workout templates'),
          subtitle: const Text('Create and reuse workout routines'),
          enabled: unlocked,
          onTap: () => _push((v) => TemplatesPage(vault: v)),
        ),
        ListTile(
          leading: const Icon(Icons.health_and_safety_outlined),
          title: const Text('Health permissions'),
          subtitle: const Text('Choose what Fitness may read'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const PermissionsPage()),
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.sync_alt),
          title: Text(Theme.of(context).platform == TargetPlatform.iOS
              ? 'Save workouts to Apple Health'
              : 'Save workouts to Health Connect'),
          subtitle: const Text(
              'Workouts you log or record here show up in your other apps'),
          value: _writeback,
          onChanged: _writebackBusy || !unlocked ? null : _setWriteback,
        ),
        ListTile(
          leading: const Icon(Icons.straighten_outlined),
          title: const Text('Units & format'),
          subtitle: Text(
              '${_distanceUnit == DistanceUnit.metric ? 'Metric' : 'Imperial'} · '
              '${_timeFormat == TimeFormat.h24 ? '24h' : '12h'}'),
          onTap: () => _showUnitsPicker(context),
        ),
        ListTile(
          leading: const Icon(Icons.map_outlined),
          title: const Text('Offline maps'),
          subtitle: const Text('Keep route maps on this phone'),
          enabled: unlocked,
          onTap: () => _push((v) => OfflineMapsPage(vault: v)),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Privacy dashboard'),
          subtitle: const Text('What your vault holds and how it is protected'),
          enabled: unlocked,
          onTap: () => _push((v) => PrivacyDashboardPage(vault: v)),
        ),
      ],
      backupSection: [
        ListTile(
          leading: const Icon(Icons.import_export_outlined),
          title: const Text('Export & restore'),
          subtitle: const Text('Back up to a file or bring a backup back in'),
          enabled: unlocked,
          onTap: () => _push((v) => ExportRestorePage(vault: v)),
        ),
        ListTile(
          leading: const Icon(Icons.move_to_inbox_outlined),
          title: const Text('Import from Google Fit'),
          subtitle: const Text('Your history from a Google Takeout export'),
          enabled: unlocked,
          onTap: () => _push((v) => GoogleFitImportPage(vault: v)),
        ),
        ListTile(
          leading: const Icon(Icons.route_outlined),
          title: const Text('Import GPX routes'),
          subtitle: const Text('From Strava, Komoot, Garmin and others'),
          enabled: unlocked,
          onTap: () => _push((v) => GpxImportPage(vault: v)),
        ),
        ListTile(
          leading: const Icon(Icons.share_outlined),
          title: const Text('Share report'),
          subtitle: const Text('A scoped health report to share'),
          enabled: unlocked,
          onTap: () => _push((v) => ShareReportPage(vault: v)),
        ),
        ListTile(
          leading: Icon(Icons.delete_outline,
              color: Theme.of(context).colorScheme.error),
          title: const Text('Delete activity data'),
          subtitle: const Text('Workouts, metrics and medals, on every device'),
          enabled: unlocked && !_deleting,
          onTap: _deleteActivityData,
        ),
      ],
    );
  }
}
