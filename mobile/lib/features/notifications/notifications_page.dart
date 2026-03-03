import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../auth/auth_controller.dart';
import 'notifications_controller.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final s = AppStrings.of(
        ref.watch(authControllerProvider).profile?['language']?.toString());

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('notifications')),
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(notificationActionsProvider).markReadAll(),
            child: Text(s.t('notifications_mark_all_read')),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(notificationsProvider),
        child: notifications.when(
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                      height: 320,
                      child: Center(child: Text(s.t('notifications_none'))))
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final n = items[i];
                final isRead = n['is_read'] == true;
                return ListTile(
                  leading: Icon(
                    isRead
                        ? Icons.notifications_none
                        : Icons.notifications_active,
                  ),
                  title: Text(n['title']?.toString() ?? ''),
                  subtitle: Text(n['body']?.toString() ?? ''),
                  trailing: isRead
                      ? null
                      : const Icon(Icons.circle,
                          size: 10, color: Colors.redAccent),
                  onTap: () async {
                    await ref
                        .read(notificationActionsProvider)
                        .markRead(n['id'] as int);
                    if (!context.mounted) return;
                    final kind = n['kind']?.toString() ?? '';
                    if (kind == 'chat_message') {
                      context.push('/chats');
                    } else if (kind == 'trip_finished_rate') {
                      context.push('/passenger/rate-trip');
                    } else if (kind == 'rating_received') {
                      context.push('/driver/my-ratings');
                    }
                  },
                );
              },
            );
          },
          error: (_, __) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                  height: 320,
                  child: Center(child: Text(s.t('notifications_load_error'))))
            ],
          ),
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(
                  height: 320,
                  child: Center(child: CircularProgressIndicator()))
            ],
          ),
        ),
      ),
    );
  }
}
