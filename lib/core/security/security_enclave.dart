import 'package:cryptography/cryptography.dart';
import 'package:local_auth/local_auth.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Added this import
import 'package:zerotrust_fitness/core/security/key_derivation_service.dart';
import 'package:zerotrust_fitness/core/security/security_repository.dart';
import 'package:zerotrust_fitness/core/storage/local_vault.dart';

@NowaGenerated()
class SecurityEnclave extends Notifier<SecretKey?> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final KeyDerivationService _keyDerivationService = KeyDerivationService();

  // In Riverpod 3.0, the build method is the first thing called.
  // It defines the initial state of the notifier.
  @override
  SecretKey? build() {
    // Correctly setting up disposal logic
    ref.onDispose(() {
      state = null;
    });
    return null;
  }

  Future<bool> initialize(String passphrase) async {
    if (passphrase.trim().length < 12) {
      return false;
    }

    final isAvailable = await _localAuth.canCheckBiometrics;
    final isDeviceSupported = await _localAuth.isDeviceSupported();

    if (!isAvailable || !isDeviceSupported) {
      return false;
    }

    final didAuthenticate = await _localAuth.authenticate(
      localizedReason: 'Authenticate to unlock your encrypted vault',
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
      ),
    );

    if (!didAuthenticate) {
      return false;
    }

    final salt = await SecurityRepository().getOrCreateSalt();
    final derivedKey = await _keyDerivationService.deriveKey(passphrase, salt);
    
    // Now that we extend Notifier and imported riverpod, 'state' is available
    state = derivedKey;
    return true;
  }

  void lock() {
    LocalVault().close();
    state = null;
  }
}