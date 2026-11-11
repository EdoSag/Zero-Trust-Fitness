import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_fitness/app/vault_providers.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/features/challenges/challenge_model.dart';

/// Only a challenge's admins change what it measures; each person's
/// progress row can be written only by that person (the core checks the
/// signed author on every phone).
const SpacePolicy fitnessSpacePolicy = SpacePolicy(
  adminOnlyKinds: {Challenge.kind},
  ownedPrefixes: {ChallengeProgress.prefix},
);

/// Today's date key. A provider so tests can pin the day.
final challengeTodayProvider = Provider<String Function()>(
  (ref) =>
      () => dateKey(DateTime.now()),
);

/// Bumped after every local challenge write, so screens update at once even
/// offline (the spaces' sync status changes only when they sync).
final challengesRevisionProvider = NotifierProvider<ChallengesRevision, int>(
  ChallengesRevision.new,
);

class ChallengesRevision extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

/// One challenge as the screens show it.
class ChallengeData {
  ChallengeData({
    required this.entry,
    required this.myUserId,
    this.challenge,
    this.members = const {},
    this.progress = const {},
  });

  final SpaceEntry entry;
  final String myUserId;

  /// Null until the challenge's details have arrived (just joined).
  final Challenge? challenge;

  /// Current members, user id to name.
  final Map<String, String> members;
  final Map<String, ChallengeProgress> progress;

  String get spaceId => entry.info.id;
  bool get isAdmin => entry.info.myRole == SpaceRole.admin;

  /// Joined, but an admin hasn't confirmed the codes yet.
  bool get waitingForConfirm => entry.space == null || challenge == null;

  List<Standing> get board => challenge == null
      ? const []
      : standings(c: challenge!, members: members, progress: progress);

  Standing? get mine {
    for (final s in board) {
      if (s.userId == myUserId) return s;
    }
    return null;
  }
}

class ChallengesState {
  const ChallengesState({
    this.challenges = const [],
    this.ready = false,
    this.loading = true,
    this.error,
  });

  final List<ChallengeData> challenges;
  final bool ready;
  final bool loading;
  final Object? error;

  ChallengeData? byId(String spaceId) {
    for (final c in challenges) {
      if (c.spaceId == spaceId) return c;
    }
    return null;
  }
}

/// Reads one space's challenge, members and progress.
Future<ChallengeData> readChallenge(SpaceEntry entry, String myUserId) async {
  final space = entry.space;
  if (space == null) return ChallengeData(entry: entry, myUserId: myUserId);
  Challenge? challenge;
  final progress = <String, ChallengeProgress>{};
  for (final item in await space.store.all()) {
    if (item.deleted) continue;
    if (item.itemId == Challenge.itemId) {
      challenge = Challenge.fromJson(item.json);
    } else if (item.itemId.startsWith(ChallengeProgress.prefix)) {
      final p = ChallengeProgress.fromJson(item.itemId, item.json);
      if (p != null) progress[p.userId] = p;
    }
  }
  final members = {for (final m in space.members) m.userId: m.name};
  return ChallengeData(
    entry: entry,
    myUserId: myUserId,
    challenge: challenge,
    members: members,
    // People who left don't stay on the board.
    progress: {
      for (final e in progress.entries)
        if (members.containsKey(e.key)) e.key: e.value,
    },
  );
}

/// Every challenge this account is in, newest first by start date.
final challengesProvider = FutureProvider<ChallengesState>((ref) async {
  ref.watch(challengesRevisionProvider);
  final spaces = ref.watch(ztSpacesProvider);
  final myUserId = ref.watch(accountServiceProvider).currentUserId ?? '';
  final out = <ChallengeData>[];
  for (final e in spaces.entries) {
    out.add(await readChallenge(e, myUserId));
  }
  out.sort((a, b) {
    final sa = a.challenge?.start ?? '9999';
    final sb = b.challenge?.start ?? '9999';
    return sb.compareTo(sa);
  });
  return ChallengesState(
    challenges: out,
    ready: spaces.ready,
    loading: spaces.loading,
    error: spaces.error,
  );
});

/// People waiting to be let into challenges this account administers.
final pendingChallengeJoinsProvider = FutureProvider<List<PendingJoin>>((
  ref,
) async {
  final state = await ref.watch(challengesProvider.future);
  final spaces = ref.read(ztSpacesProvider.notifier);
  final out = <PendingJoin>[];
  for (final c in state.challenges) {
    if (!c.isAdmin || c.entry.space == null) continue;
    try {
      out.addAll(await spaces.pendingJoins(c.spaceId));
    } on Object {
      // offline: shown on the next refresh
    }
  }
  return out;
});

/// The name this account last used in a challenge.
final challengeProfileProvider = FutureProvider<ChallengeProfile>((ref) async {
  ref.watch(challengesRevisionProvider);
  final store = await ref.watch(ztLocalStoreProvider.future);
  final item = await store.get(ChallengeProfile.itemId);
  return ChallengeProfile.fromJson(
    item == null || item.deleted ? null : item.json,
  );
});

final challengeActionsProvider = Provider<ChallengeActions>(
  ChallengeActions.new,
);

class ChallengeActions {
  ChallengeActions(this._ref);
  final Ref _ref;

  SpacesController get _spaces => _ref.read(ztSpacesProvider.notifier);
  void _bump() => _ref.read(challengesRevisionProvider.notifier).bump();

  Future<void> rememberName(String name) async {
    final current = await _ref.read(challengeProfileProvider.future);
    if (current.name == name) return;
    await _ref
        .read(ztSyncControllerProvider.notifier)
        .save(ChallengeProfile.itemId, ChallengeProfile(name: name).toJson());
  }

  /// Starts a challenge with this account as its admin.
  Future<String> create(Challenge challenge, {required String myName}) async {
    await rememberName(myName);
    final space = await _spaces.create(myName: myName);
    await _spaces.save(space.id, Challenge.itemId, challenge.toJson());
    _bump();
    unawaited(publishAll());
    return space.id;
  }

  /// Changes a challenge's details (admins only).
  Future<void> update(String spaceId, Challenge challenge) async {
    await _spaces.save(spaceId, Challenge.itemId, challenge.toJson());
    _bump();
    unawaited(publishAll());
  }

  Future<JoinStarted> join(
    SpaceInviteLink link, {
    required String myName,
  }) async {
    await rememberName(myName);
    final started = await _spaces.answer(link, myName: myName);
    _bump();
    return started;
  }

  Future<void> confirm(PendingJoin join) async {
    await _spaces.confirm(join);
    _bump();
  }

  Future<void> decline(PendingJoin join) async {
    await _spaces.revokeInvite(join.inviteId);
    _bump();
  }

  Future<void> removeMember(String spaceId, String userId) async {
    await _spaces.remove(spaceId, userId);
    _bump();
  }

  Future<void> leave(String spaceId) async {
    await _spaces.leave(spaceId);
    _bump();
  }

  Future<void> delete(String spaceId) async {
    await _spaces.deleteSpace(spaceId);
    _bump();
  }

  Future<void> syncNow() async {
    await _spaces.refresh();
    await _spaces.syncAll();
    _bump();
  }

  Future<void>? _publishing;
  bool _again = false;

  /// Shares this account's progress with every running challenge (and for
  /// a few days after one ends, so late syncs still count). Only writes when
  /// the numbers changed.
  Future<void> publishAll() {
    if (_publishing != null) {
      _again = true;
      return _publishing!;
    }
    return _publishing = _publish().whenComplete(() {
      _publishing = null;
      if (_again) {
        _again = false;
        publishAll();
      }
    });
  }

  Future<void> _publish() async {
    final vault = _ref.read(openFitnessVaultProvider);
    if (vault == null) return;
    final state = await _ref.read(challengesProvider.future);
    final today = _ref.read(challengeTodayProvider)();
    var wrote = false;
    Map<String, Map<String, num>>? days;
    for (final c in state.challenges) {
      final challenge = c.challenge;
      if (challenge == null || c.entry.space == null) continue;
      if (!c.members.containsKey(c.myUserId)) continue;
      if (scoresClosed(challenge, today)) continue;
      days ??= await _dayValues(vault);
      final p = computeProgress(
        c: challenge,
        userId: c.myUserId,
        dayValues: days[challenge.metric.dayKey] ?? const {},
        today: today,
      );
      if (p == null || p.sameAs(c.progress[c.myUserId])) continue;
      try {
        await _spaces.save(
          c.spaceId,
          ChallengeProgress.itemIdFor(c.myUserId),
          p.toJson(),
        );
        wrote = true;
      } on Object {
        // Locked or left meanwhile: the next change tries again.
      }
    }
    if (wrote) _bump();
  }

  static Future<Map<String, Map<String, num>>> _dayValues(
    FitnessVault vault,
  ) async {
    final out = <String, Map<String, num>>{};
    for (final row in await vault.fetchDailyMetrics()) {
      final key = row['date_key'] as String;
      final metrics = row['metrics'] as Map<String, num>;
      for (final m in ChallengeMetric.values) {
        final v = metrics[m.dayKey];
        if (v != null) (out[m.dayKey] ??= {})[key] = v;
      }
    }
    return out;
  }
}

/// What each challenge counts and when, to notice an organiser's edit.
String challengeRulesKey(List<ChallengeData> list) => [
  for (final c in list)
    '${c.spaceId}:${c.members.containsKey(c.myUserId)}:'
        '${c.challenge?.toJson()}',
].join('|');

/// Days after a challenge ends that phones still update their totals
/// (a day logged late, a phone that was offline on the last day).
const int publishGraceDays = 3;

/// Whether [c] ended so long ago that phones no longer update their totals.
/// Its rules can't be edited then: the scores would stay counted the old
/// way under the new rules.
bool scoresClosed(Challenge c, String today) =>
    today.compareTo(addDays(c.end, publishGraceDays)) > 0;

/// Keeps this account's challenge progress up to date while unlocked: when
/// its own days change and when challenges arrive or change. Watched by the
/// main screen.
final challengePublisherProvider = Provider<void>((ref) {
  Timer? timer;
  void schedule() {
    timer?.cancel();
    timer = Timer(const Duration(seconds: 3), () {
      ref.read(challengeActionsProvider).publishAll();
    });
  }

  ref.listen(fitnessVaultChangesProvider, (_, _) => schedule());
  ref.listen(challengesProvider, (prev, next) {
    final now = next.value?.challenges;
    if (now == null) return;
    // New challenges (a join confirmed) or changed rules (metric, target,
    // dates edited by an organiser): recount under the current rules.
    final before = prev?.value?.challenges;
    if (before == null ||
        challengeRulesKey(before) != challengeRulesKey(now) ||
        now.any((c) => c.challenge != null && c.mine?.hasData != true)) {
      schedule();
    }
  });
  ref.onDispose(() => timer?.cancel());
});
