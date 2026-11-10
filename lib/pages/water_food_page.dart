import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_fitness/app/vault_providers.dart';
import 'package:zerotrust_fitness/components/inline_button_style.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/core/utils/units_formatter.dart';
import 'package:zerotrust_fitness/features/goals/goals_provider.dart';

/// Daily water goal when the person hasn't set one (litres).
const double defaultWaterGoalLiters = 2.0;

const mealTypes = <String>['breakfast', 'lunch', 'dinner', 'snack'];

String mealTypeLabel(String type) => switch (type) {
  'breakfast' => 'Breakfast',
  'lunch' => 'Lunch',
  'dinner' => 'Dinner',
  _ => 'Snacks',
};

IconData mealTypeIcon(String type) => switch (type) {
  'breakfast' => Icons.free_breakfast_outlined,
  'lunch' => Icons.lunch_dining_outlined,
  'dinner' => Icons.dinner_dining_outlined,
  _ => Icons.cookie_outlined,
};

/// The meal a time of day most likely is.
String mealTypeFor(DateTime at) {
  final minutes = at.hour * 60 + at.minute;
  if (minutes >= 5 * 60 && minutes < 10 * 60 + 30) return 'breakfast';
  if (minutes >= 11 * 60 && minutes < 15 * 60) return 'lunch';
  if (minutes >= 17 * 60 && minutes < 21 * 60 + 30) return 'dinner';
  return 'snack';
}

/// Water and food logging: glasses of water against a daily goal, and meals
/// with optional calories and macros. Everything is end-to-end encrypted
/// like the rest of the vault.
class WaterFoodPage extends ConsumerStatefulWidget {
  const WaterFoodPage({super.key, this.initialTab = 0});

  /// 0 = Water, 1 = Food.
  final int initialTab;

  @override
  ConsumerState<WaterFoodPage> createState() => _WaterFoodPageState();
}

class _WaterFoodPageState extends ConsumerState<WaterFoodPage> {
  DateTime _day = DateTime.now();
  bool _loading = true;
  ({num total, num health, num logged}) _water = (
    total: 0,
    health: 0,
    logged: 0,
  );
  List<({String dateKey, num liters})> _waterWeek = const [];
  List<FitnessMeal> _meals = const [];
  List<FitnessMeal> _recent = const [];
  num _healthFoodEntries = 0;

  String get _dateKey => FitnessVault.dateKeyOf(_day);

  bool get _isToday => _dateKey == FitnessVault.dateKeyOf(DateTime.now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final vault = ref.read(openFitnessVaultProvider);
    if (vault == null) return;
    final water = await vault.waterFor(_dateKey);
    final week = <({String dateKey, num liters})>[];
    for (var i = 6; i >= 0; i--) {
      final key = FitnessVault.dateKeyOf(_day.subtract(Duration(days: i)));
      week.add((dateKey: key, liters: (await vault.waterFor(key)).total));
    }
    final all = await vault.fetchMeals();
    final rows = await vault.fetchDailyMetrics();
    final day = rows.where((r) => r['date_key'] == _dateKey).firstOrNull;
    final metrics = (day?['metrics'] as Map<String, num>?) ?? const {};
    final seen = <String>{};
    final recent = <FitnessMeal>[];
    for (final m in all) {
      final name = m.name.trim().toLowerCase();
      if (name.isEmpty || !seen.add(name)) continue;
      recent.add(m);
      if (recent.length == 8) break;
    }
    if (!mounted) return;
    setState(() {
      _water = water;
      _waterWeek = week;
      _meals = [
        for (final m in all)
          if (m.dateKey == _dateKey) m,
      ];
      _recent = recent;
      _healthFoodEntries = metrics['nutrition_entries_hc'] ?? 0;
      _loading = false;
    });
  }

  void _shiftDay(int days) {
    final next = _day.add(Duration(days: days));
    if (next.isAfter(DateTime.now())) return;
    setState(() => _day = next);
    _load();
  }

  Future<void> _addWater(double liters) async {
    final vault = ref.read(openFitnessVaultProvider);
    if (vault == null) return;
    HapticFeedback.lightImpact();
    try {
      await vault.addWater(_dateKey, liters);
    } catch (e) {
      _snack(ztErrorMessage(e));
    }
    await _load();
  }

  Future<void> _customWater() async {
    final units = UnitsFormatter();
    final imperial = units.distanceUnit == DistanceUnit.imperial;
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add water'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: imperial ? 'fl oz' : 'ml'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(controller.text.replaceAll(',', '.'));
              if (v == null || v <= 0) return;
              Navigator.pop(
                ctx,
                imperial ? v * UnitsFormatter.litersPerFlOz : v / 1000,
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (amount != null && amount > 0 && amount < 10) await _addWater(amount);
  }

  Future<void> _editMeal({FitnessMeal? meal, FitnessMeal? copyOf}) async {
    final vault = ref.read(openFitnessVaultProvider);
    if (vault == null) return;
    final now = DateTime.now();
    final defaultAt = _isToday
        ? now
        : DateTime(_day.year, _day.month, _day.day, now.hour, now.minute);
    final result = await showModalBottomSheet<_MealSheetResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => MealSheet(
        meal: meal,
        template: copyOf,
        defaultAt: defaultAt,
        suggestions: [for (final m in _recent) m.name],
      ),
    );
    if (result == null) return;
    try {
      if (result.delete && meal != null) {
        await vault.removeMeal(meal.id);
      } else if (result.meal != null) {
        await vault.logMeal(result.meal!);
      }
    } catch (e) {
      _snack(ztErrorMessage(e));
    }
    await _load();
  }

  Future<void> _relog(FitnessMeal template) async {
    final vault = ref.read(openFitnessVaultProvider);
    if (vault == null) return;
    final now = DateTime.now();
    final at = _isToday
        ? now
        : DateTime(_day.year, _day.month, _day.day, now.hour, now.minute);
    await vault.logMeal(
      FitnessMeal(
        id: FitnessVault.newId(),
        name: template.name,
        mealType: mealTypeFor(at),
        at: at.toUtc(),
        kcal: template.kcal,
        proteinG: template.proteinG,
        carbsG: template.carbsG,
        fatG: template.fatG,
      ),
    );
    _snack('Logged ${template.name}');
    await _load();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final vault = ref.watch(openFitnessVaultProvider);
    ref.listen(fitnessVaultChangesProvider, (_, __) => _load());
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Water & food'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.water_drop_outlined), text: 'Water'),
              Tab(icon: Icon(Icons.restaurant_menu_outlined), text: 'Food'),
            ],
          ),
        ),
        body: vault == null
            ? const Center(child: Text('Unlock to log water and food.'))
            : Column(
                children: [
                  _dayBar(context),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : TabBarView(
                            children: [_waterTab(context), _foodTab(context)],
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _dayBar(BuildContext context) {
    final label = _isToday
        ? 'Today'
        : _dateKey ==
              FitnessVault.dateKeyOf(
                DateTime.now().subtract(const Duration(days: 1)),
              )
        ? 'Yesterday'
        : UnitsFormatter().formatDate(_day);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous day',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _shiftDay(-1),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: 'Next day',
            icon: const Icon(Icons.chevron_right),
            onPressed: _isToday ? null : () => _shiftDay(1),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Water
  // ---------------------------------------------------------------------------

  Widget _waterTab(BuildContext context) {
    final theme = Theme.of(context);
    final units = UnitsFormatter();
    final goal =
        ref.watch(goalsProvider).asData?.value.forKey('water_l')?.targetValue ??
        defaultWaterGoalLiters;
    final progress = goal <= 0 ? 0.0 : (_water.total / goal).clamp(0.0, 1.0);
    final presets = units.waterPresets;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Center(
          child: SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progress.toDouble(),
                    strokeWidth: 14,
                    strokeCap: StrokeCap.round,
                    color: const Color(0xFF0EA5E9),
                    backgroundColor: const Color(
                      0xFF0EA5E9,
                    ).withValues(alpha: 0.15),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.water_drop,
                      color: Color(0xFF0EA5E9),
                      size: 28,
                    ),
                    Text(
                      units.formatWater(_water.total),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'of ${units.formatWater(goal)}',
                      style: TextStyle(color: theme.hintColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_water.health > 0)
          Text(
            '${units.formatWater(_water.logged)} logged here · '
            '${units.formatWater(_water.health)} from your health app',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.hintColor),
          ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final p in presets)
              FilledButton.tonalIcon(
                onPressed: () => _addWater(p.liters),
                icon: const Icon(Icons.local_drink_outlined),
                label: Text(p.label),
              ),
            OutlinedButton.icon(
              onPressed: _customWater,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Other'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: _water.logged <= 0
                ? null
                : () => _addWater(-presets.first.liters),
            icon: const Icon(Icons.undo),
            label: Text('Take off ${presets.first.label.substring(1)}'),
          ),
        ),
        const SizedBox(height: 24),
        Text('Last 7 days', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final d in _waterWeek)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    _weekday(d.dateKey),
                    style: TextStyle(color: theme.hintColor),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: goal <= 0
                          ? 0
                          : (d.liters / goal).clamp(0.0, 1.0).toDouble(),
                      color: const Color(0xFF0EA5E9),
                      backgroundColor: const Color(
                        0xFF0EA5E9,
                      ).withValues(alpha: 0.12),
                    ),
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Text(
                    units.formatWater(d.liters),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _weekday(String dateKey) {
    final d = DateTime.tryParse(dateKey);
    if (d == null) return '';
    return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday -
        1];
  }

  // ---------------------------------------------------------------------------
  // Food
  // ---------------------------------------------------------------------------

  Widget _foodTab(BuildContext context) {
    final theme = Theme.of(context);
    final totals = MealTotals.of(_meals);
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _total(context, '${totals.kcal.round()}', 'kcal'),
                    _total(context, '${totals.proteinG.round()} g', 'protein'),
                    _total(context, '${totals.carbsG.round()} g', 'carbs'),
                    _total(context, '${totals.fatG.round()} g', 'fat'),
                  ],
                ),
              ),
            ),
            if (_healthFoodEntries > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Text(
                  'Plus ${_healthFoodEntries.toInt()} '
                  '${_healthFoodEntries == 1 ? 'entry' : 'entries'} '
                  'from your health app.',
                  style: TextStyle(color: theme.hintColor),
                ),
              ),
            if (_recent.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Log again', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final m in _recent)
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 16),
                      label: Text(m.name),
                      onPressed: () => _relog(m),
                    ),
                ],
              ),
            ],
            for (final type in mealTypes) ..._mealSection(context, type),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'fab-food',
            onPressed: () => _editMeal(),
            icon: const Icon(Icons.add),
            label: const Text('Log food'),
          ),
        ),
      ],
    );
  }

  Widget _total(BuildContext context, String value, String label) => Column(
    children: [
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      Text(label, style: TextStyle(color: Theme.of(context).hintColor)),
    ],
  );

  List<Widget> _mealSection(BuildContext context, String type) {
    final items = _meals.where((m) => m.mealType == type).toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    final units = UnitsFormatter();
    return [
      const SizedBox(height: 16),
      Row(
        children: [
          Icon(mealTypeIcon(type), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mealTypeLabel(type),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (items.any((m) => m.kcal != null))
            Text(
              '${items.fold<num>(0, (s, m) => s + (m.kcal ?? 0)).round()} kcal',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
        ],
      ),
      if (items.isEmpty)
        Padding(
          padding: const EdgeInsets.only(left: 28, top: 4),
          child: Text(
            'Nothing logged',
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
        ),
      for (final m in items)
        ListTile(
          contentPadding: const EdgeInsets.only(left: 28),
          title: Text(m.name.isEmpty ? mealTypeLabel(type) : m.name),
          subtitle: Text(
            [
              units.formatTime(m.at.toLocal()),
              if (m.proteinG != null) 'P ${m.proteinG!.round()} g',
              if (m.carbsG != null) 'C ${m.carbsG!.round()} g',
              if (m.fatG != null) 'F ${m.fatG!.round()} g',
            ].join(' · '),
          ),
          trailing: m.kcal == null ? null : Text('${m.kcal!.round()} kcal'),
          onTap: () => _editMeal(meal: m),
        ),
    ];
  }
}

/// Calories and macros added up over some meals.
class MealTotals {
  const MealTotals(this.kcal, this.proteinG, this.carbsG, this.fatG);

  factory MealTotals.of(Iterable<FitnessMeal> meals) {
    num kcal = 0, p = 0, c = 0, f = 0;
    for (final m in meals) {
      kcal += m.kcal ?? 0;
      p += m.proteinG ?? 0;
      c += m.carbsG ?? 0;
      f += m.fatG ?? 0;
    }
    return MealTotals(kcal, p, c, f);
  }

  final num kcal;
  final num proteinG;
  final num carbsG;
  final num fatG;
}

class _MealSheetResult {
  const _MealSheetResult({this.meal, this.delete = false});
  final FitnessMeal? meal;
  final bool delete;
}

/// Adds or edits one meal.
class MealSheet extends StatefulWidget {
  const MealSheet({
    super.key,
    this.meal,
    this.template,
    required this.defaultAt,
    this.suggestions = const [],
  });

  final FitnessMeal? meal;
  final FitnessMeal? template;
  final DateTime defaultAt;
  final List<String> suggestions;

  @override
  State<MealSheet> createState() => _MealSheetState();
}

class _MealSheetState extends State<MealSheet> {
  late final TextEditingController _name;
  late final TextEditingController _kcal;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;
  final _nameFocus = FocusNode();
  late String _type;
  late DateTime _at;

  @override
  void initState() {
    super.initState();
    final m = widget.meal ?? widget.template;
    String fmt(num? v) =>
        v == null ? '' : (v == v.roundToDouble() ? '${v.round()}' : '$v');
    _name = TextEditingController(text: m?.name ?? '');
    _kcal = TextEditingController(text: fmt(m?.kcal));
    _protein = TextEditingController(text: fmt(m?.proteinG));
    _carbs = TextEditingController(text: fmt(m?.carbsG));
    _fat = TextEditingController(text: fmt(m?.fatG));
    _at = widget.meal?.at.toLocal() ?? widget.defaultAt;
    _type = widget.meal?.mealType ?? mealTypeFor(_at);
  }

  @override
  void dispose() {
    for (final c in [_name, _kcal, _protein, _carbs, _fat]) {
      c.dispose();
    }
    _nameFocus.dispose();
    super.dispose();
  }

  num? _num(TextEditingController c) {
    final v = num.tryParse(c.text.trim().replaceAll(',', '.'));
    return v == null || v < 0 ? null : v;
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty && _num(_kcal) == null) return;
    Navigator.pop(
      context,
      _MealSheetResult(
        meal: FitnessMeal(
          id: widget.meal?.id ?? FitnessVault.newId(),
          name: name,
          mealType: _type,
          at: _at.toUtc(),
          kcal: _num(_kcal),
          proteinG: _num(_protein),
          carbsG: _num(_carbs),
          fatG: _num(_fat),
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
    );
    if (t == null) return;
    setState(
      () => _at = DateTime(_at.year, _at.month, _at.day, t.hour, t.minute),
    );
  }

  Widget _numField(TextEditingController c, String label, String suffix) =>
      Expanded(
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            suffixText: suffix,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final editing = widget.meal != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        // Above the keyboard when it is open, else above the system
        // navigation bar (the app draws edge to edge).
        20 +
            math.max(
              MediaQuery.viewInsetsOf(context).bottom,
              MediaQuery.viewPaddingOf(context).bottom,
            ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              editing ? 'Edit food' : 'Log food',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            RawAutocomplete<String>(
              textEditingController: _name,
              focusNode: _nameFocus,
              optionsViewBuilder: (context, onSelected, options) => Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: [
                        for (final o in options)
                          ListTile(title: Text(o), onTap: () => onSelected(o)),
                      ],
                    ),
                  ),
                ),
              ),
              optionsBuilder: (v) {
                final q = v.text.trim().toLowerCase();
                if (q.isEmpty) return const Iterable<String>.empty();
                return widget.suggestions.where(
                  (s) => s.toLowerCase().contains(q),
                );
              },
              fieldViewBuilder: (context, controller, focus, onSubmit) {
                return TextField(
                  controller: controller,
                  focusNode: focus,
                  autofocus: !editing,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'What did you eat?',
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [
                for (final t in mealTypes)
                  ButtonSegment(value: t, label: Text(mealTypeLabel(t))),
              ],
              selected: {_type},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text(UnitsFormatter().formatTime(_at)),
              onTap: _pickTime,
            ),
            Row(
              children: [
                _numField(_kcal, 'Calories', 'kcal'),
                const SizedBox(width: 8),
                _numField(_protein, 'Protein', 'g'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _numField(_carbs, 'Carbs', 'g'),
                const SizedBox(width: 8),
                _numField(_fat, 'Fat', 'g'),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Calories and macros are optional.',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (editing)
                  TextButton.icon(
                    onPressed: () => Navigator.pop(
                      context,
                      const _MealSheetResult(delete: true),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _save,
                  style: inlineButtonStyle,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
