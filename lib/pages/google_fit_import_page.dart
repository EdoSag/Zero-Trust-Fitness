import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/features/import/google_fit_takeout.dart';

/// Brings a person's Google Fit history in from a Google Takeout export:
/// daily steps, Heart Points and weight, and every workout (with its GPS
/// route when Google kept one). The file is read on the phone; nothing is
/// uploaded except the encrypted result, like everything else.
class GoogleFitImportPage extends ConsumerStatefulWidget {
  const GoogleFitImportPage({super.key, required this.vault});

  final FitnessVault vault;

  @override
  ConsumerState<GoogleFitImportPage> createState() =>
      _GoogleFitImportPageState();
}

class _GoogleFitImportPageState extends ConsumerState<GoogleFitImportPage> {
  FitTakeout? _preview;
  bool _reading = false;
  bool _importing = false;
  double? _progress;
  FitImportResult? _result;
  String? _error;

  Future<void> _pick() async {
    final files = await ref
        .read(vaultControllerProvider.notifier)
        .whileShowingSystemUi(() => FilePicker.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['zip', 'csv', 'json', 'tcx'],
            ));
    final paths = [for (final f in files) if (f.path case final p?) p];
    if (paths.isEmpty) return;
    setState(() {
      _reading = true;
      _error = null;
      _preview = null;
      _result = null;
    });
    try {
      // Off the UI thread: a Takeout zip can be large.
      final takeout = await Isolate.run(() => readTakeoutFiles(paths));
      if (!mounted) return;
      setState(() {
        _preview = takeout;
        if (takeout.isEmpty) {
          _error = 'No Google Fit data found in that file. Choose the '
              'Takeout .zip, or the "Daily activity metrics.csv" file from '
              'its Fit folder.';
        }
      });
    } on Object catch (e) {
      if (mounted) setState(() => _error = 'Couldn\'t read that file ($e).');
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _import() async {
    final takeout = _preview;
    if (takeout == null) return;
    setState(() {
      _importing = true;
      _progress = 0;
    });
    try {
      final result = await importFitTakeout(
        widget.vault,
        takeout,
        onProgress: (done, total) {
          if (mounted && (done % 25 == 0 || done == total)) {
            setState(() => _progress = total == 0 ? 1 : done / total);
          }
        },
      );
      if (mounted) {
        setState(() {
          _result = result;
          _preview = null;
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = 'Import failed: ${ztErrorMessage(e)}');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _preview;
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Import from Google Fit')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Bring your Google Fit history with you',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            '1. Go to takeout.google.com and choose only "Fit".\n'
            '2. Download the .zip Google emails you.\n'
            '3. Choose it here (or the "Daily activity metrics.csv" inside).',
          ),
          const SizedBox(height: 8),
          Text(
            'The file is read on this phone. Your steps, Heart Points, weight '
            'and workouts are added to your encrypted vault, and days already '
            'counted aren\'t counted twice. Importing again adds nothing new.',
            style: TextStyle(color: theme.hintColor),
          ),
          const SizedBox(height: 24),
          if (_reading || _importing) ...[
            LinearProgressIndicator(value: _importing ? _progress : null),
            const SizedBox(height: 8),
            Text(_importing ? 'Adding to your vault…' : 'Reading the export…'),
          ] else if (result != null) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text('Added ${result.workoutsAdded} workouts and '
                  '${result.days} days'),
              subtitle: result.workoutsSkipped > 0
                  ? Text('${result.workoutsSkipped} workouts were already here')
                  : null,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Done'),
            ),
          ] else if (preview != null && !preview.isEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Found', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('${preview.sessions.length} workouts'
                        '${_range(preview.sessions.map((s) => s.start))}'),
                    Text('${preview.days.length} days of steps and Heart Points'
                        '${_range(preview.days.keys.map(DateTime.parse))}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _import,
              icon: const Icon(Icons.download_done),
              label: const Text('Import'),
            ),
            TextButton(onPressed: _pick, child: const Text('Choose another file')),
          ] else
            FilledButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.folder_open),
              label: const Text('Choose Takeout file'),
            ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ],
      ),
    );
  }

  static String _range(Iterable<DateTime> dates) {
    if (dates.isEmpty) return '';
    final sorted = dates.toList()..sort();
    String y(DateTime d) => '${d.year}';
    final a = y(sorted.first), b = y(sorted.last);
    return a == b ? ' ($a)' : ' ($a to $b)';
  }
}

/// Reads the picked files (a Takeout zip, or loose CSV/JSON/TCX files) into
/// a [FitTakeout]. Only the Fit files inside a zip are unpacked.
FitTakeout readTakeoutFiles(List<String> paths) {
  final texts = <String, String>{};
  for (final path in paths) {
    if (path.toLowerCase().endsWith('.zip')) {
      final input = InputFileStream(path);
      try {
        final archive = ZipDecoder().decodeStream(input);
        for (final file in archive) {
          if (!file.isFile || !GoogleFitTakeoutParser.isRelevant(file.name)) {
            continue;
          }
          texts[file.name] = utf8.decode(file.content, allowMalformed: true);
          file.closeSync();
        }
      } finally {
        input.closeSync();
      }
    } else if (RegExp(r'\.(csv|json|tcx)$').hasMatch(path.toLowerCase())) {
      // Loose files the person picked themselves.
      texts[path] = File(path).readAsStringSync();
    }
  }
  return GoogleFitTakeoutParser.parse(texts);
}
