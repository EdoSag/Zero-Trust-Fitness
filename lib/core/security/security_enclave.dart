import 'package:local_auth/local_auth.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zerotrust_fitness/core/security/key_derivation_service.dart';
import 'package:zerotrust_fitness/core/security/security_repository.dart';
import 'package:zerotrust_fitness/core/storage/local_vault.dart';

@NowaGenerated()
class SecurityEnclave extends Notifier<SecretKey?> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final KeyDerivationService _keyDerivationService = KeyDerivationService();

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
    state = derivedKey;
    return true;
  }

  void lock() {
    LocalVault().close();
    state = null;
  }

  @override
  SecretKey? build() {
    ref.onDispose(() => state = null);
    return null;
  }
}
