import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:zerotrust_fitness/core/storage/local_vault.dart';

class PrivacyDashboardPage extends StatefulWidget {
  const PrivacyDashboardPage({super.key, required this.secretKey});

  final SecretKey secretKey;

  @override
  State<PrivacyDashboardPage> createState() => _PrivacyDashboardPageState();
}

class _PrivacyDashboardPageState extends State<PrivacyDashboardPage> {
  Map<String, int> _counts = {};
  List<String> _recentAccess = [];
  bool _loading = true;

  static const _tableLabels = {
    'workouts': 'Workouts',
    'daily_metrics': 'Metric days',
    'achievements': 'Achievements',
    'user_goals': 'Goals',
    'backup_history': 'Backup events',
    'workout_templates': 'Templates',
    'access_log': 'Access log entries',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final counts =
          await LocalVault().fetchTableRowCounts(widget.secretKey);
      final log = await LocalVault().fetchAccessLog(widget.secretKey);
      final access = log
          .map((r) {
            final ts = DateTime.tryParse(r['accessed_at']?.toString() ?? '');
            if (ts == null) return null;
            return _fmtDateTime(ts.toLocal());
          })
          .whereType<String>()
          .toList();
      if (mounted) {
        setState(() {
          _counts = counts;
          _recentAccess = access;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtDateTime(DateTime dt) {
    final d = dt;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Dashboard')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Encryption notice
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined,
                          color: Colors.green, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'All data is encrypted with AES-256-GCM using your '
                          'master password. The developer has zero access to '
                          'your vault.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.green[700]),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Local storage summary
                Text('Local Storage',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: theme.hintColor)),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: _tableLabels.entries.map((e) {
                      final count = _counts[e.key] ?? 0;
                      return ListTile(
                        dense: true,
                        title: Text(e.value),
                        trailing: Text(
                          '$count',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // Backup status
                Text('Cloud Backup',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: theme.hintColor)),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.cloud_done_outlined),
                    title: const Text('Encrypted before upload'),
                    subtitle: const Text(
                      'Cloud sync uploads your vault as an encrypted blob. '
                      'Only you can decrypt it with your master password.',
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Recent vault access
                Text('Vault Access Log',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: theme.hintColor)),
                const SizedBox(height: 8),
                if (_recentAccess.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No access events recorded yet.',
                        style: TextStyle(
                            fontSize: 13, color: theme.hintColor)),
                  )
                else
                  Card(
                    child: Column(
                      children: _recentAccess.map((ts) {
                        return ListTile(
                          dense: true,
                          leading: Icon(Icons.lock_open_outlined,
                              size: 18, color: theme.hintColor),
                          title: Text(ts,
                              style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 20),

                // Data rights notice
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your Data Rights',
                          style: theme.textTheme.labelLarge),
                      const SizedBox(height: 8),
                      _bullet('You own all your data. It lives on your device.'),
                      _bullet('Export a full backup at any time from Export & Restore.'),
                      _bullet('Delete all local data from the Profile tab.'),
                      _bullet('Cloud data is deleted by removing your account.'),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
    );
  }

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
                child: Text(text,
                    style: const TextStyle(fontSize: 13))),
          ],
        ),
      );
}
