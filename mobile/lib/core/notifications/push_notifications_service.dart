import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/endpoints.dart';
import 'local_notifications_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background/terminated push handling entry point.
}

class PushNotificationsService {
  PushNotificationsService(this.ref);

  final Ref ref;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<String>? _onTokenRefreshSub;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerToken(token);
      }

      _onTokenRefreshSub = messaging.onTokenRefresh.listen((token) {
        unawaited(_registerToken(token));
      });

      _onMessageSub = FirebaseMessaging.onMessage.listen((message) async {
        final title = message.notification?.title ??
            message.data['title']?.toString() ??
            'SafarUz';
        final body =
            message.notification?.body ?? message.data['body']?.toString() ?? '';
        await ref
            .read(localNotificationsServiceProvider)
            .showNotification(id: message.hashCode, title: title, body: body);
      });
    } catch (_) {
      // Firebase might be unavailable if google-services config is missing.
      // Polling notifications still works as fallback.
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      await ref.read(apiClientProvider).post(
            Endpoints.pushToken,
            data: {'token': token},
          );
    } catch (_) {
      // Keep silent; token refresh will retry later.
    }
  }

  void dispose() {
    _onMessageSub?.cancel();
    _onTokenRefreshSub?.cancel();
  }
}

final pushNotificationsServiceProvider =
    Provider<PushNotificationsService>((ref) {
  final service = PushNotificationsService(ref);
  ref.onDispose(service.dispose);
  return service;
});
