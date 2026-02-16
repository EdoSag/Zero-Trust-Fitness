import 'package:dio/dio.dart';
import 'package:nowa_runtime/nowa_runtime.dart';

@NowaGenerated({'editor': 'api'})
class SupabaseManagement {
  factory SupabaseManagement() => _instance;

  SupabaseManagement._();

  final Dio _dioClient = Dio();

  @NowaGenerated({'loader': 'api_client_getter'})
  Dio get dioClient => _dioClient;

  static final SupabaseManagement _instance = SupabaseManagement._();

  Future<Response<dynamic>> setupEncryptedVault() {
    throw UnsupportedError(
      'Security hardening: schema/RPC execution from client is disabled. Use server-side migrations only.',
    );
  }
}
