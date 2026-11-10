import 'package:flutter/material.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';

class PrivacyDashboardPage extends StatefulWidget {
  const PrivacyDashboardPage({super.key, required this.vault});

  final FitnessVault vault;

  @override
  State<PrivacyDashboardPage> createState() => _PrivacyDashboardPageState();
}

class _PrivacyDashboardPageState extends State<PrivacyDashboardPage> {
  Map<String, int> _counts = {};
  bool _loading = true;

  static const _tableLabels = {
    'workout': 'Workouts',
    'day': 'Metric days',
    'achievement': 'Medals',
    'goal': 'Goals',
    'template': 'Templates',
    'meal': 'Meals',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final counts = await widget.vault.countsByKind();
      if (mounted) {
        setState(() {
          _counts = counts;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
                          'Everything is encrypted on this phone with a key '
                          'only your password or recovery key can open. The '
                          'server, and the developer, see only ciphertext.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.green[700]),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Local storage summary
                Text('Stored in your vault',
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

                Card(
                  child: ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: const Text('How your data is protected'),
                    subtitle: const Text('Encryption, sync and what the server sees'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const ZtDataProtectionScreen()),
                    ),
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
                      _bullet('You own all your data. Only your devices can read it.'),
                      _bullet('Export a full backup at any time from Export & Restore.'),
                      _bullet('Delete activity data from Settings → Delete activity data.'),
                      _bullet('Deleting your account removes everything from the server.'),
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
