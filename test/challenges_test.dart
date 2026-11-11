import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_fitness/features/challenges/challenge_model.dart';
import 'package:zerotrust_fitness/features/challenges/challenges_data.dart';
import 'package:zerotrust_fitness/features/challenges/challenges_pages.dart';
import 'package:zerotrust_fitness/l10n/l10n.dart';

import 'phone_layout.dart';

const alice = '00000000-0000-4000-8000-00000000000a';
const bob = '00000000-0000-4000-8000-00000000000b';
const carol = '00000000-0000-4000-8000-00000000000c';

const steps7 = Challenge(
  title: 'November step-off',
  metric: ChallengeMetric.steps,
  goal: ChallengeGoal.mostTotal,
  start: '2026-11-10',
  end: '2026-11-16',
);

const days7 = Challenge(
  title: '10k a day',
  metric: ChallengeMetric.steps,
  goal: ChallengeGoal.dailyTarget,
  start: '2026-11-10',
  end: '2026-11-16',
  dailyTarget: 10000,
);

Uint8List dek(int seed) =>
    Uint8List.fromList(List<int>.generate(32, (i) => (seed * 7 + i) & 0xff));

/// One account's phone, on the in-memory stand-in for Supabase.
class Phone {
  Phone(this.server, this.userId, this.seed);
  final InMemorySpaceServer server;
  final String userId;
  final int seed;
  final Map<String, InMemoryItemStore> stores = {};
  late final SharedSpaces spaces;

  Future<Phone> start({SpacePolicy policy = fitnessSpacePolicy}) async {
    spaces = SharedSpaces(
      app: 'fitness',
      myUserId: userId,
      identity: await ZtIdentity.fromDek(dek(seed)),
      backend: server.backendFor(userId),
      privateStore: InMemorySpacePrivateStore(),
      openStore: (id) async => stores.putIfAbsent(id, InMemoryItemStore.new),
      deleteStore: (id) async => stores.remove(id),
      deviceId: 'phone-$userId',
      policy: policy,
    );
    return this;
  }

  Future<ChallengeData> read(String spaceId) async {
    final space = await spaces.open(spaceId);
    await spaces.sync(space);
    final info = (await spaces.list()).firstWhere((i) => i.id == spaceId);
    return readChallenge(SpaceEntry(info: info, space: space), userId);
  }

  Future<void> share(String spaceId, ChallengeProgress p) async {
    final space = await spaces.open(spaceId);
    await space.save(ChallengeProgress.itemIdFor(userId), p.toJson());
    await spaces.sync(space);
  }
}

Future<void> letIn(
  Phone admin,
  Phone friend,
  String spaceId,
  String name,
) async {
  final link = await admin.spaces.invite(spaceId);
  final joined = await friend.spaces.answer(
    SpaceInviteLink.parse(link.toString()),
    myName: name,
  );
  final pending = await admin.spaces.pendingJoins(spaceId);
  expect(pending.single.verificationCode, joined.verificationCode);
  await admin.spaces.confirm(pending.single);
  await friend.spaces.sync(await friend.spaces.open(spaceId));
}

void main() {
  group('progress', () {
    test('sums only the challenge days, up to today', () {
      final p = computeProgress(
        c: steps7,
        userId: alice,
        dayValues: {
          '2026-11-09': 50000, // before the start
          '2026-11-10': 8000,
          '2026-11-11': 12000.4,
          '2026-11-12': 99999, // "tomorrow": not counted yet
        },
        today: '2026-11-11',
      )!;
      expect(p.total, 20000);
      expect(p.through, '2026-11-11');
      expect(p.daysMet, 0);
    });

    test('daily target counts days that reached it; stops at the end', () {
      final p = computeProgress(
        c: days7,
        userId: alice,
        dayValues: {
          '2026-11-10': 10000,
          '2026-11-11': 9999,
          '2026-11-16': 15000,
          '2026-11-17': 20000, // after the end
        },
        today: '2026-11-19',
      )!;
      expect(p.daysMet, 2);
      expect(p.total, 34999);
      expect(p.through, '2026-11-16');
    });

    test('nothing before the challenge starts', () {
      expect(
        computeProgress(
          c: steps7,
          userId: alice,
          dayValues: const {'2026-11-09': 1},
          today: '2026-11-09',
        ),
        isNull,
      );
    });

    test('status and days left', () {
      expect(steps7.statusOn('2026-11-09'), ChallengeStatus.upcoming);
      expect(steps7.statusOn('2026-11-10'), ChallengeStatus.active);
      expect(steps7.daysLeftOn('2026-11-10'), 7);
      expect(steps7.daysLeftOn('2026-11-16'), 1);
      expect(steps7.statusOn('2026-11-17'), ChallengeStatus.finished);
      expect(steps7.lengthDays, 7);
      // Across a daylight-saving change.
      expect(daysBetween('2026-03-25', '2026-04-01'), 7);
      expect(addDays('2026-12-30', 3), '2027-01-02');
      // Every day of the year counts once, whatever the phone's time zone.
      for (var d = 0; d < 366; d++) {
        expect(daysBetween('2026-01-01', addDays('2026-01-01', d)), d);
      }
    });

    test('validation', () {
      expect(
        Challenge.problem(
          title: ' ',
          goal: ChallengeGoal.mostTotal,
          start: '2026-11-10',
          end: '2026-11-11',
        ),
        'title',
      );
      expect(
        Challenge.problem(
          title: 'x',
          goal: ChallengeGoal.mostTotal,
          start: '2026-11-10',
          end: '2027-03-10',
        ),
        'dates',
      );
      expect(
        Challenge.problem(
          title: 'x',
          goal: ChallengeGoal.dailyTarget,
          start: '2026-11-10',
          end: '2026-11-11',
        ),
        'target',
      );
    });

    test('json round trip; a progress row must name its own owner', () {
      final c = Challenge.fromJson(days7.toJson())!;
      expect(c.title, days7.title);
      expect(c.goal, ChallengeGoal.dailyTarget);
      expect(c.dailyTarget, 10000);
      final p = ChallengeProgress(
        userId: bob,
        total: 5,
        daysMet: 1,
        through: '2026-11-11',
      );
      expect(
        ChallengeProgress.fromJson(
          ChallengeProgress.itemIdFor(bob),
          p.toJson(),
        ),
        isNotNull,
      );
      expect(
        ChallengeProgress.fromJson(
          ChallengeProgress.itemIdFor(alice),
          p.toJson(),
        ),
        isNull,
      );
    });
  });

  group('leaderboard', () {
    test('ranks by total; ties share a rank; no data counts as zero', () {
      final board = standings(
        c: steps7,
        members: {alice: 'Alice', bob: 'Bob', carol: 'Carol'},
        progress: {
          alice: const ChallengeProgress(
            userId: alice,
            total: 900,
            daysMet: 0,
            through: '2026-11-11',
          ),
          bob: const ChallengeProgress(
            userId: bob,
            total: 900,
            daysMet: 0,
            through: '2026-11-11',
          ),
        },
      );
      expect(board.map((s) => s.name), ['Alice', 'Bob', 'Carol']);
      expect(board.map((s) => s.rank), [1, 1, 3]);
      expect(board.last.hasData, isFalse);
    });

    test('daily target ranks by days, then by total', () {
      final board = standings(
        c: days7,
        members: {alice: 'Alice', bob: 'Bob'},
        progress: {
          alice: const ChallengeProgress(
            userId: alice,
            total: 30000,
            daysMet: 2,
            through: '2026-11-12',
          ),
          bob: const ChallengeProgress(
            userId: bob,
            total: 31000,
            daysMet: 2,
            through: '2026-11-12',
          ),
        },
      );
      expect(board.first.name, 'Bob');
      expect(board.map((s) => s.rank), [1, 2]);
    });
  });

  test('an organiser editing the rules changes the rules key', () {
    ChallengeData data(Challenge c) => ChallengeData(
      entry: const SpaceEntry(
        info: SpaceInfo(
          id: 's1',
          app: 'fitness',
          keyEpoch: 1,
          myRole: SpaceRole.member,
        ),
      ),
      myUserId: bob,
      challenge: c,
      members: {bob: 'Bob'},
    );
    final edited = Challenge(
      title: steps7.title,
      metric: ChallengeMetric.heartPoints,
      goal: steps7.goal,
      start: steps7.start,
      end: steps7.end,
    );
    expect(
      challengeRulesKey([data(steps7)]),
      isNot(challengeRulesKey([data(edited)])),
    );
    expect(
      challengeRulesKey([data(steps7)]),
      challengeRulesKey([data(steps7)]),
    );
  });

  group('shared challenge', () {
    late InMemorySpaceServer server;
    late Phone a, b;

    setUp(() async {
      server = InMemorySpaceServer();
      a = await Phone(server, alice, 1).start();
      b = await Phone(server, bob, 2).start();
    });

    test('both phones see the challenge and one leaderboard', () async {
      final space = await a.spaces.create(myName: 'Alice');
      await space.save(Challenge.itemId, steps7.toJson());
      await a.spaces.sync(space);
      await letIn(a, b, space.id, 'Bob');

      await a.share(
        space.id,
        computeProgress(
          c: steps7,
          userId: alice,
          dayValues: {'2026-11-10': 7000},
          today: '2026-11-10',
        )!,
      );
      await b.share(
        space.id,
        computeProgress(
          c: steps7,
          userId: bob,
          dayValues: {'2026-11-10': 9000},
          today: '2026-11-10',
        )!,
      );

      for (final phone in [a, b]) {
        final data = await phone.read(space.id);
        expect(data.challenge?.title, steps7.title);
        expect(data.members, {alice: 'Alice', bob: 'Bob'});
        expect(data.board.map((s) => '${s.name} ${s.total}'), [
          'Bob 9000',
          'Alice 7000',
        ]);
      }
      expect((await b.read(space.id)).isAdmin, isFalse);
      expect((await a.read(space.id)).isAdmin, isTrue);
    });

    test('the server only ever holds ciphertext', () async {
      final space = await a.spaces.create(myName: 'Alice');
      await space.save(Challenge.itemId, steps7.toJson());
      await a.share(
        space.id,
        const ChallengeProgress(
          userId: alice,
          total: 123456,
          daysMet: 0,
          through: '2026-11-10',
        ),
      );
      for (final row in server.rowsOf(space.id)) {
        final text = String.fromCharCodes(row.dataBlob ?? Uint8List(0));
        expect(text, isNot(contains('123456')));
        expect(text, isNot(contains('November')));
      }
    });

    test('a friend can neither change the challenge nor post as someone '
        'else', () async {
      final space = await a.spaces.create(myName: 'Alice');
      await space.save(Challenge.itemId, steps7.toJson());
      await a.spaces.sync(space);
      await letIn(a, b, space.id, 'Bob');
      final bs = await b.spaces.open(space.id);

      expect(
        () => bs.save(ChallengeProgress.itemIdFor(alice), {
          'kind': ChallengeProgress.kind,
          'userId': alice,
          'total': 1,
        }),
        throwsArgumentError,
      );

      // A changed app that skips both checks: the server refuses the
      // admin-only row, and Alice's phone rejects the forged progress.
      server.enforceAdminOnly = false;
      final rogue = SharedSpaces(
        app: 'fitness',
        myUserId: bob,
        identity: await ZtIdentity.fromDek(dek(2)),
        backend: server.backendFor(bob),
        privateStore: InMemorySpacePrivateStore()
          ..items[SharedSpaces.anchorId(space.id)] = (await _anchorOf(
            b,
            space.id,
          ))!,
        openStore: (id) async => InMemoryItemStore(),
        deviceId: 'rogue',
      );
      final rs = await rogue.open(space.id);
      await rogue.sync(rs);
      await rs.save(Challenge.itemId, {
        ...steps7.toJson(),
        'title': 'Hijacked',
      });
      await rs.save(ChallengeProgress.itemIdFor(alice), {
        'kind': ChallengeProgress.kind,
        'userId': alice,
        'total': 1,
        'daysMet': 0,
        'through': '2026-11-10',
      });
      await rogue.sync(rs);

      final data = await a.read(space.id);
      expect(data.challenge?.title, steps7.title);
      expect(data.progress[alice], isNull);
    });
  });

  group('screens', () {
    Widget app(
      ChallengesState state,
      Widget home, {
      Locale? locale,
      String today = '2026-11-12',
    }) =>
        ProviderScope(
          overrides: [
            challengesProvider.overrideWith((ref) async => state),
            pendingChallengeJoinsProvider.overrideWith((ref) async => []),
            challengeTodayProvider.overrideWithValue(() => today),
          ],
          child: MaterialApp(
            theme: appTheme,
            locale: locale,
            localizationsDelegates: const [
              AppL10n.delegate,
              ...ZtLanguages.delegates,
            ],
            supportedLocales: ZtLanguages.supported,
            home: home,
          ),
        );

    ChallengeData sample() => ChallengeData(
      entry: const SpaceEntry(
        info: SpaceInfo(
          id: 's1',
          app: 'fitness',
          keyEpoch: 1,
          myRole: SpaceRole.admin,
        ),
      ),
      myUserId: alice,
      challenge: steps7,
      members: {
        alice: 'Alice',
        bob: 'Bob with a really quite long name for a phone',
        carol: 'Carol',
      },
      progress: {
        alice: const ChallengeProgress(
          userId: alice,
          total: 21500,
          daysMet: 0,
          through: '2026-11-12',
        ),
        bob: const ChallengeProgress(
          userId: bob,
          total: 30250,
          daysMet: 0,
          through: '2026-11-12',
        ),
      },
    );

    ChallengesState state() =>
        ChallengesState(challenges: [sample()], ready: true, loading: false);

    testWidgets('leaderboard rows keep names and numbers apart', (
      tester,
    ) async {
      await usePhoneScreen(tester);
      await tester.pumpWidget(
        app(state(), const ChallengeDetailPage(spaceId: 's1')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final bobName = find.textContaining('Bob with');
      final bobTotal = find.text('30,250');
      expect(bobName, findsOneWidget);
      expect(bobTotal, findsOneWidget);
      // Bob leads, so his row is above Alice's.
      expect(
        tester.getTopLeft(bobTotal).dy,
        lessThan(tester.getTopLeft(find.text('21,500')).dy),
      );
      // The name ends before the number starts (no overlap).
      expect(
        tester.getRect(bobName).right,
        lessThanOrEqualTo(tester.getRect(bobTotal).left),
      );
      expect(find.text('Alice (you)'), findsOneWidget);
      expect(find.text('No data yet'), findsOneWidget);
    });

    testWidgets('Edit is offered until the scores close, not after', (
      tester,
    ) async {
      for (final (today, shown) in [('2026-11-12', true), ('2026-12-30', false)]) {
        await tester.pumpWidget(
          app(
            state(),
            ChallengeDetailPage(key: ValueKey(today), spaceId: 's1'),
            today: today,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        expect(find.text('Edit challenge'), shown ? findsOneWidget : findsNothing);
        expect(find.text('Delete'), findsOneWidget);
        await tester.tapAt(Offset.zero);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('list shows the challenge with my rank, and both buttons '
        'are on screen', (tester) async {
      await usePhoneScreen(tester);
      await tester.pumpWidget(app(state(), const ChallengesPage()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(steps7.title), findsOneWidget);
      expect(find.text('#2 of 3'), findsOneWidget);
      expect(find.text('5 days left'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Join with an invite'), 100);
      expectTappableOnScreen(tester, find.text('Start a challenge'));
      expectTappableOnScreen(tester, find.text('Join with an invite'));
    });

    testWidgets('empty list explains what is shared', (tester) async {
      await usePhoneScreen(tester);
      await tester.pumpWidget(
        app(
          const ChallengesState(ready: true, loading: false),
          const ChallengesPage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Challenge your friends'), findsOneWidget);
      expect(find.textContaining('only one number'), findsOneWidget);
    });

    testWidgets('Hebrew leaderboard reads right to left', (tester) async {
      await usePhoneScreen(tester);
      await tester.pumpWidget(
        app(
          state(),
          const ChallengeDetailPage(spaceId: 's1'),
          locale: const Locale('he'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('טבלת מובילים'), findsOneWidget);
      // The rank badge is on the right, the total on the left.
      final badge = tester.getCenter(find.text('1'));
      final total = tester.getCenter(find.text('30,250'));
      expect(badge.dx, greaterThan(total.dx));
    });

    testWidgets('create form fits a phone and validates', (tester) async {
      await usePhoneScreen(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            challengeTodayProvider.overrideWithValue(() => '2026-11-12'),
            challengeProfileProvider.overrideWith(
              (ref) async => const ChallengeProfile(name: 'Alice'),
            ),
          ],
          child: MaterialApp(
            theme: appTheme,
            localizationsDelegates: const [
              AppL10n.delegate,
              ...ZtLanguages.delegates,
            ],
            supportedLocales: ZtLanguages.supported,
            home: const ChallengeEditorPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Daily target'));
      await tester.pumpAndSettle();
      expect(find.text('Daily target (Steps)'), findsOneWidget);
      final save = find.text('Create and invite friends');
      // To the end of the form: the button must clear the gesture bar.
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expectTappableOnScreen(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, 3000));
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsOneWidget); // the empty title
      expect(find.text('Alice'), findsOneWidget);
    });
  });
}

Future<Map<String, Object?>?> _anchorOf(Phone p, String spaceId) async {
  // The joiner's private note, as their own phone wrote it.
  final store = p.spaces.privateStore;
  return store.read(SharedSpaces.anchorId(spaceId));
}
