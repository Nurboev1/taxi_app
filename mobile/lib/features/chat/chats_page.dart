import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taxi_mobile/core/api/api_error.dart';
import 'package:taxi_mobile/core/i18n/strings.dart';
import 'package:taxi_mobile/core/widgets/neo_sections.dart';
import 'package:taxi_mobile/core/widgets/neo_shell.dart';

import '../auth/auth_controller.dart';
import 'chat_controller.dart';

class ChatsPage extends ConsumerStatefulWidget {
  const ChatsPage({super.key});

  @override
  ConsumerState<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends ConsumerState<ChatsPage> {
  Future<void> _deleteChat(int chatId, AppStrings s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('chat_delete_title')),
        content: Text(s.t('chat_delete_body')),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Yo'q")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.t('chat_delete_confirm'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(chatActionsProvider).deleteChat(chatId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.t('chat_deleted'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(apiErrorMessage(e, fallback: s.t('generic_error')))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(
        ref.watch(authControllerProvider).profile?['language']?.toString());
    final chatsAsync = ref.watch(myChatsProvider);
    return NeoScaffold(
      title: s.t('chats'),
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myChatsProvider);
        },
        child: chatsAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  NeoHeroCard(
                    title: s.t('chats'),
                    subtitle: s.t('tutorial_passenger_chat_desc'),
                    icon: Icons.forum_outlined,
                  ),
                  const SizedBox(height: 24),
                  NeoEmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: s.t('no_chats'),
                    subtitle: s.t('tutorial_passenger_chat_desc'),
                  ),
                ],
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: items.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: NeoHeroCard(
                      title: s.t('chats'),
                      subtitle: s.t('tutorial_passenger_chat_desc'),
                      icon: Icons.forum_outlined,
                      badges: [
                        NeoBadge(
                          icon: Icons.mark_chat_unread_outlined,
                          label: '${items.length}',
                        ),
                      ],
                    ),
                  );
                }
                final c = items[i - 1];
                final title = '${c['passenger_name']} - ${c['driver_name']}';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: NeoActionCard(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: title,
                    subtitle:
                        (c['last_message'] ?? s.t('no_message')).toString(),
                    onTap: () => context.push('/chat/${c['chat_id']}'),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz_rounded),
                      onSelected: (value) async {
                        if (value == 'copy') {
                          await Clipboard.setData(ClipboardData(text: title));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(s.t('copied'))),
                          );
                          return;
                        }
                        if (value == 'delete') {
                          await _deleteChat(c['chat_id'] as int, s);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                            value: 'copy', child: Text(s.t('copy_name'))),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(s.t('chat_delete_title')),
                        ),
                      ],
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
                  child: Center(child: Text(s.t('chats_load_error'))))
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
