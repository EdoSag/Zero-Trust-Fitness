import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_fitness/features/achievements/domain/achievement_definition.dart';
import 'package:zerotrust_fitness/features/achievements/domain/achievement_service.dart';
import 'package:zerotrust_fitness/features/achievements/presentation/achievement_detail_bottom_sheet.dart';
import 'package:zerotrust_fitness/features/achievements/presentation/medal_card.dart';
import 'package:zerotrust_fitness/features/app/providers.dart';

enum _AchievementFilter { all, unlocked, locked }

class AchievementsPage extends ConsumerStatefulWidget {
  const AchievementsPage({super.key});

  @override
  ConsumerState<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends ConsumerState<AchievementsPage> {
  List<UnlockedAchievement> _unlocked = [];
  _AchievementFilter _filter = _AchievementFilter.all;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    final secretKey = ref.read(securityEnclaveProvider);
    if (secretKey == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final unlocked = await AchievementService().fetchUnlocked(secretKey);
    if (!mounted) return;
    setState(() {
      _unlocked = unlocked;
      _isLoading = false;
    });
  }

  Set<String> get _unlockedIds => _unlocked.map((u) => u.definition.id).toSet();

  List<AchievementDefinition> _filteredFor(AchievementCategory category) {
    return kAllAchievements.where((d) {
      if (d.category != category) return false;
      return switch (_filter) {
        _AchievementFilter.all => true,
        _AchievementFilter.unlocked => _unlockedIds.contains(d.id),
        _AchievementFilter.locked => !_unlockedIds.contains(d.id),
      };
    }).toList();
  }

  String _categoryLabel(AchievementCategory cat) => switch (cat) {
        AchievementCategory.fitness => 'Fitness',
        AchievementCategory.sleep => 'Sleep',
        AchievementCategory.health => 'Health',
        AchievementCategory.milestones => 'Milestones',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = AchievementCategory.values;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              '${_unlocked.length}/${kAllAchievements.length}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _AchievementFilter.values.map((f) {
                        final label = switch (f) {
                          _AchievementFilter.all => 'All',
                          _AchievementFilter.unlocked => 'Unlocked',
                          _AchievementFilter.locked => 'Locked',
                        };
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(label),
                            selected: _filter == f,
                            onSelected: (_) =>
                                setState(() => _filter = f),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final medals = _filteredFor(cat);
                      if (medals.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 12),
                            child: Text(
                              _categoryLabel(cat),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.85,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                            ),
                            itemCount: medals.length,
                            itemBuilder: (context, i) {
                              final def = medals[i];
                              final earned = _unlockedIds.contains(def.id);
                              final unlock = _unlocked
                                  .where((u) => u.definition.id == def.id)
                                  .firstOrNull;
                              return MedalCard(
                                definition: def,
                                isEarned: earned,
                                unlockedAt: unlock?.unlockedAt,
                                onTap: () => showAchievementDetail(
                                  context,
                                  def,
                                  earned,
                                  unlock?.unlockedAt,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
