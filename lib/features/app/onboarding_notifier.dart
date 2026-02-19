import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3/open.dart'; 
// Use ONLY sqlcipher_flutter_libs for encrypted sqlite on Android
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart'; 
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cryptography/cryptography.dart';

import 'package:zerotrust_fitness/core/services/supabase_service.dart';
import 'package:zerotrust_fitness/core/security/security_repository.dart';
import 'package:zerotrust_fitness/core/security/key_derivation_service.dart';

part 'onboarding_notifier.g.dart';

@riverpod
class OnboardingNotifier extends _$OnboardingNotifier {
  final _supabaseService = SupabaseService();
  final _securityRepository = SecurityRepository();
  final _keyDerivationService = KeyDerivationService();
  final _secureStorage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();

  @override
  FutureOr<void> build() {
    return null;
  }

  Future<void> createAccount({
    required String email,
    required String masterPassword,
    required bool enableBiometrics,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      // 1. Validation
      if (masterPassword.trim().length < 12) {
        throw Exception('Master password must be at least 12 characters long');
      }

      // 2. Biometrics check
      if (enableBiometrics) {
        final bool canCheck = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
        if (!canCheck) {
          throw Exception('Biometrics not available on this device');
        }

        final authenticated = await _localAuth.authenticate(
          localizedReason: 'Secure your Zero-Trust Vault',
          options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
        );
        if (!authenticated) throw Exception('Biometric setup cancelled.');
      }

      // 3. Supabase Auth
      final authResponse = await _supabaseService.signUp(email, masterPassword);
      if (authResponse.session == null) {
        throw Exception('Signup successful! Check your email to verify your account.');
      }

      // 4. Key Derivation (PBKDF2)
      final salt = await _securityRepository.getOrCreateSalt();
      final SecretKey derivedKey = await _keyDerivationService.deriveKey(
        masterPassword,
        salt,
      );

      // 5. Initialize SQLCipher with derived key
      await _initializeSQLCipherDatabase(derivedKey);

      // 6. Persist metadata
      final keyBytes = await derivedKey.extractBytes();
      final dbKeyHex = keyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      
      await _secureStorage.write(key: 'encrypted_db_key', value: dbKeyHex);
      if (enableBiometrics) {
        await _secureStorage.write(key: 'biometric_enabled', value: 'true');
      }
    });
  }

Future<void> _initializeSQLCipherDatabase(SecretKey secretKey) async {
    if (Platform.isAndroid) {
      // This is the correct way to initialize SQLCipher binaries on Android
      open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
    }

    final keyBytes = await secretKey.extractBytes();
    final dbKeyHex = keyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    final appDir = await getApplicationDocumentsDirectory();
    final dbPath = '${appDir.path}/vault.sqlite';

    final db = sqlite3.open(dbPath);
    try {
      // Essential: Apply the key immediately after opening
      db.execute("PRAGMA key = \"x'$dbKeyHex'\";");
      db.execute("PRAGMA cipher_memory_security = ON;");
      
      // Verify encryption is active
      final result = db.select("PRAGMA cipher_version;");
      if (result.isEmpty) {
        throw Exception("Zero-Trust Error: SQLCipher encryption failed to initialize.");
      }

      db.execute('''
        CREATE TABLE IF NOT EXISTS workouts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          encrypted_data TEXT NOT NULL,
          created_at TEXT NOT NULL
        );
      ''');
    } finally {
      db.dispose();
    }
  }
}