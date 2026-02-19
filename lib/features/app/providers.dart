import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zerotrust_fitness/core/security/security_enclave.dart';

@NowaGenerated()
final securityEnclaveProvider = NotifierProvider<SecurityEnclave, SecretKey?>(
  SecurityEnclave.new, // Use .new instead of a full arrow function
);
