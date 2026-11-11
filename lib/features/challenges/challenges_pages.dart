import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_fitness/components/inline_button_style.dart';
import 'package:zerotrust_fitness/features/challenges/challenge_model.dart';
import 'package:zerotrust_fitness/features/challenges/challenges_data.dart';
import 'package:zerotrust_fitness/l10n/l10n.dart';

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 4)),
    );
}

/// A page's list padding, clear of the gesture bar at the bottom (an
/// explicit padding turns off ListView's own).
EdgeInsets _listPadding(
  BuildContext context, {
  double side = 16,
  double top = 16,
}) => EdgeInsets.fromLTRB(
  side,
  top,
  side,
  24 + MediaQuery.paddingOf(context).bottom,
);

String metricLabel(BuildContext context, ChallengeMetric m) => switch (m) {
  ChallengeMetric.steps => context.l10n.steps,
  ChallengeMetric.heartPoints => context.l10n.heartPoints,
};

String _number(BuildContext context, int v) => NumberFormat.decimalPattern(
  Localizations.localeOf(context).toString(),
).format(v);

String _date(BuildContext context, String key) => DateFormat.MMMd(
  Localizations.localeOf(context).toString(),
).format(parseDateKey(key));

/// "Most steps" / "Days with 10,000 steps".
String goalLabel(BuildContext context, Challenge c) {
  final l = context.l10n;
  final metric = metricLabel(context, c.metric);
  return switch (c.goal) {
    ChallengeGoal.mostTotal => l.challengeGoalMostSummary(metric),
    ChallengeGoal.dailyTarget => l.challengeGoalDaysSummary(
      _number(context, c.dailyTarget ?? 0),
      metric,
    ),
  };
}

String statusLabel(BuildContext context, Challenge c, String today) {
  final l = context.l10n;
  return switch (c.statusOn(today)) {
    ChallengeStatus.upcoming => l.challengeStarts(_date(context, c.start)),
    ChallengeStatus.active => l.challengeDaysLeft(c.daysLeftOn(today)),
    ChallengeStatus.finished => l.challengeEnded(_date(context, c.end)),
  };
}

String _ordinalRank(BuildContext context, int rank, int of) =>
    context.l10n.challengeYourRank(rank, of);

// ---------------------------------------------------------------------------
// List
// ---------------------------------------------------------------------------

/// Every challenge this account is in, people waiting to join, and the
/// buttons to start or join one.
class ChallengesPage extends ConsumerWidget {
  const ChallengesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final state = ref.watch(challengesProvider);
    final joins = ref.watch(pendingChallengeJoinsProvider).value ?? const [];
    final today = ref.watch(challengeTodayProvider)();
    final data = state.value;
    final list = data?.challenges ?? const <ChallengeData>[];
    final active = [
      for (final c in list)
        if (c.challenge?.statusOn(today) == ChallengeStatus.active) c,
    ];
    final upcoming = [
      for (final c in list)
        if (c.challenge?.statusOn(today) == ChallengeStatus.upcoming) c,
    ];
    final finished = [
      for (final c in list)
        if (c.challenge?.statusOn(today) == ChallengeStatus.finished) c,
    ];
    final waiting = [
      for (final c in list)
        if (c.challenge == null) c,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l.challenges),
        actions: [
          IconButton(
            tooltip: l.challengeSyncNow,
            icon: const Icon(Icons.sync),
            onPressed: data?.ready == true
                ? () async {
                    try {
                      await ref.read(challengeActionsProvider).syncNow();
                    } on Object {
                      if (context.mounted)
                        _snack(context, l.challengeNeedsInternet);
                    }
                  }
                : null,
          ),
        ],
      ),
      body: data == null || (data.loading && list.isEmpty)
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                try {
                  await ref.read(challengeActionsProvider).syncNow();
                } on Object {
                  // shown by the error text below
                }
              },
              child: ListView(
                padding: _listPadding(context, top: 8),
                children: [
                  if (data.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        l.challengeNeedsInternet,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  for (final j in joins)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.person_add_alt),
                        title: Text(
                          l.challengeJoinRequest(
                            j.name,
                            data.byId(j.spaceId)?.challenge?.title ?? '',
                          ),
                        ),
                        subtitle: Text(l.challengeJoinRequestHint),
                        onTap: () => confirmChallengeJoin(context, ref, j),
                      ),
                    ),
                  if (list.isEmpty) const _EmptyChallenges(),
                  for (final c in waiting) _WaitingCard(data: c),
                  if (active.isNotEmpty) _Section(l.challengeActive),
                  for (final c in active) ChallengeCard(data: c, today: today),
                  if (upcoming.isNotEmpty) _Section(l.challengeUpcoming),
                  for (final c in upcoming)
                    ChallengeCard(data: c, today: today),
                  if (finished.isNotEmpty) _Section(l.challengeFinished),
                  for (final c in finished)
                    ChallengeCard(data: c, today: today),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: data.ready
                        ? () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ChallengeEditorPage(),
                            ),
                          )
                        : null,
                    icon: const Icon(Icons.emoji_events_outlined),
                    label: Text(l.challengeCreate),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: data.ready
                        ? () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const JoinChallengePage(),
                            ),
                          )
                        : null,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text(l.challengeJoin),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(4, 16, 4, 8),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    ),
  );
}

class _EmptyChallenges extends StatelessWidget {
  const _EmptyChallenges();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 56,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            l.challengeEmptyTitle,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(l.challengeEmptyBody, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            l.challengePrivacy,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Joined, waiting for the organiser to compare codes.
class _WaitingCard extends StatelessWidget {
  const _WaitingCard({required this.data});
  final ChallengeData data;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final code = data.entry.joinCode;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.hourglass_top),
        title: Text(l.challengeWaitingTitle),
        subtitle: Text(
          code == null
              ? l.challengeWaitingBody
              : '${l.challengeWaitingBody}\n${l.challengeYourCode} ${ltr(code)}',
        ),
        isThreeLine: code != null,
      ),
    );
  }
}

/// One challenge in the list, and on the Today page.
class ChallengeCard extends StatelessWidget {
  const ChallengeCard({super.key, required this.data, required this.today});
  final ChallengeData data;
  final String today;

  @override
  Widget build(BuildContext context) {
    final c = data.challenge!;
    final mine = data.mine;
    final theme = Theme.of(context);
    final board = data.board;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ChallengeDetailPage(spaceId: data.spaceId),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  c.metric == ChallengeMetric.steps
                      ? Icons.directions_walk
                      : Icons.favorite,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(goalLabel(context, c)),
                    const SizedBox(height: 2),
                    Text(
                      statusLabel(context, c, today),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (mine != null &&
                  mine.hasData &&
                  c.statusOn(today) != ChallengeStatus.upcoming) ...[
                const SizedBox(width: 12),
                Text(
                  _ordinalRank(context, mine.rank, board.length),
                  style: theme.textTheme.labelLarge,
                  textAlign: TextAlign.end,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Running challenges on the Today page. Draws nothing when there are none.
class TodayChallengesCard extends ConsumerWidget {
  const TodayChallengesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(challengeTodayProvider)();
    final list = ref.watch(challengesProvider).value?.challenges ?? const [];
    final active = [
      for (final c in list)
        if (c.challenge?.statusOn(today) == ChallengeStatus.active) c,
    ];
    if (active.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in active.take(3)) ChallengeCard(data: c, today: today),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail
// ---------------------------------------------------------------------------

class ChallengeDetailPage extends ConsumerWidget {
  const ChallengeDetailPage({super.key, required this.spaceId});
  final String spaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final state = ref.watch(challengesProvider).value;
    final data = state?.byId(spaceId);
    final c = data?.challenge;
    final today = ref.watch(challengeTodayProvider)();
    if (state != null && data == null) {
      // Left, removed, or deleted.
      return Scaffold(
        appBar: AppBar(title: Text(l.challenges)),
        body: Center(child: Text(l.challengeGone)),
      );
    }
    if (data == null || c == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.challenges)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final joins = [
      for (final j
          in ref.watch(pendingChallengeJoinsProvider).value ??
              const <PendingJoin>[])
        if (j.spaceId == spaceId) j,
    ];
    final board = data.board;
    final theme = Theme.of(context);
    final best = board.isEmpty ? 0 : board.first.score;
    final byDays = c.goal == ChallengeGoal.dailyTarget;
    final maxScore = byDays ? c.lengthDays : best;

    return Scaffold(
      appBar: AppBar(
        title: Text(c.title),
        actions: [
          if (data.isAdmin)
            IconButton(
              tooltip: l.challengeInvite,
              icon: const Icon(Icons.person_add_alt),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => InviteFriendPage(spaceId: spaceId),
                ),
              ),
            ),
          PopupMenuButton<String>(
            onSelected: (v) => _menu(context, ref, data, v),
            itemBuilder: (_) => [
              if (data.isAdmin &&
                  !scoresClosed(c, ref.read(challengeTodayProvider)()))
                PopupMenuItem(value: 'edit', child: Text(l.challengeEdit)),
              PopupMenuItem(value: 'leave', child: Text(l.challengeLeave)),
              if (data.isAdmin)
                PopupMenuItem(value: 'delete', child: Text(l.challengeDelete)),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: _listPadding(context, top: 8),
        children: [
          Text(goalLabel(context, c), style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            l.challengeDates(_date(context, c.start), _date(context, c.end)),
          ),
          const SizedBox(height: 2),
          Text(
            statusLabel(context, c, today),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          for (final j in joins)
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_add_alt),
                title: Text(l.challengeJoinRequest(j.name, c.title)),
                subtitle: Text(l.challengeJoinRequestHint),
                onTap: () => confirmChallengeJoin(context, ref, j),
              ),
            ),
          _Section(l.challengeLeaderboard),
          for (final s in board)
            _StandingRow(
              standing: s,
              isMe: s.userId == data.myUserId,
              unit: byDays
                  ? l.challengeDaysUnit(s.daysMet)
                  : _number(context, s.total),
              detail: byDays
                  ? l.challengeTotalDetail(
                      _number(context, s.total),
                      metricLabel(context, c.metric),
                    )
                  : null,
              fraction: maxScore <= 0 ? 0 : s.score / maxScore,
              onLongPress: data.isAdmin && s.userId != data.myUserId
                  ? () => _confirmRemove(context, ref, data, s)
                  : null,
            ),
          if (board.length < 2) ...[
            const SizedBox(height: 8),
            Text(l.challengeInviteHint, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(Icons.lock_outline, size: 18, color: theme.hintColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.challengeWhatIsShared(metricLabel(context, c.metric)),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _menu(
    BuildContext context,
    WidgetRef ref,
    ChallengeData data,
    String action,
  ) async {
    final l = context.l10n;
    final actions = ref.read(challengeActionsProvider);
    if (action == 'edit') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChallengeEditorPage(
            spaceId: data.spaceId,
            initial: data.challenge,
          ),
        ),
      );
      return;
    }
    final delete = action == 'delete';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(delete ? l.challengeDeleteTitle : l.challengeLeaveTitle),
        content: Text(delete ? l.challengeDeleteBody : l.challengeLeaveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(delete ? l.challengeDelete : l.challengeLeave),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      if (delete) {
        await actions.delete(data.spaceId);
      } else {
        await actions.leave(data.spaceId);
      }
      if (context.mounted) Navigator.of(context).pop();
    } on Object {
      if (context.mounted) _snack(context, l.challengeNeedsInternet);
    }
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    ChallengeData data,
    Standing s,
  ) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.challengeRemoveTitle(s.name)),
        content: Text(l.challengeRemoveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.challengeRemove),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(challengeActionsProvider)
          .removeMember(data.spaceId, s.userId);
    } on Object {
      if (context.mounted) _snack(context, l.challengeNeedsInternet);
    }
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({
    required this.standing,
    required this.isMe,
    required this.unit,
    required this.fraction,
    this.detail,
    this.onLongPress,
  });

  final Standing standing;
  final bool isMe;
  final String unit;
  final String? detail;
  final double fraction;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final name = isMe ? l.challengeYou(standing.name) : standing.name;
    final medal = switch (standing.rank) {
      1 => const Color(0xFFF5B301),
      2 => const Color(0xFF9CA3AF),
      3 => const Color(0xFFB45309),
      _ => null,
    };
    return InkWell(
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: CircleAvatar(
                radius: 16,
                backgroundColor:
                    medal ?? theme.colorScheme.surfaceContainerHighest,
                child: Text(
                  '${standing.rank}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: medal != null ? Colors.black : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: isMe
                              ? theme.textTheme.titleSmall
                              : theme.textTheme.bodyLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        standing.hasData ? unit : l.challengeNoDataYet,
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fraction.clamp(0.0, 1.0),
                      minHeight: 6,
                    ),
                  ),
                  if (detail != null && standing.hasData) ...[
                    const SizedBox(height: 4),
                    Text(detail!, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create / edit
// ---------------------------------------------------------------------------

class ChallengeEditorPage extends ConsumerStatefulWidget {
  const ChallengeEditorPage({super.key, this.spaceId, this.initial});

  /// Set when editing an existing challenge.
  final String? spaceId;
  final Challenge? initial;

  @override
  ConsumerState<ChallengeEditorPage> createState() =>
      _ChallengeEditorPageState();
}

class _ChallengeEditorPageState extends ConsumerState<ChallengeEditorPage> {
  static const _lengths = [3, 7, 14, 30];

  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _target = TextEditingController(
    text: widget.initial?.dailyTarget?.toString() ?? '10000',
  );
  final _name = TextEditingController();
  late ChallengeMetric _metric =
      widget.initial?.metric ?? ChallengeMetric.steps;
  late ChallengeGoal _goal = widget.initial?.goal ?? ChallengeGoal.mostTotal;
  late String _start =
      widget.initial?.start ?? ref.read(challengeTodayProvider)();
  late int _length = widget.initial?.lengthDays ?? 7;
  bool _busy = false;

  bool get _editing => widget.spaceId != null;

  @override
  void initState() {
    super.initState();
    if (!_editing) {
      ref
          .read(challengeProfileProvider.future)
          .then((p) {
            if (mounted && _name.text.isEmpty) _name.text = p.name;
          })
          .catchError((Object _) {});
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    _name.dispose();
    super.dispose();
  }

  void _setMetric(ChallengeMetric m) {
    setState(() {
      // Swap the suggested target along with the metric, unless typed.
      if (_target.text == '10000' && m == ChallengeMetric.heartPoints) {
        _target.text = '30';
      } else if (_target.text == '30' && m == ChallengeMetric.steps) {
        _target.text = '10000';
      }
      _metric = m;
    });
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: parseDateKey(_start),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) setState(() => _start = dateKey(picked));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final l = context.l10n;
    final challenge = Challenge(
      title: _title.text.trim(),
      metric: _metric,
      goal: _goal,
      start: _start,
      end: addDays(_start, _length - 1),
      dailyTarget: _goal == ChallengeGoal.dailyTarget
          ? int.tryParse(_target.text.trim())
          : null,
    );
    setState(() => _busy = true);
    try {
      final actions = ref.read(challengeActionsProvider);
      if (_editing) {
        await actions.update(widget.spaceId!, challenge);
        if (mounted) Navigator.of(context).pop();
      } else {
        final id = await actions.create(challenge, myName: _name.text.trim());
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => InviteFriendPage(spaceId: id),
          ),
        );
      }
    } on Object {
      if (mounted) _snack(context, l.challengeNeedsInternet);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lengths = {..._lengths, _length}.toList()..sort();
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? l.challengeEdit : l.challengeCreate),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: _listPadding(context),
          children: [
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 60,
              decoration: InputDecoration(
                labelText: l.challengeTitle,
                hintText: l.challengeTitleHint,
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? l.challengeRequired : null,
            ),
            const SizedBox(height: 8),
            Text(
              l.challengeMeasure,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SegmentedButton<ChallengeMetric>(
              segments: [
                ButtonSegment(
                  value: ChallengeMetric.steps,
                  label: Text(l.steps),
                  icon: const Icon(Icons.directions_walk),
                ),
                ButtonSegment(
                  value: ChallengeMetric.heartPoints,
                  label: Text(l.heartPoints),
                  icon: const Icon(Icons.favorite_outline),
                ),
              ],
              selected: {_metric},
              onSelectionChanged: (s) => _setMetric(s.first),
            ),
            const SizedBox(height: 16),
            Text(
              l.challengeWinBy,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SegmentedButton<ChallengeGoal>(
              segments: [
                ButtonSegment(
                  value: ChallengeGoal.mostTotal,
                  label: Text(l.challengeGoalMost),
                ),
                ButtonSegment(
                  value: ChallengeGoal.dailyTarget,
                  label: Text(l.challengeGoalDays),
                ),
              ],
              selected: {_goal},
              onSelectionChanged: (s) => setState(() => _goal = s.first),
            ),
            const SizedBox(height: 8),
            Text(
              _goal == ChallengeGoal.mostTotal
                  ? l.challengeGoalMostHint
                  : l.challengeGoalDaysHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_goal == ChallengeGoal.dailyTarget) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _target,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l.challengeDailyTarget(
                    metricLabel(context, _metric),
                  ),
                ),
                validator: (v) => (int.tryParse(v?.trim() ?? '') ?? 0) <= 0
                    ? l.challengeRequired
                    : null,
              ),
            ],
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(l.challengeStartDate),
              subtitle: Text(_date(context, _start)),
              onTap: _pickStart,
            ),
            Text(
              l.challengeLength,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final days in lengths)
                  ChoiceChip(
                    label: Text(l.challengeLengthDays(days)),
                    selected: _length == days,
                    onSelected: (_) => setState(() => _length = days),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l.challengeDates(
                _date(context, _start),
                _date(context, addDays(_start, _length - 1)),
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (!_editing) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                maxLength: 40,
                decoration: InputDecoration(
                  labelText: l.challengeYourName,
                  helperText: l.challengeYourNameHint,
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? l.challengeRequired : null,
              ),
              const SizedBox(height: 8),
              Text(
                l.challengeWhatIsShared(metricLabel(context, _metric)),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_editing ? l.save : l.challengeCreateAndInvite),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Invite and join
// ---------------------------------------------------------------------------

/// A link to send, or a QR code to scan in person. Then shows who answered,
/// to confirm with the code.
class InviteFriendPage extends ConsumerStatefulWidget {
  const InviteFriendPage({super.key, required this.spaceId});
  final String spaceId;

  @override
  ConsumerState<InviteFriendPage> createState() => _InviteFriendPageState();
}

class _InviteFriendPageState extends ConsumerState<InviteFriendPage> {
  SpaceInviteLink? _link;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _create());
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final link = await ref
          .read(ztSpacesProvider.notifier)
          .invite(widget.spaceId);
      if (mounted) setState(() => _link = link);
    } on Object {
      if (mounted) _snack(context, context.l10n.challengeNeedsInternet);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final title =
        ref
            .watch(challengesProvider)
            .value
            ?.byId(widget.spaceId)
            ?.challenge
            ?.title ??
        '';
    final joins = [
      for (final j
          in ref.watch(pendingChallengeJoinsProvider).value ??
              const <PendingJoin>[])
        if (j.spaceId == widget.spaceId) j,
    ];
    final link = _link;
    return Scaffold(
      appBar: AppBar(title: Text(l.challengeInviteTo(title))),
      body: ListView(
        padding: _listPadding(context),
        children: [
          for (final j in joins)
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_add_alt),
                title: Text(l.challengeJoinRequest(j.name, title)),
                subtitle: Text(l.challengeJoinRequestHint),
                onTap: () => confirmChallengeJoin(context, ref, j),
              ),
            ),
          if (link == null) ...[
            Text(l.challengeInviteIntro),
            const SizedBox(height: 24),
            if (_busy)
              const Center(child: CircularProgressIndicator())
            else
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.qr_code),
                label: Text(l.challengeCreateInvite),
              ),
          ] else ...[
            Text(l.challengeInviteReady, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Center(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: QrImageView(
                  data: link.qrData,
                  size: 240,
                  semanticsLabel: l.challengeInviteQr,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: inlineButtonStyle,
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: link.toString()),
                      );
                      if (context.mounted)
                        _snack(context, l.challengeLinkCopied);
                    },
                    icon: const Icon(Icons.copy),
                    label: Text(l.challengeCopyLink),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: inlineButtonStyle,
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(
                        text: l.challengeInviteMessage(title, link.toString()),
                      ),
                    ),
                    icon: const Icon(Icons.share),
                    label: Text(l.challengeShareLink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              l.challengeInviteNextSteps,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                await ref.read(ztSpacesProvider.notifier).refresh();
                ref.invalidate(pendingChallengeJoinsProvider);
              },
              icon: const Icon(Icons.refresh),
              label: Text(l.challengeCheckAnswers),
            ),
            TextButton.icon(
              onPressed: _busy ? null : _create,
              icon: const Icon(Icons.person_add_alt),
              label: Text(l.challengeAnotherInvite),
            ),
          ],
        ],
      ),
    );
  }
}

/// The organiser checks the code on the friend's phone, then lets them in.
Future<void> confirmChallengeJoin(
  BuildContext context,
  WidgetRef ref,
  PendingJoin j,
) async {
  final l = context.l10n;
  final actions = ref.read(challengeActionsProvider);
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.challengeConfirmTitle(j.name)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.challengeConfirmBody),
          const SizedBox(height: 16),
          Text(
            j.verificationCode,
            style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 2,
            ),
            textDirection: TextDirection.ltr,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'reject'),
          child: Text(l.challengeCodesDiffer),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l.challengeLater),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'ok'),
          child: Text(l.challengeCodesMatch),
        ),
      ],
    ),
  );
  try {
    if (choice == 'ok') {
      await actions.confirm(j);
      if (context.mounted) _snack(context, l.challengeJoined(j.name));
    } else if (choice == 'reject') {
      await actions.decline(j);
    } else {
      return;
    }
  } on Object {
    if (context.mounted) _snack(context, l.challengeNeedsInternet);
  }
  ref.invalidate(pendingChallengeJoinsProvider);
}

/// Joins a challenge from an invite link (pasted, scanned, or opened from a
/// message), then shows the code to compare with the organiser.
class JoinChallengePage extends ConsumerStatefulWidget {
  const JoinChallengePage({super.key, this.initialLink});
  final String? initialLink;

  @override
  ConsumerState<JoinChallengePage> createState() => _JoinChallengePageState();
}

class _JoinChallengePageState extends ConsumerState<JoinChallengePage> {
  late final _link = TextEditingController(text: widget.initialLink);
  final _name = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _code;

  @override
  void initState() {
    super.initState();
    ref
        .read(challengeProfileProvider.future)
        .then((p) {
          if (mounted && _name.text.isEmpty) _name.text = p.name;
        })
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    _link.dispose();
    _name.dispose();
    super.dispose();
  }

  String? _validLink(String? v) {
    try {
      final link = SpaceInviteLink.parse(v ?? '');
      if (link.app != 'fitness') return context.l10n.challengeInviteOtherApp;
      return null;
    } on FormatException {
      return context.l10n.challengeInviteInvalid;
    }
  }

  Future<void> _scan() async {
    final text = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const _ScanInvitePage()));
    if (text != null) setState(() => _link.text = text);
  }

  Future<void> _join() async {
    if (!_form.currentState!.validate()) return;
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      final started = await ref
          .read(challengeActionsProvider)
          .join(SpaceInviteLink.parse(_link.text), myName: _name.text.trim());
      if (mounted) setState(() => _code = started.verificationCode);
    } on SpaceRefused {
      if (mounted) _snack(context, l.challengeInviteUsed);
    } on Object {
      if (mounted) _snack(context, l.challengeNeedsInternet);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final code = _code;
    return Scaffold(
      appBar: AppBar(title: Text(l.challengeJoin)),
      body: code != null
          ? ListView(
              padding: _listPadding(context, side: 24),
              children: [
                const Icon(Icons.verified_user_outlined, size: 56),
                const SizedBox(height: 16),
                Text(
                  l.challengeJoinCodeTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  code,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  style: Theme.of(
                    context,
                  ).textTheme.displaySmall?.copyWith(letterSpacing: 3),
                ),
                const SizedBox(height: 16),
                Text(l.challengeJoinCodeBody, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l.challengeDone),
                ),
              ],
            )
          : Form(
              key: _form,
              child: ListView(
                padding: _listPadding(context),
                children: [
                  Text(l.challengeJoinIntro),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _link,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l.challengeInviteLink,
                      suffixIcon: IconButton(
                        tooltip: l.challengeScanQr,
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: _scan,
                      ),
                    ),
                    validator: _validLink,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 40,
                    decoration: InputDecoration(
                      labelText: l.challengeYourName,
                      helperText: l.challengeYourNameHint,
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? l.challengeRequired
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.challengeJoinPrivacy,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _join,
                    child: Text(l.challengeJoinButton),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ScanInvitePage extends StatefulWidget {
  const _ScanInvitePage();

  @override
  State<_ScanInvitePage> createState() => _ScanInvitePageState();
}

class _ScanInvitePageState extends State<_ScanInvitePage> {
  final _key = GlobalKey(debugLabel: 'qr');
  bool _done = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.challengeScanQr)),
    body: QRView(
      key: _key,
      overlay: QrScannerOverlayShape(
        borderColor: Theme.of(context).colorScheme.primary,
        borderRadius: 12,
        borderLength: 32,
        borderWidth: 8,
        cutOutSize: 260,
      ),
      onQRViewCreated: (controller) {
        controller.scannedDataStream.listen((b) {
          final code = b.code;
          if (_done || code == null) return;
          try {
            SpaceInviteLink.parse(code);
          } on FormatException {
            return;
          }
          _done = true;
          controller.pauseCamera();
          if (context.mounted) Navigator.of(context).pop(code);
        });
      },
    ),
  );
}
