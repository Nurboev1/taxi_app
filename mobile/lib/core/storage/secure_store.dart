import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStore {
  static const _tokenKey = 'access_token';
  static const _roleKey = 'role';
  static const _userIdKey = 'user_id';
  static const _requestIdKey = 'current_request_id';
  static const _chatIdKey = 'current_chat_id';
  static const _darkModeKey = 'dark_mode';
  static const _shownNotificationIdsKey = 'shown_notification_ids';
  static const _pushNotificationsReadyKey = 'push_notifications_ready';
  static const _passengerTutorialSeenKey = 'tutorial_seen_passenger_home';
  static const _driverTutorialSeenKey = 'tutorial_seen_driver_home';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);
  Future<String?> readToken() => _storage.read(key: _tokenKey);
  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  Future<void> saveRole(String role) =>
      _storage.write(key: _roleKey, value: role);
  Future<String?> readRole() => _storage.read(key: _roleKey);

  Future<void> saveUserId(int id) =>
      _storage.write(key: _userIdKey, value: id.toString());
  Future<int?> readUserId() async {
    final value = await _storage.read(key: _userIdKey);
    if (value == null) return null;
    return int.tryParse(value);
  }

  Future<void> saveCurrentRequestId(int id) =>
      _storage.write(key: _requestIdKey, value: id.toString());
  Future<int?> readCurrentRequestId() async {
    final value = await _storage.read(key: _requestIdKey);
    if (value == null) return null;
    return int.tryParse(value);
  }

  Future<void> saveCurrentChatId(int id) =>
      _storage.write(key: _chatIdKey, value: id.toString());
  Future<int?> readCurrentChatId() async {
    final value = await _storage.read(key: _chatIdKey);
    if (value == null) return null;
    return int.tryParse(value);
  }

  Future<void> saveDarkMode(bool isDark) =>
      _storage.write(key: _darkModeKey, value: isDark ? '1' : '0');
  Future<bool> readDarkMode() async {
    final value = await _storage.read(key: _darkModeKey);
    return value == '1';
  }

  Future<Set<int>> readShownNotificationIds() async {
    final value = await _storage.read(key: _shownNotificationIdsKey);
    if (value == null || value.isEmpty) return <int>{};
    final ids = value
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toSet();
    return ids;
  }

  Future<void> saveShownNotificationIds(Set<int> ids) async {
    final sorted = ids.toList()..sort();
    final capped =
        sorted.length > 400 ? sorted.sublist(sorted.length - 400) : sorted;
    await _storage.write(
        key: _shownNotificationIdsKey, value: capped.join(','));
  }

  Future<void> savePushNotificationsReady(bool ready) => _storage.write(
        key: _pushNotificationsReadyKey,
        value: ready ? '1' : '0',
      );

  Future<bool> readPushNotificationsReady() async {
    final value = await _storage.read(key: _pushNotificationsReadyKey);
    return value == '1';
  }

  Future<bool> readPassengerTutorialSeen() async {
    final v = await _storage.read(key: _passengerTutorialSeenKey);
    return v == '1';
  }

  Future<void> savePassengerTutorialSeen(bool seen) =>
      _storage.write(key: _passengerTutorialSeenKey, value: seen ? '1' : '0');

  Future<bool> readDriverTutorialSeen() async {
    final v = await _storage.read(key: _driverTutorialSeenKey);
    return v == '1';
  }

  Future<void> saveDriverTutorialSeen(bool seen) =>
      _storage.write(key: _driverTutorialSeenKey, value: seen ? '1' : '0');

  Future<void> clearAll() => _storage.deleteAll();
}
