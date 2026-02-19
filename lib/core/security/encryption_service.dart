import 'package:cryptography/cryptography.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'dart:convert';

@NowaGenerated()
class EncryptionService {
  EncryptionService._();

  factory EncryptionService() {
    return _instance;
  }

  final _algorithm = AesGcm.with256bits();

  static final EncryptionService _instance = EncryptionService._();

  Future<String> encryptString(String data, SecretKey secretKey) async {
    final nonce = _algorithm.newNonce();
    final secretBox = await _algorithm.encrypt(
      utf8.encode(data),
      secretKey: secretKey,
      nonce: nonce,
    );
    return base64Url.encode(secretBox.concatenation());
  }

  Future<String> decryptString(String encrypted, SecretKey secretKey) async {
    final concatenation = base64Url.decode(encrypted);
    final secretBox = SecretBox.fromConcatenation(
      concatenation,
      nonceLength: _algorithm.nonceLength,
      macLength: _algorithm.macAlgorithm.macLength,
    );
    final clearText = await _algorithm.decrypt(secretBox, secretKey: secretKey);
    return utf8.decode(clearText);
  }
}
