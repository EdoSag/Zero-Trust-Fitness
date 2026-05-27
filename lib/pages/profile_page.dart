import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zerotrust_fitness/core/services/supabase_service.dart';
import 'package:zerotrust_fitness/features/achievements/domain/achievement_service.dart';
import 'package:zerotrust_fitness/features/achievements/presentation/medal_chip.dart';
import 'package:zerotrust_fitness/globals/router.dart';

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
  });

  final bool isSyncing;
  final bool isPulling;
  final bool isDeletingData;
  final Future<void> Function() onSync;
  final Future<void> Function() onPull;
  final Future<void> Function() onDeleteData;
  final List<UnlockedAchievement> earnedMedals;
  final VoidCallback onViewAllMedals;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isSigningOut = false;

  void _exitToOnboarding() {
    appRouter.go('/onboarding');
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
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
