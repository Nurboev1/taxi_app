import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

final notificationsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) async* {
  while (true) {
    final res =
        await ref.read(apiClientProvider).get(Endpoints.myNotifications);
    yield (res.data as List).cast<Map<String, dynamic>>();
    await Future<void>.delayed(const Duration(seconds: 4));
  }
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final asyncValue = ref.watch(notificationsProvider);
  return asyncValue.maybeWhen(
    data: (items) => items.where((e) => e['is_read'] == false).length,
    orElse: () => 0,
  );
});

class NotificationActions {
  NotificationActions(this.ref);

  final Ref ref;

  Future<void> markRead(int id) async {
    await ref.read(apiClientProvider).post(Endpoints.markNotificationRead(id));
    ref.invalidate(notificationsProvider);
  }

  Future<void> markReadAll() async {
    await ref.read(apiClientProvider).post(Endpoints.readAllNotifications);
    ref.invalidate(notificationsProvider);
  }
}

final notificationActionsProvider =
    Provider<NotificationActions>((ref) => NotificationActions(ref));
