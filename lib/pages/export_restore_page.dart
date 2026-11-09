import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_fitness/core/services/export_service.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';

/// Export to a file, or bring a file back in. Cloud backup is no longer a
/// separate step: every change is synced, encrypted, as it happens.
class ExportRestorePage extends ConsumerStatefulWidget {
  const ExportRestorePage({super.key, required this.vault});

  final FitnessVault vault;

  @override
  ConsumerState<ExportRestorePage> createState() => _ExportRestorePageState();
}

class _ExportRestorePageState extends ConsumerState<ExportRestorePage> {
  bool _exportingJson = false;
  bool _exportingCsv = false;
  bool _restoring = false;

  /// Share sheets and file pickers send the app to the background; keep the
  /// vault from auto-locking under them.
  Future<R> _systemUi<R>(Future<R> Function() action) => ref
      .read(vaultControllerProvider.notifier)
      .whileShowingSystemUi(action);

  Future<void> _exportJson() async {
    setState(() => _exportingJson = true);
    try {
      await _systemUi(() => ExportService().exportJson(widget.vault));
    } catch (e) {
      _snack('Export failed: ${ztErrorMessage(e)}');
    } finally {
      if (mounted) setState(() => _exportingJson = false);
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _exportingCsv = true);
    try {
      await _systemUi(() => ExportService().exportCsv(widget.vault));
    } catch (e) {
      _snack('Export failed: ${ztErrorMessage(e)}');
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  Future<void> _restore() async {
    final result = await _systemUi(() => FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
        ));
    if (result.isEmpty) return;

    final path = result.first.path;
    if (path == null) {
      _snack('Could not read selected file.');
      return;
    }

    String content;
    try {
      content = await File(path).readAsString();
    } catch (e) {
      _snack('Failed to read file.');
      return;
    }

    final preview = ExportService().parsePreview(content);
    if (preview == null) {
      _snack('Invalid or unsupported export file (version too new?).');
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
                'Workouts missing here are added, days in the file replace '
                'the same days here, and goals are set. It syncs to your '
                'other devices.'),
            const SizedBox(height: 12),
            _previewRow('Exported', _formatDate(preview.exportedAt)),
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
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _restoring = true);
    try {
      final msg = await ExportService().restoreFromJson(content, widget.vault);
      _snack(msg);
    } catch (e) {
      _snack('Restore failed: ${ztErrorMessage(e)}');
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
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
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
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
              style: theme.textTheme.titleSmall?.copyWith(color: theme.hintColor)),
          const SizedBox(height: 8),
          _buildActionTile(
            icon: Icons.file_download_outlined,
            title: 'Export full backup (JSON)',
            subtitle:
                'All workouts, metrics, goals and medals. Not encrypted: keep it safe.',
            onTap: _exportJson,
            loading: _exportingJson,
          ),
          _buildActionTile(
            icon: Icons.table_chart_outlined,
            title: 'Export metrics (CSV)',
            subtitle: 'Daily health metrics as a spreadsheet, for analysis',
            onTap: _exportCsv,
            loading: _exportingCsv,
          ),
          const SizedBox(height: 20),
          Text('Restore',
              style: theme.textTheme.titleSmall?.copyWith(color: theme.hintColor)),
          const SizedBox(height: 8),
          _buildActionTile(
            icon: Icons.file_upload_outlined,
            title: 'Restore from JSON',
            subtitle: 'Bring a full backup back in. Nothing here is deleted.',
            onTap: _restore,
            loading: _restoring,
          ),
          const SizedBox(height: 20),
          Text(
            'Your data is synced, end-to-end encrypted, to your other devices '
            'as you go. To be able to get back in if you forget your password, '
            'keep your recovery key safe (Settings → New recovery key).',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}
