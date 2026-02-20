import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zerotrust_fitness/features/app/onboarding_notifier.dart';

class FirstTimeOnboardingPage extends ConsumerStatefulWidget {
  const FirstTimeOnboardingPage({super.key});

  @override
  ConsumerState<FirstTimeOnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<FirstTimeOnboardingPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _enableBiometrics = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    await ref.read(onboardingProvider.notifier).createAccount(
          email: _emailController.text.trim(),
          masterPassword: _passwordController.text,
          enableBiometrics: _enableBiometrics,
        );

    _handlePostAuthFeedback(successMessage: 'Vault Initialized!');
  }

  Future<void> _handleSignIn() async {
    await ref.read(onboardingProvider.notifier).signIn(
          email: _emailController.text.trim(),
          masterPassword: _passwordController.text,
          enableBiometrics: _enableBiometrics,
        );

    _handlePostAuthFeedback(successMessage: 'Vault unlocked from cloud backup.');
  }

  void _handlePostAuthFeedback({required String successMessage}) {
    final state = ref.read(onboardingProvider);
    if (!mounted) return;

    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.enhanced_encryption,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                const Text('Initialize or Unlock Your Vault',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  'Create a new encrypted vault, or sign in to restore your encrypted backup.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Master Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Enable Biometric Unlock'),
                  value: _enableBiometrics,
                  onChanged: isLoading ? null : (val) => setState(() => _enableBiometrics = val),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _handleSignUp,
                    style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('CREATE SECURE VAULT'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: isLoading ? null : _handleSignIn,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('SIGN IN'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
