import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zerotrust_fitness/core/services/supabase_service.dart';
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
  });

  final bool isSyncing;
  final bool isPulling;
  final bool isDeletingData;
  final Future<void> Function() onSync;
  final Future<void> Function() onPull;
  final Future<void> Function() onDeleteData;

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
            label: Text(widget.isDeletingData ? 'Deleting...' : 'Delete Data'),
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
