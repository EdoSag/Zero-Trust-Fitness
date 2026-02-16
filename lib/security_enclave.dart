import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zerotrust_fitness/security_repository.dart';
import 'dart:convert';

@NowaGenerated()
class SecurityEnclave extends Notifier<SecretKey?> {
  Future<void> initialize() async {
    final masterKeyBase64 = await SecurityRepository().getOrCreateMasterKey();
    final masterKeyBytes = base64Url.decode(masterKeyBase64);
    state = SecretKey(masterKeyBytes);
  }

  @override
  SecretKey? build() {
    ref.onDispose(() {
      state = null;
    });
    return null;
  }
}
