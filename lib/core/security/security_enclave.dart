import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

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
    // ... [existing validation and biometric code] ...

    try {
      final salt = await SecurityRepository().getOrCreateSalt();
      final derivedKey = await _keyDerivationService.deriveKey(passphrase, salt);
      
      // 1. Convert the key to the hex format SQLCipher expects
      final keyBytes = await derivedKey.extractBytes();
      final dbKeyHex = keyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

      // 2. CRITICAL: Tell the LocalVault to open using this key
      // This solves the "QueryExecutor.ensureOpen()" error
      await LocalVault().open(derivedKey);

      // 3. Update state to unblur the UI
      state = derivedKey;
      await _secureStorage.write(key: 'vault_locked', value: 'false');
      return true;
    } catch (e) {
      debugPrint('Unlock error: $e');
      return false;
    }
  }

  Future<void> lock() async {
    await LocalVault().close();
    await _secureStorage.write(key: 'vault_locked', value: 'true');
    state = null;
  }
}
