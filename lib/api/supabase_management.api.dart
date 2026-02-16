import 'package:dio/dio.dart';
import 'package:nowa_runtime/nowa_runtime.dart';

@NowaGenerated({'editor': 'api'})
class SupabaseManagement {
  factory SupabaseManagement() {
    return _instance;
  }

  SupabaseManagement._();

  final Dio _dioClient = Dio();

  @NowaGenerated({'loader': 'api_client_getter'})
  Dio get dioClient {
    return _dioClient;
  }

  static final SupabaseManagement _instance = SupabaseManagement._();

  Future<Response<dynamic>> setupEncryptedVault() async {
    final Response res = await dioClient.post(
      'https://ohgxpnchqmisvktqjmcx.supabase.co/rest/v1/rpc/exec',
      options: Options(
        headers: {
          'apikey':
              'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9oZ3hwbmNocW1pc3ZrdHFqbWN4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzExNDUxNTYsImV4cCI6MjA4NjcyMTE1Nn0.5vDw0yzpqrLnR49VEsdUoj6Z7h9BqmpJBD14A-jrj8w',
          'Authorization':
              'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9oZ3hwbmNocW1pc3ZrdHFqbWN4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzExNDUxNTYsImV4cCI6MjA4NjcyMTE1Nn0.5vDw0yzpqrLnR49VEsdUoj6Z7h9BqmpJBD14A-jrj8w',
          'Content-Type': 'application/json',
        },
      ),
      data:
          '{"sql": "CREATE TABLE IF NOT EXISTS public.encrypted_vault (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), user_id UUID NOT NULL DEFAULT auth.uid(), data_blob TEXT NOT NULL, updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone(\'\\\'\'utc\'\\\'\'::text, now()) NOT NULL); ALTER TABLE public.encrypted_vault ENABLE ROW LEVEL SECURITY; CREATE POLICY \\"Users can only access their own data\\" ON public.encrypted_vault FOR ALL USING (auth.uid() = user_id);"}',
    );
    return res;
  }
}
