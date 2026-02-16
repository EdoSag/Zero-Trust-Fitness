import 'package:nowa_runtime/nowa_runtime.dart';
import 'dart:math';
import 'dart:convert';

@NowaGenerated()
class SecurityRepository {
  SecurityRepository._();

  factory SecurityRepository() {
    return _instance;
  }

  final FlutterSecureStorage _storage = FlutterSecureStorage();

  static final SecurityRepository _instance = SecurityRepository._();

  static const String _masterKeyName = 'master_key_256';

  Future<String> getOrCreateMasterKey() async {
    String? masterKey = await _storage.read(key: _masterKeyName);
    if (masterKey == null) {
      final Random random = Random.secure();
      final List<int> values = List<int>.generate(
        32,
        (i) => random.nextInt(256),
      );
      masterKey = base64Url.encode(values);
      await _storage.write(key: _masterKeyName, value: masterKey);
    }
    return masterKey!;
  }
}
