import 'package:cryptography/cryptography.dart';

class KeyDerivationService {
  Future<SecretKey> deriveKey(String passphrase, List<int> salt) async {
    final algorithm = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 600000,
      bits: 256,
    );

    final derivedKey = await algorithm.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );

    return derivedKey;
  }
}
