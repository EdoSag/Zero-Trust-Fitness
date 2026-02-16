import 'package:zerotrust_fitness/encryption_service.dart';
import 'package:zerotrust_fitness/local_vault.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zerotrust_fitness/security_repository.dart';
import 'dart:convert';

@NowaGenerated()
class WorkoutService {
  final EncryptionService _encryptionService = EncryptionService();

  final LocalVault _localVault = LocalVault();

  Future<void> runTestFlow() async {
    const dummyWorkout = 'Ran 5km';
    final masterKeyBase64 = await SecurityRepository().getOrCreateMasterKey();
    final secretKey = SecretKey(base64Url.decode(masterKeyBase64));
    final encrypted = await _encryptionService.encryptString(
      dummyWorkout,
      secretKey,
    );
    print('Scrambled Text: ${encrypted}');
    await _localVault.saveWorkout(encrypted);
    final decrypted = await _encryptionService.decryptString(
      encrypted,
      secretKey,
    );
    print('Decrypted Text: ${decrypted}');
    if (decrypted == dummyWorkout) {
      print('✅ Security Flow Verified: Zero-Trust Foundation Complete!');
    } else {
      print('❌ Security Flow Failed: Decrypted text does not match!');
    }
  }
}
