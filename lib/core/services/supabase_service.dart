import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zerotrust_fitness/core/security/private_key_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@NowaGenerated()
class SupabaseService {
  SupabaseService._();

  factory SupabaseService() => _instance;

  static final SupabaseService _instance = SupabaseService._();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _deviceIdKey = 'sync_device_id';


  Future<String> _getOrCreateDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final created = DateTime.now().microsecondsSinceEpoch.toString();
    await _storage.write(key: _deviceIdKey, value: created);
    return created;
  }

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

    final signedPayload = await PrivateKeyService().signBase64Payload(encryptedData);
    final publicKey = await PrivateKeyService().getPublicKeyBase64();
    final deviceId = await _getOrCreateDeviceId();

    await Supabase.instance.client.from('encrypted_vault').upsert({
      'user_id': user.id,
      'data_blob': encryptedData,
      'signature': signedPayload,
      'public_key': publicKey,
      'device_id': deviceId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<int>> fetchSaltForCurrentUser() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    final dynamic row = await Supabase.instance.client
        .from('profiles')
        .select('salt')
        .eq('id', user.id)
        .single();

    final saltValue = row['salt'];
    if (saltValue is! String || saltValue.isEmpty) {
      throw Exception('No valid salt found for this account.');
    }

    try {
      return base64Url.decode(saltValue);
    } catch (_) {
      throw Exception('Stored salt is not a valid base64url string.');
    }
  }

  Future<void> upsertSaltForCurrentUser(List<int> salt) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    await Supabase.instance.client.from('profiles').upsert({
      'id': user.id,
      'salt': base64Url.encode(salt),
    });
  }

  Future<String?> fetchEncryptedVaultBlobForCurrentUser() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    final rows = await Supabase.instance.client
        .from('encrypted_vault')
        .select('data_blob, updated_at')
        .eq('user_id', user.id)
        .order('updated_at', ascending: false)
        .limit(1);

    if (rows.isEmpty) {
      return null;
    }

    final latestRow = rows.first;
    final blob = latestRow['data_blob'];
    return blob is String ? blob : null;
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
