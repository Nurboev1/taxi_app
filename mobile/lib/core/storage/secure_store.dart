import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStore {
  static const _tokenKey = 'access_token';
  static const _roleKey = 'role';
  static const _userIdKey = 'user_id';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);
  Future<String?> readToken() => _storage.read(key: _tokenKey);
  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  Future<void> saveRole(String role) => _storage.write(key: _roleKey, value: role);
  Future<String?> readRole() => _storage.read(key: _roleKey);

  Future<void> saveUserId(int id) => _storage.write(key: _userIdKey, value: id.toString());
  Future<int?> readUserId() async {
    final value = await _storage.read(key: _userIdKey);
    if (value == null) return null;
    return int.tryParse(value);
  }

  Future<void> clearAll() => _storage.deleteAll();
}
