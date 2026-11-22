import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure key-value storage service backed by Android Keystore.
/// Used to securely store optional API keys (such as The Guardian developer key)
/// rather than keeping them in plain text or hardcoding them in the codebase.
class SecureStorageService {
  static const String _guardianApiKey = 'guardian_api_key';

  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
            );

  Future<void> saveGuardianApiKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await _storage.delete(key: _guardianApiKey);
    } else {
      await _storage.write(key: _guardianApiKey, value: trimmed);
    }
  }

  Future<String?> getGuardianApiKey() async {
    return await _storage.read(key: _guardianApiKey);
  }

  Future<void> clearGuardianApiKey() async {
    await _storage.delete(key: _guardianApiKey);
  }

  Future<bool> hasGuardianApiKey() async {
    final key = await getGuardianApiKey();
    return key != null && key.isNotEmpty;
  }
}
