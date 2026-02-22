import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PrivateKeyService {
  factory PrivateKeyService() => _instance;

  PrivateKeyService._();

  static final PrivateKeyService _instance = PrivateKeyService._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Ed25519 _algorithm = Ed25519();

  static const String _privateKeyStorageKey = 'user_sync_private_key';

  Future<SimpleKeyPair> getOrCreateUserPrivateKey() async {
    final encoded = await _storage.read(key: _privateKeyStorageKey);
    if (encoded != null && encoded.isNotEmpty) {
      final keyBytes = base64Url.decode(encoded);
      return SimpleKeyPairData(
        keyBytes,
        type: KeyPairType.ed25519,
      );
    }

    final keyPair = await _algorithm.newKeyPair();
    final privateKey = await keyPair.extractPrivateKeyBytes();
    await _storage.write(
      key: _privateKeyStorageKey,
      value: base64Url.encode(privateKey),
    );

    return SimpleKeyPairData(privateKey, type: KeyPairType.ed25519);
  }

  Future<String> getPublicKeyBase64() async {
    final privateKey = await getOrCreateUserPrivateKey();
    final publicKey = await privateKey.extractPublicKey();
    return base64Url.encode(publicKey.bytes);
  }

  Future<String> signBase64Payload(String payload) async {
    final privateKey = await getOrCreateUserPrivateKey();
    final signature = await _algorithm.sign(
      utf8.encode(payload),
      keyPair: privateKey,
    );
    return base64Url.encode(signature.bytes);
  }
}
