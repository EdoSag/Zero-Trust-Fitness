import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:zerotrust_fitness/core/security/encryption_service.dart';
import 'package:zerotrust_fitness/core/storage/local_vault.dart';

class TemplatesPage extends StatefulWidget {
  const TemplatesPage({super.key, required this.secretKey});

  final SecretKey secretKey;

  @override
  State<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends State<TemplatesPage> {
  List<_Template> _templates = [];
  bool _loading = true;

  static const _activityTypes = [
    'Running', 'Walking', 'Cycling', 'Strength', 'HIIT', 'Yoga', 'Swimming', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await LocalVault().fetchTemplates(widget.secretKey);
      final templates = <_Template>[];
      for (final row in rows) {
        try {
          final decrypted = await EncryptionService()
              .decryptString(row['encrypted_data'] as String, widget.secretKey);
          final data = jsonDecode(decrypted) as Map<String, dynamic>;
          templates.add(_Template(
            id: row['id'] as int,
            name: row['name'] as String,
            activityType: row['activity_type'] as String,
            durationMinutes: (data['duration_minutes'] as num?)?.toInt() ?? 30,
            intensity: (data['intensity'] as num?)?.toInt() ?? 5,
            notes: data['notes'] as String? ?? '',
          ));
        } catch (_) {}
      }
      if (mounted) setState(() { _templates = templates; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showEditor({_Template? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    String activityType = existing?.activityType ?? _activityTypes.first;
    int duration = existing?.durationMinutes ?? 30;
    int intensity = existing?.intensity ?? 5;
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                existing == null ? 'New Template' : 'Edit Template',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Template name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: activityType,
                decoration: const InputDecoration(
                  labelText: 'Activity type',
                  border: OutlineInputBorder(),
                ),
                items: _activityTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setSheet(() => activityType = v!),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Duration (min):'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Slider(
                      value: duration.toDouble(),
                      min: 5,
                      max: 120,
                      divisions: 23,
                      label: '$duration min',
                      onChanged: (v) =>
                          setSheet(() => duration = v.round()),
                    ),
                  ),
                  Text('$duration'),
                ],
              ),
              Row(
                children: [
                  const Text('Intensity (1–10):'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Slider(
                      value: intensity.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: '$intensity',
                      onChanged: (v) =>
                          setSheet(() => intensity = v.round()),
                    ),
                  ),
                  Text('$intensity'),
                ],
              ),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      Navigator.pop(ctx);
                      await _save(
                        existing: existing,
                        name: name,
                        activityType: activityType,
                        durationMinutes: duration,
                        intensity: intensity,
                        notes: notesCtrl.text.trim(),
                      );
                    },
                    child: Text(existing == null ? 'Create' : 'Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save({
    _Template? existing,
    required String name,
    required String activityType,
    required int durationMinutes,
    required int intensity,
    required String notes,
  }) async {
    final data = jsonEncode({
      'duration_minutes': durationMinutes,
      'intensity': intensity,
      'notes': notes,
    });
    final encrypted =
        await EncryptionService().encryptString(data, widget.secretKey);
    if (existing == null) {
      await LocalVault().saveTemplate(
        name: name,
        activityType: activityType,
        encryptedData: encrypted,
        secretKey: widget.secretKey,
      );
    } else {
      await LocalVault().updateTemplate(
        id: existing.id,
        name: name,
        activityType: activityType,
        encryptedData: encrypted,
        secretKey: widget.secretKey,
      );
    }
    await _load();
  }

  Future<void> _delete(_Template t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete template?'),
        content: Text('Delete "${t.name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await LocalVault().deleteTemplate(t.id, widget.secretKey);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workout Templates')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditor(),
        tooltip: 'New template',
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.fitness_center_outlined,
                          size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('No templates yet'),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => _showEditor(),
                        child: const Text('Create your first template'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: _templates.length,
                  itemBuilder: (_, i) {
                    final t = _templates[i];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.fitness_center_outlined),
                        title: Text(t.name),
                        subtitle: Text(
                            '${t.activityType} · ${t.durationMinutes} min · intensity ${t.intensity}/10'),
                        trailing: PopupMenuButton<_Action>(
                          onSelected: (a) {
                            if (a == _Action.edit) _showEditor(existing: t);
                            if (a == _Action.delete) _delete(t);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: _Action.edit,
                                child: Text('Edit')),
                            PopupMenuItem(
                                value: _Action.delete,
                                child: Text('Delete')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

enum _Action { edit, delete }

class _Template {
  const _Template({
    required this.id,
    required this.name,
    required this.activityType,
    required this.durationMinutes,
    required this.intensity,
    required this.notes,
  });

  final int id;
  final String name;
  final String activityType;
  final int durationMinutes;
  final int intensity;
  final String notes;
}
