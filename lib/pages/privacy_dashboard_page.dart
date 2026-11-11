import 'package:flutter/material.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/l10n/l10n.dart';

class PrivacyDashboardPage extends StatefulWidget {
  const PrivacyDashboardPage({super.key, required this.vault});

  final FitnessVault vault;

  @override
  State<PrivacyDashboardPage> createState() => _PrivacyDashboardPageState();
}

class _PrivacyDashboardPageState extends State<PrivacyDashboardPage> {
  Map<String, int> _counts = {};
  bool _loading = true;

  Map<String, String> get _tableLabels => {
    'workout': context.l10n.workouts,
    'day': context.l10n.metricDays,
    'achievement': context.l10n.medals,
    'goal': context.l10n.goals,
    'template': context.l10n.templates,
    'meal': context.l10n.meals,
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
      appBar: AppBar(title: Text(context.l10n.privacyDashboard)),
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
                          context.l10n.everythingIsEncryptedOnThis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.green[700]),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Local storage summary
                Text(context.l10n.storedInYourVault,
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
                    title: Text(context.l10n.howYourDataIsProtected),
                    subtitle: Text(context.l10n.encryptionSyncAndWhatThe),
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
                      Text(context.l10n.yourDataRights,
                          style: theme.textTheme.labelLarge),
                      const SizedBox(height: 8),
                      _bullet(context.l10n.youOwnAllYourData),
                      _bullet(context.l10n.exportAFullBackupAt),
                      _bullet(context.l10n.deleteActivityDataFromSettings),
                      _bullet(context.l10n.deletingYourAccountRemovesEverything),
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
