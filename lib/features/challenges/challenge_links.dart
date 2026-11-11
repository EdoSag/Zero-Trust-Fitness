import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_fitness/features/challenges/challenges_data.dart';
import 'package:zerotrust_fitness/features/challenges/challenges_pages.dart';
import 'package:zerotrust_fitness/platform/links.dart';

/// Around the unlocked app: opens challenge invite links the app was opened
/// with (they wait while signed out or locked), and keeps this account's
/// challenge progress shared.
class ChallengeLinks extends ConsumerStatefulWidget {
  const ChallengeLinks({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ChallengeLinks> createState() => _ChallengeLinksState();
}

class _ChallengeLinksState extends ConsumerState<ChallengeLinks> {
  StreamSubscription<void>? _links;

  @override
  void initState() {
    super.initState();
    _links = IncomingLinks.instance.arrived.listen((_) => _take());
    WidgetsBinding.instance.addPostFrameCallback((_) => _take());
  }

  @override
  void dispose() {
    _links?.cancel();
    super.dispose();
  }

  Future<void> _take() async {
    final links = await IncomingLinks.instance.take();
    for (final link in links) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => JoinChallengePage(initialLink: link),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(challengePublisherProvider);
    return widget.child;
  }
}
