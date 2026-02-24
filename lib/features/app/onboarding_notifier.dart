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
      if (masterPassword.trim().length < 12) {
        throw Exception('Master password must be at least 12 characters long');
      }

      await _guardBiometricSetup(enableBiometrics);

      final authResponse = await _supabaseService.signUp(email, masterPassword);
      if (authResponse.session == null) {
        throw Exception('Signup successful! Check your email to verify your account.');
      }

      final salt = await _securityRepository.getOrCreateSalt();
      await _supabaseService.upsertSaltForCurrentUser(salt);

      final SecretKey derivedKey = await _keyDerivationService.deriveKey(
        masterPassword,
        salt,
      );

      await _initializeSQLCipherDatabase(derivedKey);
      await _persistLocalMetadata(derivedKey, enableBiometrics: enableBiometrics);
    });
  }

  Future<void> signIn({
    required String email,
    required String masterPassword,
    required bool enableBiometrics,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      if (masterPassword.trim().isEmpty) {
        throw Exception('Master password is required.');
      }

      await _guardBiometricSetup(enableBiometrics);

      final authResponse = await _supabaseService.signIn(email, masterPassword);
      if (authResponse.session == null) {
        throw Exception('Unable to establish an authenticated session.');
      }

      final salt = await _supabaseService.fetchSaltForCurrentUser();
      await _securityRepository.saveSalt(salt);

      final SecretKey derivedKey = await _keyDerivationService.deriveKey(
        masterPassword,
        salt,
      );

      await _initializeSQLCipherDatabase(derivedKey);
      await _persistLocalMetadata(derivedKey, enableBiometrics: enableBiometrics);

      final encryptedBlob = await _supabaseService.fetchEncryptedVaultBlobForCurrentUser();
      if (encryptedBlob != null) {
        await _secureStorage.write(key: 'vault_remote_blob', value: encryptedBlob);
      }
    });
  }

  Future<void> _guardBiometricSetup(bool enableBiometrics) async {
    if (!enableBiometrics) {
      return;
    }

    final bool canCheck =
        await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    if (!canCheck) {
      throw Exception('Biometrics not available on this device');
    }

    final authenticated = await _localAuth.authenticate(
      localizedReason: 'Secure your Zero-Trust Vault',
      options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
    );
    if (!authenticated) {
      throw Exception('Biometric setup cancelled.');
    }
  }

  Future<void> _persistLocalMetadata(
    SecretKey derivedKey, {
    required bool enableBiometrics,
  }) async {
    final keyBytes = await derivedKey.extractBytes();
    final dbKeyHex = keyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    await _secureStorage.write(key: 'encrypted_db_key', value: dbKeyHex);
    await _secureStorage.write(key: 'vault_passphrase', value: null);

    if (enableBiometrics) {
      await _secureStorage.write(key: 'biometric_enabled', value: 'true');
    } else {
      await _secureStorage.write(key: 'biometric_enabled', value: 'false');
    }
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
      db.execute('PRAGMA cipher_memory_security = ON;');

      // Verify encryption is active
      final result = db.select('PRAGMA cipher_version;');
      if (result.isEmpty) {
        throw Exception('Zero-Trust Error: SQLCipher encryption failed to initialize.');
      }

      db.execute('''
        CREATE TABLE IF NOT EXISTS workouts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          encrypted_data TEXT NOT NULL,
          created_at TEXT NOT NULL
        );
      ''');
      db.execute('''
        CREATE TABLE IF NOT EXISTS daily_metrics (
          date_key TEXT PRIMARY KEY,
          steps INTEGER NOT NULL,
          heart_points INTEGER NOT NULL,
          updated_at TEXT NOT NULL
        );
      ''');
    } finally {
      db.dispose();
    }
  }
}
