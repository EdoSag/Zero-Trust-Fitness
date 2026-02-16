import 'package:zerotrust_fitness/security_enclave.dart';
import 'package:nowa_runtime/nowa_runtime.dart';

@NowaGenerated()
final securityEnclaveProvider = NotifierProvider<SecurityEnclave, SecretKey?>(
  () => SecurityEnclave(),
);
