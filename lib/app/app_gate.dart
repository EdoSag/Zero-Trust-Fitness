import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_fitness/app/auth_providers.dart';
import 'package:zerotrust_fitness/app/vault_providers.dart';
import 'package:zerotrust_fitness/components/bottom_nav_shell.dart';
import 'package:zerotrust_fitness/pages/home_page.dart';
import 'package:zerotrust_fitness/widget_service.dart';

/// Whether the welcome page was shown on this install.
final welcomeSeenProvider =
    NotifierProvider<WelcomeSeen, bool?>(WelcomeSeen.new);

class WelcomeSeen extends Notifier<bool?> {
  static const _key = 'has_seen_get_started_landing';

  @override
  bool? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state ??= prefs.getBool(_key) ?? false;
    } on Object {
      state ??= false;
    }
  }

  Future<void> markSeen() async {
    state = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } on Object {
      // Shown again next launch; harmless.
    }
  }
}

/// Routes between the welcome page, the shared account screens and the
/// dashboard.
///
/// Signed out: welcome (first launch only), then sign in or create an
/// account. Signed in but locked (cold start, auto-lock): unlock with the
/// account password or biometrics. A new recovery key is always shown, and
/// confirmed, before the vault opens.
class AppGate extends ConsumerStatefulWidget {
  const AppGate({super.key});

  @override
  ConsumerState<AppGate> createState() => _AppGateState();
}

class _AppGateState extends ConsumerState<AppGate> with WidgetsBindingObserver {
  /// Stays on the sign-in screen until it hands back a result, even though
  /// Supabase reports the session a moment earlier.
  late bool _signingIn = ref.read(currentUserProvider) == null;
  UnlockResult? _awaitingRecoveryKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// A key waiting behind the recovery-key screen is zeroed when the app
  /// leaves the foreground, so coming back asks for the password. Locking
  /// the open vault is the core's job: it follows the Auto-lock setting.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      final pending = _awaitingRecoveryKey;
      if (pending != null) {
        pending.dek.fillRange(0, pending.dek.length, 0);
        setState(() => _awaitingRecoveryKey = null);
      }
    }
  }

  void _onUnlocked(UnlockResult result) {
    if (result.newRecoveryKey != null) {
      setState(() {
        _signingIn = false;
        _awaitingRecoveryKey = result;
      });
      return;
    }
    setState(() => _signingIn = false);
    ref
        .read(vaultControllerProvider.notifier)
        .unlock(result.dek, legacyDek: result.legacyDek);
  }

  void _forgotPassword() => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ZtForgotPasswordScreen()),
      );

  @override
  Widget build(BuildContext context) {
    ref.listen(vaultControllerProvider, (_, next) {
      if (next is VaultLocked) {
        // Don't leave a page open over a locked vault, or numbers on the
        // home-screen widget.
        Navigator.of(context).popUntil((route) => route.isFirst);
        WidgetService.redactWidget().catchError((_) {});
      }
    });
    ref.listen(currentUserProvider, (_, user) {
      if (user == null) {
        ref.read(vaultControllerProvider.notifier).lock();
        setState(() => _signingIn = true);
      }
    });

    final pending = _awaitingRecoveryKey;
    if (pending != null) {
      return ZtRecoveryKeyScreen(
        recoveryKey: pending.newRecoveryKey!,
        onDone: () {
          setState(() => _awaitingRecoveryKey = null);
          ref
              .read(vaultControllerProvider.notifier)
              .unlock(pending.dek, legacyDek: pending.legacyDek);
        },
      );
    }

    if (ref.watch(passwordRecoveryProvider)) {
      return ZtResetPasswordScreen(
        onUnlocked: (result) {
          ref.read(passwordRecoveryProvider.notifier).done();
          _onUnlocked(result);
        },
      );
    }

    final user = ref.watch(currentUserProvider);
    if (user == null || _signingIn) {
      final welcomeSeen = ref.watch(welcomeSeenProvider);
      if (welcomeSeen == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (!welcomeSeen && user == null) {
        return HomePage(
          onGetStarted: () => ref.read(welcomeSeenProvider.notifier).markSeen(),
        );
      }
      return ZtSignInScreen(
        onUnlocked: _onUnlocked,
        onForgotPassword: _forgotPassword,
      );
    }

    if (ref.watch(vaultControllerProvider) is VaultLocked) {
      return ZtUnlockScreen(
        email: user.email,
        onUnlocked: _onUnlocked,
        onSignOut: () => ref.read(accountServiceProvider).signOut(),
        onForgotPassword: _forgotPassword,
      );
    }

    return const _FitnessHome();
  }
}

/// Counts any touch as activity for auto-lock. Goes in
/// `MaterialApp.builder`, above the navigator, so touches on pushed screens
/// (an editor, Settings) count too and the app doesn't lock mid-edit.
class AutoLockActivity extends ConsumerWidget {
  const AutoLockActivity({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Listener(
        onPointerDown: (_) =>
            ref.read(vaultControllerProvider.notifier).touch(),
        child: child,
      );
}

/// The dashboard once the vault's store is open and data from earlier
/// versions has been brought over (or that failed, say offline, and will
/// be retried). Sync runs while this is shown.
class _FitnessHome extends ConsumerWidget {
  const _FitnessHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(ztSyncControllerProvider);
    final vault = ref.watch(fitnessVaultProvider);
    if (vault case AsyncError(:final error) when error is! VaultIsLocked) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Couldn\'t open your fitness data on this device.'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(fitnessVaultProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return switch (ref.watch(legacyImportProvider)) {
      AsyncData() => const BottomNavShell(),
      AsyncError(:final error) when error is! VaultIsLocked =>
        const BottomNavShell(legacyImportFailed: true),
      _ => const _Opening(),
    };
  }
}

class _Opening extends StatelessWidget {
  const _Opening();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ZtBrandMark(app: ZtSuite.fitness),
            const SizedBox(height: ZtSpacing.lg),
            const CircularProgressIndicator(),
            const SizedBox(height: ZtSpacing.md),
            Text(
              'Opening your fitness data…',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
