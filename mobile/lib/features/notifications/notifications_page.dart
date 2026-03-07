import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/widgets/neo_sections.dart';
import '../../core/widgets/neo_shell.dart';
import '../auth/auth_controller.dart';
import 'notifications_controller.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final s = AppStrings.of(
      ref.watch(authControllerProvider).profile?['language']?.toString(),
    );

    return NeoScaffold(
      title: s.t('notifications'),
      actions: [
        TextButton(
          onPressed: () => ref.read(notificationActionsProvider).markReadAll(),
          child: Text(s.t('notifications_mark_all_read')),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(notificationsProvider),
        child: notifications.when(
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  NeoHeroCard(
                    title: s.t('notifications'),
                    subtitle: s.t('notifications_new_none'),
                    icon: Icons.notifications_active_outlined,
                  ),
                  const SizedBox(height: 24),
                  NeoEmptyState(
                    icon: Icons.notifications_off_outlined,
                    title: s.t('notifications_none'),
                    subtitle: s.t('notifications_new_none'),
                  ),
                ],
              );
            }

            final unreadCount =
                items.where((item) => item['is_read'] != true).length;

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: NeoHeroCard(
                      title: s.t('notifications'),
                      subtitle: unreadCount > 0
                          ? s
                              .t('notifications_new_count')
                              .replaceFirst('{count}', '$unreadCount')
                          : s.t('notifications_new_none'),
                      icon: Icons.notifications_active_outlined,
                      badges: [
                        NeoBadge(
                          icon: Icons.mark_email_unread_outlined,
                          label: '$unreadCount',
                        ),
                        NeoBadge(
                          icon: Icons.history_rounded,
                          label: '${items.length}',
                        ),
                      ],
                    ),
                  );
                }

                final n = items[index - 1];
                final isRead = n['is_read'] == true;
                final kind = n['kind']?.toString() ?? '';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () async {
                        await ref
                            .read(notificationActionsProvider)
                            .markRead(n['id'] as int);
                        if (!context.mounted) return;
                        if (kind == 'chat_message') {
                          context.push('/chats');
                        } else if (kind == 'trip_finished_rate') {
                          context.push('/passenger/rate-trip');
                        } else if (kind == 'rating_received') {
                          context.push('/driver/my-ratings');
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: (isRead
                                        ? Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest
                                        : Theme.of(context).colorScheme.primary)
                                    .withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                isRead
                                    ? Icons.notifications_none_rounded
                                    : Icons.notifications_active_rounded,
                                color: isRead
                                    ? Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                    : Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          n['title']?.toString() ?? '',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      if (!isRead)
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: const BoxDecoration(
                                            color: Colors.redAccent,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    n['body']?.toString() ?? '',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                          height: 1.4,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
          error: (_, __) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: 320,
                child: Center(child: Text(s.t('notifications_load_error'))),
              ),
            ],
          ),
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(
                height: 320,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
