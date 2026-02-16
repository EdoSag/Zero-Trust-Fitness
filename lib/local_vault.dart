import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zerotrust_fitness/security_repository.dart';
import 'dart:convert';
import 'package:zerotrust_fitness/encryption_service.dart';

@NowaGenerated()
class LocalVault {
  factory LocalVault() {
    return _instance;
  }

  LocalVault._();

  static final LocalVault _instance = LocalVault._();

  Future<void> saveWorkout(String encryptedData) async {}

  Future<void> runTestFlow() async {
    const dummyWorkout = 'Ran 5km';
    final masterKeyBase64 = await SecurityRepository().getOrCreateMasterKey();
    final secretKey = SecretKey(base64Url.decode(masterKeyBase64));
    final encrypted = await EncryptionService().encryptString(
      dummyWorkout,
      secretKey,
    );
    print('Scrambled Text: ${encrypted}');
    await saveWorkout(encrypted);
    final decrypted = await EncryptionService().decryptString(
      encrypted,
      secretKey,
    );
    print('Decrypted Text: ${decrypted}');
    if (decrypted == dummyWorkout) {
      print('✅ Security Flow Verified!');
    }
  }
}
