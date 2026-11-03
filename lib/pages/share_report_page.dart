import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:zerotrust_fitness/core/services/export_service.dart';
import 'package:zerotrust_fitness/features/dashboard/metric_card_specs.dart';

class ShareReportPage extends StatefulWidget {
  const ShareReportPage({super.key, required this.secretKey});

  final SecretKey secretKey;

  @override
  State<ShareReportPage> createState() => _ShareReportPageState();
}

class _ShareReportPageState extends State<ShareReportPage> {
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  final Set<String> _selectedKeys = {'steps', 'sleep_asleep_min', 'resting_hr', 'weight'};
  bool _generating = false;

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (picked != null && mounted) setState(() => _range = picked);
  }

  Future<void> _generate() async {
    if (_selectedKeys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one metric.')),
      );
      return;
    }
    setState(() => _generating = true);
    try {
      await ExportService().generateShareableReport(
        secretKey: widget.secretKey,
        metricKeys: _selectedKeys.toList(),
        dateRange: _range,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  String _fmtDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Share Report')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.date_range_outlined),
              title: const Text('Date range'),
              subtitle: Text('${_fmtDate(_range.start)} – ${_fmtDate(_range.end)}'),
              trailing: TextButton(
                onPressed: _pickRange,
                child: const Text('Change'),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Metrics to include',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.hintColor)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: metricCardSpecs.map((spec) {
              final selected = _selectedKeys.contains(spec.key);
              return FilterChip(
                label: Text(spec.title),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _selectedKeys.add(spec.key);
                    } else {
                      _selectedKeys.remove(spec.key);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 18, color: theme.hintColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The report is a plain-text file — not encrypted. '
                    'Only share with people you trust. '
                    'Informational only — not medical advice.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _generating ? null : _generate,
            icon: _generating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.share_outlined),
            label: Text(_generating ? 'Generating…' : 'Generate & Share'),
          ),
        ],
      ),
    );
  }
}
