import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@NowaGenerated()
class SupabaseService {
  SupabaseService._();

  factory SupabaseService() => _instance;

  static final SupabaseService _instance = SupabaseService._();

  Future<AuthResponse> signIn(String email, String password) {
    return Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp(String email, String password) {
    return Supabase.instance.client.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() {
    return Supabase.instance.client.auth.signOut();
  }

  Future<void> syncLocalToSupabase(String encryptedData) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    await Supabase.instance.client.from('encrypted_vault').upsert({
      'user_id': user.id,
      'data_blob': encryptedData,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> initialize() async {
    await dotenv.load(fileName: '.env');
    final url = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (url == null || url.isEmpty || anonKey == null || anonKey.isEmpty) {
      throw StateError('Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env');
    }

    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme.toLowerCase() != 'https') {
      throw StateError('SUPABASE_URL must be a valid HTTPS URL.');
    }

    await Supabase.initialize(url: url, anonKey: anonKey);
  }
}
