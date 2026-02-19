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

  void _handleSignUp() async {
    // Read the notifier and call the create account method
    await ref.read(onboardingProvider.notifier).createAccount(
          email: _emailController.text,
          masterPassword: _passwordController.text,
          enableBiometrics: _enableBiometrics,
        );

    // Get the updated state
    final state = ref.read(onboardingProvider);

    if (!mounted) return; // Guard against 'async gap' errors

    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error.toString().replaceAll('Exception: ', '')), 
          backgroundColor: Colors.red
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vault Initialized!')),
      );
      // Navigate to dashboard now that keys are set
      context.go('/dashboard'); 
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the provider state
    final state = ref.watch(onboardingProvider);
    // Riverpod 3.0 uses .isLoading property
    final isLoading = state.isLoading;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.enhanced_encryption, 
                  size: 80, 
                  color: Theme.of(context).colorScheme.primary
                ),
                const SizedBox(height: 16),
                const Text("Initialize Your Vault", 
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  "This creates your private encryption keys locally.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address', 
                    border: OutlineInputBorder()
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Master Password (min 12 chars)',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text("Enable Biometric Unlock"),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    child: isLoading 
                      ? const SizedBox(
                          height: 20, 
                          width: 20, 
                          child: CircularProgressIndicator(strokeWidth: 2)
                        ) 
                      : const Text("CREATE SECURE VAULT"),
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