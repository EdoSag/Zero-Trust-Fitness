import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart' show Share;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zerotrust_fitness/core/services/background_backup_service.dart';
import 'package:zerotrust_fitness/core/services/export_service.dart';
import 'package:zerotrust_fitness/core/storage/local_vault.dart';
import 'package:zerotrust_fitness/globals/app_state.dart';

class ExportRestorePage extends StatefulWidget {
  const ExportRestorePage({super.key, required this.secretKey});

  final SecretKey secretKey;

  @override
  State<ExportRestorePage> createState() => _ExportRestorePageState();
}

class _ExportRestorePageState extends State<ExportRestorePage> {
  bool _exportingJson = false;
  bool _exportingCsv = false;
  bool _restoring = false;
  bool _generatingKit = false;

  List<Map<String, dynamic>> _backupHistory = [];
  bool _historyLoading = true;

  bool _autoBackupEnabled = false;
  int _autoBackupFreqDays = 1;
  bool _autoBackupLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadAutoBackupSettings();
  }

  Future<void> _loadHistory() async {
    try {
      final history =
          await LocalVault().fetchBackupHistory(widget.secretKey);
      if (mounted) setState(() => _backupHistory = history);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  Future<void> _exportJson() async {
    setState(() => _exportingJson = true);
    try {
      await ExportService().exportJson(widget.secretKey);
      await LocalVault().insertBackupHistory(
        backupType: 'json_export',
        status: 'success',
        secretKey: widget.secretKey,
      );
      await _loadHistory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingJson = false);
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _exportingCsv = true);
    try {
      await ExportService().exportCsv(widget.secretKey);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  Future<void> _restore() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final path = result.files.first.path;
    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read selected file.')),
        );
      }
      return;
    }

    String content;
    try {
      content = await File(path).readAsString();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to read file: $e')),
        );
      }
      return;
    }

    final preview = ExportService().parsePreview(content);
    if (preview == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Invalid or unsupported export file (version too new?).')),
        );
      }
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from backup?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'This will REPLACE all local data. This cannot be undone.'),
            const SizedBox(height: 12),
            _previewRow(
                'Exported', _formatDate(preview.exportedAt)),
            _previewRow('Workouts', '${preview.workoutCount}'),
            _previewRow('Metric days', '${preview.metricDayCount}'),
            _previewRow('Achievements', '${preview.achievementCount}'),
            _previewRow('Goals', '${preview.goalCount}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _restoring = true);
    try {
      final msg =
          await ExportService().restoreFromJson(content, widget.secretKey);
      await LocalVault().insertBackupHistory(
        backupType: 'json_restore',
        status: 'success',
        details: msg,
        secretKey: widget.secretKey,
      );
      await _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _loadAutoBackupSettings() async {
    final enabled = await BackgroundBackupService().isEnabled;
    final freq = await BackgroundBackupService().frequencyDays;
    if (mounted) {
      setState(() {
        _autoBackupEnabled = enabled;
        _autoBackupFreqDays = freq;
        _autoBackupLoading = false;
      });
    }
  }

  Future<void> _toggleAutoBackup(bool value) async {
    await BackgroundBackupService().setEnabled(value);
    if (value) {
      await AppState().scheduleVaultBackup(_autoBackupFreqDays);
    } else {
      await AppState().cancelVaultBackup();
    }
    if (mounted) setState(() => _autoBackupEnabled = value);
  }

  Future<void> _setAutoBackupFrequency(int days) async {
    await BackgroundBackupService().setFrequencyDays(days);
    if (_autoBackupEnabled) {
      await AppState().scheduleVaultBackup(days);
    }
    if (mounted) setState(() => _autoBackupFreqDays = days);
  }

  Future<void> _generateRecoveryKit() async {
    setState(() => _generatingKit = true);
    try {
      final email =
          Supabase.instance.client.auth.currentUser?.email ?? 'unknown';
      final now = _formatDate(DateTime.now());
      final kit = '''ZERO-TRUST HEALTH — RECOVERY KIT
Generated: $now
Account email: $email

IMPORTANT: This document does NOT contain your master password.
Your master password cannot be recovered — store it in a password manager.

HOW TO RESTORE YOUR DATA
─────────────────────────
1. Re-install Zero-Trust Health on your device.
2. Open the app and sign in with the email above.
3. Enter your master password to unlock the vault.
4. If restoring from a JSON backup file:
   a. Go to Profile → Export & Restore.
   b. Tap "Restore from JSON" and select your backup file.
   c. Review the preview and confirm.
5. If you have cloud sync enabled:
   a. After unlocking, tap "Pull from Cloud" on the Profile tab.
   b. Your latest cloud backup will be restored automatically.

WHAT IS ENCRYPTED
──────────────────
All workout data, health metrics, and goals are encrypted with your
master password using AES-256-GCM before leaving your device.
Anthropic and the app developer have zero access to your data.

NEED HELP?
───────────
If you lose your master password, your data cannot be recovered.
Contact support only for account-level issues (sign-in, cloud storage).
''';

      await Share.share(kit, subject: 'Zero-Trust Health Recovery Kit');
    } finally {
      if (mounted) setState(() => _generatingKit = false);
    }
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    return Card(
      child: ListTile(
        leading: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle,
            style:
                TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        trailing: loading ? null : const Icon(Icons.chevron_right),
        onTap: loading ? null : onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Export & Restore')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Export',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.hintColor)),
          const SizedBox(height: 8),
          _buildActionTile(
            icon: Icons.file_download_outlined,
            title: 'Export Full Backup (JSON)',
            subtitle:
                'All workouts, metrics, goals & achievements — re-importable',
            onTap: _exportJson,
            loading: _exportingJson,
          ),
          _buildActionTile(
            icon: Icons.table_chart_outlined,
            title: 'Export Metrics (CSV)',
            subtitle:
                'Daily health metrics spreadsheet — plaintext, for analysis',
            onTap: _exportCsv,
            loading: _exportingCsv,
          ),
          const SizedBox(height: 20),
          Text('Restore',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.hintColor)),
          const SizedBox(height: 8),
          _buildActionTile(
            icon: Icons.file_upload_outlined,
            title: 'Restore from JSON',
            subtitle:
                'Replace local data with a previous full backup — cannot be undone',
            onTap: _restore,
            loading: _restoring,
          ),
          const SizedBox(height: 20),
          Text('Recovery',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.hintColor)),
          const SizedBox(height: 8),
          _buildActionTile(
            icon: Icons.shield_outlined,
            title: 'Generate Recovery Kit',
            subtitle:
                'Shareable document with restore instructions — never contains your password',
            onTap: _generatingKit ? null : _generateRecoveryKit,
            loading: _generatingKit,
          ),
          const SizedBox(height: 20),
          Text('Automatic Backups',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.hintColor)),
          const SizedBox(height: 8),
          Card(
            child: _autoBackupLoading
                ? const ListTile(
                    leading: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    title: Text('Loading…'),
                  )
                : Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.cloud_sync_outlined),
                        title: const Text('Auto backup to cloud'),
                        subtitle: const Text(
                          'Encrypts and uploads your vault on a schedule',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: _autoBackupEnabled,
                        onChanged: _toggleAutoBackup,
                      ),
                      if (_autoBackupEnabled) ...[
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.schedule_outlined),
                          title: const Text('Frequency'),
                          trailing: DropdownButton<int>(
                            value: _autoBackupFreqDays,
                            underline: const SizedBox.shrink(),
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('Daily')),
                              DropdownMenuItem(
                                  value: 7, child: Text('Weekly')),
                            ],
                            onChanged: (v) {
                              if (v != null) _setAutoBackupFrequency(v);
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 20),
          Text('History',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.hintColor)),
          const SizedBox(height: 8),
          if (_historyLoading)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else if (_backupHistory.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No export or restore history yet.',
                  style:
                      TextStyle(fontSize: 13, color: theme.hintColor)),
            )
          else
            ..._backupHistory.map((row) {
              final type = row['backup_type']?.toString() ?? '';
              final status = row['status']?.toString() ?? '';
              final createdAt = row['created_at']?.toString() ?? '';
              final dt = DateTime.tryParse(createdAt)?.toLocal();
              final label = switch (type) {
                'json_export' => 'JSON Export',
                'csv_export' => 'CSV Export',
                'json_restore' => 'JSON Restore',
                'cloud_sync' => 'Cloud Sync',
                String() => type,
              };
              return ListTile(
                dense: true,
                leading: Icon(
                  status == 'success'
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  color:
                      status == 'success' ? Colors.green : Colors.redAccent,
                  size: 20,
                ),
                title: Text(label, style: const TextStyle(fontSize: 13)),
                subtitle: dt != null
                    ? Text(_formatDate(dt),
                        style:
                            TextStyle(fontSize: 11, color: theme.hintColor))
                    : null,
                trailing: Text(status,
                    style: TextStyle(
                        fontSize: 11,
                        color: status == 'success'
                            ? Colors.green
                            : Colors.redAccent)),
              );
            }),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}
