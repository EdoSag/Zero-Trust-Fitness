import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_fitness/app/vault_providers.dart';

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
      return const _AfterAMoment(
        child: _Banner(
          icon: Icons.cloud_sync_outlined,
          text: 'Bringing over your data from the previous version…',
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
            'Your data from the previous version hasn\'t been brought '
            'over yet: the server couldn\'t be reached. Check your '
            'connection and try again.',
        busy: busy,
        actions: [
          TextButton(
            onPressed: busy ? null : () => _retry(context, controller),
            child: const Text('Try again'),
          ),
        ],
      ),
      LegacyImportProblem.locked => _Banner(
        icon: Icons.lock_outline,
        text: status.passwordTried
            ? 'That password didn\'t open your data from the previous '
                  'version either. Try another password you used before, '
                  'or skip it.'
            : 'Your data from the previous version is locked with the '
                  'password you used before this update. Enter it once to '
                  'bring it over.',
        busy: busy,
        actions: [
          if (status.passwordTried)
            TextButton(
              onPressed: busy ? null : () => _skip(context, controller),
              child: const Text('Skip'),
            ),
          TextButton(
            onPressed: busy ? null : () => _askPassword(context, controller),
            child: const Text('Enter password'),
          ),
        ],
      ),
      LegacyImportProblem.failed => _Banner(
        icon: Icons.error_outline,
        text:
            'Your data from the previous version hasn\'t been brought '
            'over yet. Something went wrong; try again.',
        busy: busy,
        actions: [
          TextButton(
            onPressed: busy ? null : () => _retry(context, controller),
            child: const Text('Try again'),
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
        title: const Text('Skip the locked data?'),
        content: const Text(
          'Whatever no password opened stays where it is (the old file is '
          'kept on this phone) but won\'t show in the app. Everything else '
          'from the previous version is brought over.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Skip'),
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
      null => 'Your data from the previous version is here.',
      VaultIsLocked() => null,
      _ => switch (LegacyImportStatus(error: error).problem) {
        LegacyImportProblem.offline =>
          'Still couldn\'t reach the server. Check your connection.',
        LegacyImportProblem.locked =>
          'That password didn\'t open it. Try another one you used before.',
        _ => 'That didn\'t work. Try again in a moment.',
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
      title: const Text('Password from before the update'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The password Zero-Trust Fitness used before this update. It '
            'only unlocks your old data on this phone; it isn\'t sent '
            'anywhere and doesn\'t change your account.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: _obscured,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Old password',
              suffixIcon: IconButton(
                tooltip: _obscured ? 'Show password' : 'Hide password',
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
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Unlock')),
      ],
    );
  }
}
