import 'package:cryptography/cryptography.dart';
import 'dart:convert';

import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zerotrust_fitness/core/security/encryption_service.dart';
import 'package:zerotrust_fitness/core/storage/local_vault.dart';

@NowaGenerated()
class WorkoutService {
  final EncryptionService _encryptionService = EncryptionService();
  final LocalVault _localVault = LocalVault();

  Future<void> runTestFlow(SecretKey secretKey) async {
    const dummyWorkout = 'Ran 5km';
    final encrypted = await _encryptionService.encryptString(dummyWorkout, secretKey);
    await _localVault.saveWorkout(encrypted, secretKey);
    final decrypted = await _encryptionService.decryptString(encrypted, secretKey);
    if (decrypted != dummyWorkout) {
      throw StateError('Security flow failed: decrypted text mismatch');
    }
  }
}
