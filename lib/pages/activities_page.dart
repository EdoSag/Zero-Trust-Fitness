import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:zerotrust_fitness/components/empty_state_widget.dart';

enum _ActivityFilter { all, manual, auto }

class ActivitiesPage extends StatefulWidget {
  const ActivitiesPage({
    super.key,
    required this.recentActivities,
    required this.isLoading,
    required this.onManualEntry,
    required this.onRefresh,
    required this.secretKey,
    required this.onEditActivity,
    required this.onDeleteActivity,
  });

  final List<Map<String, dynamic>> recentActivities;
  final bool isLoading;
  final VoidCallback onManualEntry;
  final Future<void> Function() onRefresh;
  final SecretKey? secretKey;
  final Future<void> Function(int id, Map<String, dynamic> data) onEditActivity;
  final Future<void> Function(int id) onDeleteActivity;

  @override
  State<ActivitiesPage> createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends State<ActivitiesPage> {
  final TextEditingController _searchController = TextEditingController();
  _ActivityFilter _filter = _ActivityFilter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isManual(Map<String, dynamic> a) => a.containsKey('duration');

  String _activityTitle(Map<String, dynamic> activity) {
    final rawType = (activity['type'] ?? 'Activity').toString();
    if (rawType.startsWith('HealthDataType.')) {
      return rawType
          .replaceFirst('HealthDataType.', '')
          .replaceAll('_', ' ')
          .split(' ')
          .where((p) => p.isNotEmpty)
          .map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase())
          .join(' ');
    }
    return rawType;
  }

  String _activitySubtitle(Map<String, dynamic> activity) {
    final timestampRaw = activity['timestamp'] ?? activity['date'];
    final ts = timestampRaw is String
        ? DateTime.tryParse(timestampRaw)?.toLocal()
        : null;
    final timeText = ts == null
        ? 'Unknown time'
        : '${ts.year.toString().padLeft(4, '0')}-'
            '${ts.month.toString().padLeft(2, '0')}-'
            '${ts.day.toString().padLeft(2, '0')} '
            '${ts.hour.toString().padLeft(2, '0')}:'
            '${ts.minute.toString().padLeft(2, '0')}';

    final duration = activity['duration'];
    final intensity = activity['intensity'];
    if (duration != null) {
      final intensityText = intensity == null ? 'n/a' : '$intensity/10';
      return '$duration min · intensity $intensityText · $timeText';
    }
    final value = activity['value'];
    if (value != null) return 'Value: $value · $timeText';
    return timeText;
  }

  IconData _activityIcon(Map<String, dynamic> activity) {
    final type = _activityTitle(activity).toLowerCase();
    if (type.contains('run')) return Icons.directions_run;
    if (type.contains('walk')) return Icons.directions_walk;
    if (type.contains('cycl')) return Icons.directions_bike;
    if (type.contains('swim')) return Icons.pool;
    if (type.contains('strength')) return Icons.fitness_center;
    if (type.contains('hiit')) return Icons.bolt;
    if (type.contains('yoga') || type.contains('stretch')) {
      return Icons.self_improvement;
    }
    if (type.contains('heart')) return Icons.favorite;
    if (type.contains('step')) return Icons.hiking;
    return Icons.sports_gymnastics;
  }

  /// Returns the date key (yyyy-MM-dd) for grouping.
  String _dateGroup(Map<String, dynamic> activity) {
    final raw = activity['timestamp'] ?? activity['date'];
    if (raw is! String) return 'Unknown';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return 'Unknown';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> get _filtered {
    return widget.recentActivities.where((a) {
      final matchesFilter = switch (_filter) {
        _ActivityFilter.all => true,
        _ActivityFilter.manual => _isManual(a),
        _ActivityFilter.auto => !_isManual(a),
      };
      if (!matchesFilter) return false;
      if (_query.isEmpty) return true;
      return _activityTitle(a).toLowerCase().contains(_query);
    }).toList();
  }

  Future<void> _confirmDelete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete activity?'),
        content: const Text('This cannot be undone.'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.onDeleteActivity(id);
    }
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _ActivityFilter.values.map((f) {
          final label = switch (f) {
            _ActivityFilter.all => 'All',
            _ActivityFilter.manual => 'Manual',
            _ActivityFilter.auto => 'Auto',
          };
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(label),
              selected: _filter == f,
              onSelected: (_) => setState(() => _filter = f),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildList(ThemeData theme, List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return EmptyStateWidget.noData(
        'activities',
        action: TextButton.icon(
          onPressed: widget.onManualEntry,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Log a workout'),
        ),
      );
    }

    // Build items with date-group headers interspersed.
    final rows = <Widget>[];
    String? lastGroup;
    for (final activity in items) {
      final group = _dateGroup(activity);
      if (group != lastGroup) {
        lastGroup = group;
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 6),
          child: Text(
            group,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.hintColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ));
      }
      final isManual = _isManual(activity);
      final id = activity['_id'] as int?;
      rows.add(Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor:
                theme.colorScheme.secondary.withValues(alpha: 0.1),
            child: Icon(_activityIcon(activity),
                color: theme.colorScheme.secondary),
          ),
          title: Text(_activityTitle(activity)),
          subtitle: Text(_activitySubtitle(activity)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isManual ? Colors.blue : Colors.green)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isManual ? Colors.blue : Colors.green)
                        .withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  isManual ? 'MANUAL' : 'AUTO',
                  style: TextStyle(
                    color: isManual ? Colors.blue : Colors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isManual && id != null && widget.secretKey != null) ...[
                const SizedBox(width: 4),
                PopupMenuButton<_ActivityMenuAction>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (action) {
                    switch (action) {
                      case _ActivityMenuAction.edit:
                        widget.onEditActivity(id, activity);
                      case _ActivityMenuAction.delete:
                        _confirmDelete(id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _ActivityMenuAction.edit,
                      child: Row(children: [
                        Icon(Icons.edit_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ]),
                    ),
                    PopupMenuItem(
                      value: _ActivityMenuAction.delete,
                      child: Row(children: [
                        Icon(Icons.delete_outline, size: 16,
                            color: Colors.redAccent),
                        SizedBox(width: 8),
                        Text('Delete',
                            style: TextStyle(color: Colors.redAccent)),
                      ]),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _filtered;

    return Scaffold(
      appBar: AppBar(title: const Text('Activities')),
      body: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: widget.isLoading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search activities…',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                )
                              : null,
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _buildFilterChips(),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    sliver: SliverToBoxAdapter(
                      child: _buildList(theme, items),
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: widget.onManualEntry,
        tooltip: 'Log a workout or health metric',
        child: const Icon(Icons.add),
      ),
    );
  }
}

enum _ActivityMenuAction { edit, delete }
