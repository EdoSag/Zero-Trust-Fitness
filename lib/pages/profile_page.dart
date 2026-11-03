import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zerotrust_fitness/core/services/supabase_service.dart';
import 'package:zerotrust_fitness/features/achievements/domain/achievement_service.dart';
import 'package:zerotrust_fitness/features/achievements/presentation/medal_chip.dart';
import 'package:zerotrust_fitness/globals/router.dart';
import 'package:zerotrust_fitness/pages/export_restore_page.dart';
import 'package:zerotrust_fitness/pages/goals_page.dart';
import 'package:zerotrust_fitness/pages/reminders_page.dart';
import 'package:zerotrust_fitness/core/utils/units_formatter.dart';
import 'package:zerotrust_fitness/pages/privacy_dashboard_page.dart';
import 'package:zerotrust_fitness/pages/share_report_page.dart';
import 'package:zerotrust_fitness/pages/templates_page.dart';

@NowaGenerated()
class ProfilePage extends StatefulWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const ProfilePage({
    super.key,
    required this.isSyncing,
    required this.isPulling,
    required this.isDeletingData,
    required this.onSync,
    required this.onPull,
    required this.onDeleteData,
    required this.earnedMedals,
    required this.onViewAllMedals,
    required this.autoLockMinutes,
    required this.onAutoLockChanged,
    this.secretKey,
  });

  final bool isSyncing;
  final bool isPulling;
  final bool isDeletingData;
  final Future<void> Function() onSync;
  final Future<void> Function() onPull;
  final Future<void> Function() onDeleteData;
  final List<UnlockedAchievement> earnedMedals;
  final VoidCallback onViewAllMedals;
  final int autoLockMinutes;
  final void Function(int minutes) onAutoLockChanged;
  final SecretKey? secretKey;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isSigningOut = false;
  DistanceUnit _distanceUnit = UnitsFormatter().distanceUnit;
  TimeFormat _timeFormat = UnitsFormatter().timeFormat;

  void _exitToOnboarding() {
    appRouter.go('/onboarding');
  }

  Future<void> _signOut() async {
    if (_isSigningOut) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      _exitToOnboarding();
      return;
    }

    setState(() => _isSigningOut = true);
    try {
      await SupabaseService().signOut();
      if (!mounted) return;
      _exitToOnboarding();
    } catch (e) {
      if (Supabase.instance.client.auth.currentUser == null && mounted) {
        _exitToOnboarding();
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign out failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
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

  static const _autoLockOptions = [0, 1, 5, 15];

  String _autoLockLabel(int minutes) => switch (minutes) {
        0 => 'Never',
        1 => 'After 1 minute',
        5 => 'After 5 minutes',
        15 => 'After 15 minutes',
        _ => 'After $minutes minutes',
      };

  Future<void> _showAutoLockPicker(BuildContext context) async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text('Auto-lock vault',
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._autoLockOptions.map(
              (m) => ListTile(
                title: Text(_autoLockLabel(m)),
                trailing: m == widget.autoLockMinutes
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(ctx, m),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen != null) widget.onAutoLockChanged(chosen);
  }

  Widget _buildMedalsCard(BuildContext context) {
    final theme = Theme.of(context);
    final medals = widget.earnedMedals.take(10).toList();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                onPressed: widget.onViewAllMedals,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'View All (${widget.earnedMedals.length})',
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

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'Not signed in';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: const Text('Account'),
              subtitle: Text(email),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Goals'),
              subtitle: const Text('Set daily and weekly targets'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const GoalsPage()),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Reminders'),
              subtitle: const Text('Movement, hydration, workout & sleep'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const RemindersPage()),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.library_books_outlined),
              title: const Text('Workout Templates'),
              subtitle: const Text('Create and reuse workout routines'),
              trailing: const Icon(Icons.chevron_right),
              onTap: widget.secretKey == null
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              TemplatesPage(secretKey: widget.secretKey!),
                        ),
                      ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy Dashboard'),
              subtitle: const Text('Storage summary, encryption status & access log'),
              trailing: const Icon(Icons.chevron_right),
              onTap: widget.secretKey == null
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PrivacyDashboardPage(
                              secretKey: widget.secretKey!),
                        ),
                      ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.straighten_outlined),
              title: const Text('Units & Format'),
              subtitle: Text(
                  '${_distanceUnit == DistanceUnit.metric ? 'Metric' : 'Imperial'} · '
                  '${_timeFormat == TimeFormat.h24 ? '24h' : '12h'}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showUnitsPicker(context),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_clock_outlined),
              title: const Text('Auto-lock'),
              subtitle: Text(_autoLockLabel(widget.autoLockMinutes)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showAutoLockPicker(context),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share Report'),
              subtitle: const Text('Generate a scoped health report to share'),
              trailing: const Icon(Icons.chevron_right),
              onTap: widget.secretKey == null
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ShareReportPage(secretKey: widget.secretKey!),
                        ),
                      ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.import_export_outlined),
              title: const Text('Export & Restore'),
              subtitle: const Text('Back up or restore your health data'),
              trailing: const Icon(Icons.chevron_right),
              onTap: widget.secretKey == null
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ExportRestorePage(
                              secretKey: widget.secretKey!),
                        ),
                      ),
            ),
          ),
          const SizedBox(height: 16),
          _buildMedalsCard(context),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: widget.isSyncing ? null : widget.onSync,
            icon: widget.isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(widget.isSyncing ? 'Syncing...' : 'Sync to Cloud'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: widget.isPulling ? null : widget.onPull,
            icon: widget.isPulling
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_download_outlined),
            label: Text(widget.isPulling ? 'Pulling...' : 'Pull from Cloud'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: widget.isDeletingData ? null : widget.onDeleteData,
            icon: widget.isDeletingData
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
            label: Text(
                widget.isDeletingData ? 'Deleting...' : 'Delete Data'),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _isSigningOut ? null : _signOut,
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            icon: _isSigningOut
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
            label: Text(_isSigningOut ? 'Signing out...' : 'Sign Out'),
          ),
        ],
      ),
    );
  }
}
