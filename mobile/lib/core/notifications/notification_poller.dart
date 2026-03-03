import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/endpoints.dart';
import 'local_notifications_service.dart';

final localNotificationsServiceProvider =
    Provider<LocalNotificationsService>((ref) {
  return LocalNotificationsService();
});

class NotificationPoller {
  NotificationPoller(this.ref);

  final Ref ref;
  Timer? _timer;
  bool _running = false;

  Future<void> start() async {
    if (_timer != null) return;
    await ref.read(localNotificationsServiceProvider).init();
    await _tick();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  Future<void> _tick() async {
    if (_running) return;
    _running = true;
    try {
      final token = await ref.read(secureStoreProvider).readToken();
      if (token == null || token.isEmpty) return;

      final api = ref.read(apiClientProvider);
      final res = await api.get(Endpoints.myNotifications);
      final items = (res.data as List).cast<Map<String, dynamic>>();
      final shownIds =
          await ref.read(secureStoreProvider).readShownNotificationIds();
      final service = ref.read(localNotificationsServiceProvider);

      for (final item in items) {
        final id = item['id'] as int?;
        final isRead = item['is_read'] == true;
        if (id == null || isRead || shownIds.contains(id)) continue;

        final title = item['title']?.toString() ?? 'SafarUz';
        final body = item['body']?.toString() ?? '';
        await service.showNotification(id: id, title: title, body: body);
        shownIds.add(id);
      }

      await ref.read(secureStoreProvider).saveShownNotificationIds(shownIds);
    } catch (_) {
      // Silent polling errors for background stability.
    } finally {
      _running = false;
    }
  }
}

final notificationPollerProvider = Provider<NotificationPoller>((ref) {
  final poller = NotificationPoller(ref);
  ref.onDispose(poller.stop);
  return poller;
});
