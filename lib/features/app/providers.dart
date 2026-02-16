import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zerotrust_fitness/core/security/security_enclave.dart';

@NowaGenerated()
final securityEnclaveProvider = NotifierProvider<SecurityEnclave, SecretKey?>(
  () => SecurityEnclave(),
);
