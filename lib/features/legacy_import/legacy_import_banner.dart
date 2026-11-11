import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_fitness/app/vault_providers.dart';
import 'package:zerotrust_fitness/l10n/l10n.dart';

/// Shows how bringing over data from the previous version is going, and
/// what to do when it's stuck: try again when offline, type the old
/// password once when the old data is locked under a different key.
/// Nothing while there's nothing to say.
class LegacyImportBanner extends ConsumerWidget {
  const LegacyImportBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(legacyImportProvider);
    final hasOldData = ref.watch(
      vaultControllerProvider.select(
        (v) => v is VaultUnlocked && v.legacyKey != null,
      ),
    );
    if (status.done) return const SizedBox.shrink();

    final problem = status.problem;
    if (problem == null) {
      // The first run after unlock. Only accounts from before the update
      // have anything to bring over; for everyone else it's instant.
      // Once it's done it is checked again on every unlock, which takes
      // a moment, so only a run that takes a while shows.
      if (!status.running || !hasOldData) return const SizedBox.shrink();
      return _AfterAMoment(
        child: _Banner(
          icon: Icons.cloud_sync_outlined,
          text: context.l10n.bringingOverYourDataFrom,
          busy: true,
          actions: [],
        ),
      );
    }

    final controller = ref.read(legacyImportProvider.notifier);
    final busy = status.running;
    return switch (problem) {
      LegacyImportProblem.offline => _Banner(
        icon: Icons.cloud_off_outlined,
        text:
            context.l10n.yourDataFromThePrevious,
        busy: busy,
        actions: [
          TextButton(
            onPressed: busy ? null : () => _retry(context, controller),
            child: Text(context.l10n.tryAgain),
          ),
        ],
      ),
      LegacyImportProblem.locked => _Banner(
        icon: Icons.lock_outline,
        text: status.passwordTried
            ? context.l10n.thatPasswordDidntOpenYour
            : context.l10n.yourDataFromThePreviousX,
        busy: busy,
        actions: [
          if (status.passwordTried)
            TextButton(
              onPressed: busy ? null : () => _skip(context, controller),
              child: Text(context.l10n.skip),
            ),
          TextButton(
            onPressed: busy ? null : () => _askPassword(context, controller),
            child: Text(context.l10n.enterPassword),
          ),
        ],
      ),
      LegacyImportProblem.failed => _Banner(
        icon: Icons.error_outline,
        text:
            context.l10n.yourDataFromThePreviousXX,
        busy: busy,
        actions: [
          TextButton(
            onPressed: busy ? null : () => _retry(context, controller),
            child: Text(context.l10n.tryAgain),
          ),
        ],
      ),
    };
  }

  static Future<void> _retry(
    BuildContext context,
    LegacyImportController controller,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await controller.retry();
    _report(messenger, error);
  }

  static Future<void> _askPassword(
    BuildContext context,
    LegacyImportController controller,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _OldPasswordDialog(),
    );
    if (password == null || password.isEmpty) return;
    final error = await controller.retryWithPassword(password);
    _report(messenger, error);
  }

  static Future<void> _skip(
    BuildContext context,
    LegacyImportController controller,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.skipTheLockedData),
        content: Text(
          context.l10n.whateverNoPasswordOpenedStays,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.skip),
          ),
        ],
      ),
    );
    if (ok != true) return;
    _report(messenger, await controller.skipUnreadable());
  }

  /// Says what happened, so a tap is never silent.
  static void _report(ScaffoldMessengerState messenger, Object? error) {
    final text = switch (error) {
      null => currentL10n.yourDataFromThePreviousXXX,
      VaultIsLocked() => null,
      _ => switch (LegacyImportStatus(error: error).problem) {
        LegacyImportProblem.offline =>
          currentL10n.stillCouldntReachTheServer,
        LegacyImportProblem.locked =>
          currentL10n.thatPasswordDidntOpenIt,
        _ => currentL10n.thatDidntWorkTryAgain,
      },
    };
    if (text == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}

class _AfterAMoment extends StatefulWidget {
  const _AfterAMoment({required this.child});
  final Widget child;

  @override
  State<_AfterAMoment> createState() => _AfterAMomentState();
}

class _AfterAMomentState extends State<_AfterAMoment> {
  Timer? _timer;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _shown ? widget.child : const SizedBox.shrink();
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.text,
    required this.busy,
    required this.actions,
  });

  final IconData icon;
  final String text;
  final bool busy;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: MaterialBanner(
        leading: busy
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Icon(icon),
        content: Text(text),
        actions: actions.isEmpty ? const [SizedBox.shrink()] : actions,
      ),
    );
  }
}

class _OldPasswordDialog extends StatefulWidget {
  const _OldPasswordDialog();

  @override
  State<_OldPasswordDialog> createState() => _OldPasswordDialogState();
}

class _OldPasswordDialogState extends State<_OldPasswordDialog> {
  final _controller = TextEditingController();
  bool _obscured = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.passwordFromBeforeTheUpdate),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.thePasswordZeroTrustFitness,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: _obscured,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: context.l10n.oldPassword,
              suffixIcon: IconButton(
                tooltip: _obscured ? context.l10n.showPassword : context.l10n.hidePassword,
                icon: Icon(_obscured ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscured = !_obscured),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(context.l10n.unlock)),
      ],
    );
  }
}
