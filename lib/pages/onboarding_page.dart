import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zerotrust_fitness/features/app/providers.dart';
import 'package:zerotrust_fitness/features/app/onboarding_notifier.dart';
import 'package:zerotrust_fitness/globals/app_state.dart';
import 'package:zerotrust_fitness/main.dart';
import 'package:zerotrust_fitness/pages/permissions_page.dart';

enum _OnboardingMode { create, restore }

class FirstTimeOnboardingPage extends ConsumerStatefulWidget {
  const FirstTimeOnboardingPage({super.key});

  @override
  ConsumerState<FirstTimeOnboardingPage> createState() =>
      _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<FirstTimeOnboardingPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pageController = PageController();

  _OnboardingMode _mode = _OnboardingMode.create;
  bool _obscurePassword = true;
  bool _enableBiometrics = true;
  bool _isBusy = false;
  int _currentStep = 0;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    setState(() => _currentStep = step);
    if (reduceMotion) {
      _pageController.jumpToPage(step);
    } else {
      _pageController.animateToPage(
        step,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCredentials() {
    final email = _emailController.text.trim();
    final pwd = _passwordController.text;
    if (email.isEmpty) {
      setState(() => _passwordError = 'Email is required.');
      return false;
    }
    if (pwd.isEmpty) {
      setState(() => _passwordError = 'Password is required.');
      return false;
    }
    if (_mode == _OnboardingMode.create && pwd.length < 12) {
      setState(
          () => _passwordError = 'Password must be at least 12 characters.');
      return false;
    }
    setState(() => _passwordError = null);
    return true;
  }

  Future<void> _handleAuth() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (_enableBiometrics) {
        await ref.read(onboardingProvider.notifier).setupBiometrics();
        // Non-fatal: we continue regardless of biometric result.
      }

      if (_mode == _OnboardingMode.create) {
        await ref.read(onboardingProvider.notifier).createAccount(
              email: email,
              masterPassword: password,
              enableBiometrics: _enableBiometrics,
            );
      } else {
        await ref.read(onboardingProvider.notifier).signIn(
              email: email,
              masterPassword: password,
              enableBiometrics: _enableBiometrics,
            );
      }

      if (!mounted) return;
      final authState = ref.read(onboardingProvider);
      if (authState.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(authState.error.toString().replaceAll('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      await _postAuthInitialization(password);
      if (!mounted) return;
      _goToStep(3);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _postAuthInitialization(String masterPassword) async {
    final authState = ref.read(onboardingProvider);
    if (authState.hasError) return;

    await ref
        .read(securityEnclaveProvider.notifier)
        .initialize(masterPassword);

    final tasksInitialized =
        sharedPrefs.getBool('bg_tasks_initialized') ?? false;
    if (!tasksInitialized && mounted) {
      final appState = AppState.of(context, listen: false);
      await appState.initializeBackgroundTasks();
      await sharedPrefs.setBool('bg_tasks_initialized', true);
    }
  }

  // ---------------------------------------------------------------------------
  // Step indicator
  // ---------------------------------------------------------------------------

  Widget _buildStepIndicator() {
    final color = Theme.of(context).colorScheme.primary;
    final outline =
        Theme.of(context).colorScheme.outline.withValues(alpha: 0.3);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final isActive = i == _currentStep;
        final isCompleted = i < _currentStep;
        return AnimatedContainer(
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: (isActive || isCompleted) ? color : outline,
          ),
        );
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 0 — Vault choice
  // ---------------------------------------------------------------------------

  Widget _buildVaultChoiceStep() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.enhanced_encryption,
              size: 80, color: theme.colorScheme.primary),
          const SizedBox(height: 20),
          Text(
            'Zero-Trust Health',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Your data stays on your device, encrypted with your master password.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 40),
          _VaultChoiceCard(
            icon: Icons.lock_outline,
            title: 'Create New Vault',
            subtitle: 'First time? Set up your encrypted local vault.',
            selected: _mode == _OnboardingMode.create,
            onTap: () => setState(() => _mode = _OnboardingMode.create),
          ),
          const SizedBox(height: 12),
          _VaultChoiceCard(
            icon: Icons.cloud_download_outlined,
            title: 'Restore from Backup',
            subtitle: 'Already have an account? Sign in to restore.',
            selected: _mode == _OnboardingMode.restore,
            onTap: () => setState(() => _mode = _OnboardingMode.restore),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => _goToStep(1),
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1 — Credentials
  // ---------------------------------------------------------------------------

  Widget _buildCredentialsStep() {
    final theme = Theme.of(context);
    final isCreate = _mode == _OnboardingMode.create;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCreate ? 'Create Your Vault' : 'Sign In to Restore',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            isCreate
                ? 'Choose a strong master password. You\'ll need it every time you unlock.'
                : 'Enter your credentials to restore your encrypted backup.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_passwordError != null) {
                setState(() => _passwordError = null);
              }
            },
            decoration: InputDecoration(
              labelText: 'Master Password',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.key_outlined),
              errorText: _passwordError,
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                icon: Icon(_obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          if (isCreate) ...[
            const SizedBox(height: 8),
            Text(
              'Minimum 12 characters.',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: theme.colorScheme.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'If you forget your master password, your data cannot be recovered — we have zero access to it.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _goToStep(0),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () {
                    if (_validateCredentials()) _goToStep(2);
                  },
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2 — Biometrics
  // ---------------------------------------------------------------------------

  Widget _buildBiometricsStep() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.fingerprint, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 20),
          Text(
            'Biometric Unlock',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Use fingerprint or face ID to unlock without typing your master password each time.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 32),
          Card(
            child: SwitchListTile(
              value: _enableBiometrics,
              onChanged:
                  _isBusy ? null : (val) => setState(() => _enableBiometrics = val),
              title: const Text(
                'Enable Biometric Unlock',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                  'Your passphrase reference is stored in the secure enclave — never sent anywhere.'),
            ),
          ),
          const SizedBox(height: 40),
          if (_isBusy)
            const Center(child: CircularProgressIndicator())
          else ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _handleAuth,
                child: Text(_mode == _OnboardingMode.create
                    ? 'Create Vault'
                    : 'Restore Vault'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => _goToStep(1),
                child: const Text('Back'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3 — Permissions
  // ---------------------------------------------------------------------------

  Widget _buildPermissionsStep() {
    final theme = Theme.of(context);
    final categories = [
      (Icons.directions_run, 'Activity',
          'Steps, exercise, heart rate, hydration, nutrition'),
      (Icons.bedtime_outlined, 'Sleep', 'Sleep stages and total sleep time'),
      (Icons.monitor_heart_outlined, 'Vitals',
          'Resting HR, blood oxygen, blood pressure, blood glucose'),
      (Icons.accessibility_new_outlined, 'Body',
          'Weight, BMI, body fat percentage'),
      (Icons.location_on_outlined, 'Location',
          'GPS tracking for outdoor workouts'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.health_and_safety_outlined,
              size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Health Permissions',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Grant access to Health Connect so Zero-Trust Health can read your data. Everything stays on device — only you can see it.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 24),
          ...categories.map((cat) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  tileColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  leading: Icon(cat.$1, color: theme.colorScheme.primary),
                  title: Text(cat.$2,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(cat.$3, style: theme.textTheme.bodySmall),
                ),
              )),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Grant Permissions'),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const PermissionsPage()),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Skip for Now'),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Go to Dashboard'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: _buildStepIndicator(),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildVaultChoiceStep(),
                  _buildCredentialsStep(),
                  _buildBiometricsStep(),
                  _buildPermissionsStep(),
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
// Private helper widget
// ---------------------------------------------------------------------------

class _VaultChoiceCard extends StatelessWidget {
  const _VaultChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
              : theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? theme.colorScheme.primary : theme.hintColor,
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected ? theme.colorScheme.primary : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
