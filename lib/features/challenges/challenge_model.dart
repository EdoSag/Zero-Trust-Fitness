/// Challenges with friends (roadmap F11): the data each challenge keeps in
/// its shared space, and the pure rules that turn it into a leaderboard.
///
/// A challenge is one Zero-Trust shared space (core Z24). Inside it, all
/// encrypted for the members only:
/// - `challenge`: what is measured and when, written by the space's admins;
/// - `progress/<userId>`: one person's running total and the number of days
///   they reached the daily target, written only by that person (the core
///   refuses rows written in someone else's name).
///
/// Nobody shares their days, workouts or any other metric: only the one
/// number the challenge measures, summed over the challenge's dates.
library;

/// What a challenge counts.
enum ChallengeMetric {
  steps('steps'),
  heartPoints('heart_points');

  const ChallengeMetric(this.dayKey);

  /// The key of this metric in a Fitness day.
  final String dayKey;

  static ChallengeMetric parse(String? value) => ChallengeMetric.values
      .firstWhere((m) => m.name == value, orElse: () => ChallengeMetric.steps);
}

/// How a challenge is won.
enum ChallengeGoal {
  /// The highest total over the challenge's days.
  mostTotal,

  /// The most days that reach [Challenge.dailyTarget] (ties: higher total).
  dailyTarget;

  static ChallengeGoal parse(String? value) => ChallengeGoal.values.firstWhere(
    (g) => g.name == value,
    orElse: () => ChallengeGoal.mostTotal,
  );
}

enum ChallengeStatus { upcoming, active, finished }

/// Dates are local calendar days as `YYYY-MM-DD` (the same keys Fitness
/// uses for its days), so each person counts their own days where they are.
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime parseDateKey(String key) {
  final p = key.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// [days] after [key] (negative goes back).
String addDays(String key, int days) {
  final d = parseDateKey(key);
  return dateKey(DateTime(d.year, d.month, d.day + days));
}

/// Days from [from] to [to] (0 when the same day).
int daysBetween(String from, String to) {
  final a = parseDateKey(from);
  final b = parseDateKey(to);
  // UTC dates: local days can be 23 or 25 hours long around a
  // daylight-saving change.
  return DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}

class Challenge {
  const Challenge({
    required this.title,
    required this.metric,
    required this.goal,
    required this.start,
    required this.end,
    this.dailyTarget,
  });

  static const String itemId = 'challenge';
  static const String kind = 'challenge';

  /// Longest challenge: about three months.
  static const int maxDays = 92;

  final String title;
  final ChallengeMetric metric;
  final ChallengeGoal goal;

  /// First and last day, both counted.
  final String start;
  final String end;

  /// For [ChallengeGoal.dailyTarget]: the value a day must reach.
  final int? dailyTarget;

  int get lengthDays => daysBetween(start, end) + 1;

  ChallengeStatus statusOn(String today) {
    if (today.compareTo(start) < 0) return ChallengeStatus.upcoming;
    if (today.compareTo(end) > 0) return ChallengeStatus.finished;
    return ChallengeStatus.active;
  }

  /// Days left including today, while active.
  int daysLeftOn(String today) => statusOn(today) == ChallengeStatus.active
      ? daysBetween(today, end) + 1
      : 0;

  /// Why this challenge isn't valid, or null.
  static String? problem({
    required String title,
    required ChallengeGoal goal,
    required String start,
    required String end,
    int? dailyTarget,
  }) {
    if (title.trim().isEmpty) return 'title';
    if (end.compareTo(start) < 0) return 'dates';
    if (daysBetween(start, end) + 1 > maxDays) return 'dates';
    if (goal == ChallengeGoal.dailyTarget &&
        (dailyTarget == null || dailyTarget <= 0)) {
      return 'target';
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'kind': kind,
    'v': 1,
    'title': title.trim(),
    'metric': metric.name,
    'goal': goal.name,
    'start': start,
    'end': end,
    if (goal == ChallengeGoal.dailyTarget) 'dailyTarget': dailyTarget,
  };

  /// Null when [json] isn't a readable challenge.
  static Challenge? fromJson(Map<String, Object?>? json) {
    if (json == null || json['kind'] != kind) return null;
    final start = json['start'];
    final end = json['end'];
    final key = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (start is! String || end is! String) return null;
    if (!key.hasMatch(start) || !key.hasMatch(end)) return null;
    final target = json['dailyTarget'];
    return Challenge(
      title: (json['title'] as String?) ?? '',
      metric: ChallengeMetric.parse(json['metric'] as String?),
      goal: ChallengeGoal.parse(json['goal'] as String?),
      start: start,
      end: end,
      dailyTarget: target is num ? target.round() : null,
    );
  }
}

/// What one person shares with a challenge.
class ChallengeProgress {
  const ChallengeProgress({
    required this.userId,
    required this.total,
    required this.daysMet,
    required this.through,
  });

  static const String kind = 'challenge_progress';
  static const String prefix = 'progress/';
  static String itemIdFor(String userId) => '$prefix$userId';

  final String userId;

  /// Sum of the metric over the challenge's days so far.
  final int total;

  /// Days that reached the daily target (0 for "most total" challenges).
  final int daysMet;

  /// The last day counted (today while the challenge runs).
  final String through;

  Map<String, Object?> toJson() => {
    'kind': kind,
    'v': 1,
    'userId': userId,
    'total': total,
    'daysMet': daysMet,
    'through': through,
  };

  /// Only the owner's own row counts: [itemId] must name [json]'s user.
  static ChallengeProgress? fromJson(
    String itemId,
    Map<String, Object?>? json,
  ) {
    if (json == null || json['kind'] != kind) return null;
    final userId = json['userId'];
    if (userId is! String || itemId != itemIdFor(userId)) return null;
    final total = json['total'];
    final daysMet = json['daysMet'];
    final through = json['through'];
    return ChallengeProgress(
      userId: userId,
      total: total is num && total >= 0 ? total.round() : 0,
      daysMet: daysMet is num && daysMet >= 0 ? daysMet.round() : 0,
      through: through is String ? through : '',
    );
  }

  bool sameAs(ChallengeProgress? other) =>
      other != null &&
      other.userId == userId &&
      other.total == total &&
      other.daysMet == daysMet &&
      other.through == through;
}

/// This person's progress in [c], from their own days ([dayValues]: date
/// key to the challenge's metric), counted up to [today]. Null before the
/// challenge starts.
ChallengeProgress? computeProgress({
  required Challenge c,
  required String userId,
  required Map<String, num> dayValues,
  required String today,
}) {
  if (c.statusOn(today) == ChallengeStatus.upcoming) return null;
  final through = today.compareTo(c.end) > 0 ? c.end : today;
  var total = 0;
  var daysMet = 0;
  for (final e in dayValues.entries) {
    if (e.key.compareTo(c.start) < 0 || e.key.compareTo(through) > 0) continue;
    final v = e.value.isFinite && e.value > 0 ? e.value.round() : 0;
    total += v;
    final target = c.dailyTarget;
    if (c.goal == ChallengeGoal.dailyTarget && target != null && v >= target) {
      daysMet++;
    }
  }
  return ChallengeProgress(
    userId: userId,
    total: total,
    daysMet: daysMet,
    through: through,
  );
}

/// One row of the leaderboard.
class Standing {
  const Standing({
    required this.userId,
    required this.name,
    required this.rank,
    required this.score,
    required this.total,
    required this.daysMet,
    required this.hasData,
  });

  final String userId;
  final String name;

  /// 1 is first; people with the same score share a rank.
  final int rank;

  /// What decides the order: the total, or days that met the target.
  final int score;
  final int total;
  final int daysMet;

  /// False until this person's phone has shared anything.
  final bool hasData;
}

/// The leaderboard for [c] among [members] (user id to name).
List<Standing> standings({
  required Challenge c,
  required Map<String, String> members,
  required Map<String, ChallengeProgress> progress,
}) {
  final byDays = c.goal == ChallengeGoal.dailyTarget;
  final rows = [
    for (final m in members.entries)
      (userId: m.key, name: m.value, p: progress[m.key]),
  ];
  int primary(({String userId, String name, ChallengeProgress? p}) r) =>
      byDays ? (r.p?.daysMet ?? 0) : (r.p?.total ?? 0);
  int secondary(({String userId, String name, ChallengeProgress? p}) r) =>
      byDays ? (r.p?.total ?? 0) : 0;
  rows.sort((a, b) {
    final s = primary(b).compareTo(primary(a));
    if (s != 0) return s;
    final t = secondary(b).compareTo(secondary(a));
    if (t != 0) return t;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  final out = <Standing>[];
  for (var i = 0; i < rows.length; i++) {
    final r = rows[i];
    final tie =
        i > 0 &&
        primary(rows[i - 1]) == primary(r) &&
        secondary(rows[i - 1]) == secondary(r);
    out.add(
      Standing(
        userId: r.userId,
        name: r.name,
        rank: tie ? out[i - 1].rank : i + 1,
        score: primary(r),
        total: r.p?.total ?? 0,
        daysMet: r.p?.daysMet ?? 0,
        hasData: r.p != null,
      ),
    );
  }
  return out;
}

/// The name this account goes by in challenges, kept in its own synced
/// store (never in a space) so every device suggests it.
class ChallengeProfile {
  const ChallengeProfile({required this.name});

  static const String itemId = 'fitness.challenge-profile';
  static const String kind = 'challenge_profile';

  final String name;

  Map<String, Object?> toJson() => {'kind': kind, 'name': name};

  static ChallengeProfile fromJson(Map<String, Object?>? json) =>
      ChallengeProfile(name: (json?['name'] as String?) ?? '');
}
