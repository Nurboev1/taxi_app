import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taxi_mobile/core/api/api_error.dart';
import 'package:taxi_mobile/core/i18n/strings.dart';
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
        title: const Text("Chatni o'chirish"),
        content: const Text(
            "Ushbu chat ikkala tomon uchun ham butunlay o'chiriladi. Davom etasizmi?"),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Yo'q")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Ha, o'chir")),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(chatActionsProvider).deleteChat(chatId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Chat o'chirildi")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(apiErrorMessage(e, fallback: s.t('generic_error')))),
      );
    }
  }

  Future<void> _openChatMenu(Map<String, dynamic> c, AppStrings s) async {
    final chatId = c['chat_id'] as int;
    final title = '${c['passenger_name']} - ${c['driver_name']}';
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(title),
                subtitle: Text(
                    (c['last_message'] ?? s.t('no_message')).toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('Suhbatni ochish'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/chat/$chatId');
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Ismni nusxalash'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await Clipboard.setData(ClipboardData(text: title));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nusxalandi')));
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text("Chatni o'chirish",
                    style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _deleteChat(chatId, s);
                },
              ),
            ],
          ),
        ),
      ),
    );
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
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                      height: 320, child: Center(child: Text(s.t('no_chats'))))
                ],
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final c = items[i];
                return Card(
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    leading: CircleAvatar(
                      child: Text(
                        (c['driver_name']?.toString().isNotEmpty ?? false)
                            ? c['driver_name'].toString()[0].toUpperCase()
                            : '?',
                      ),
                    ),
                    title: Text('${c['passenger_name']} - ${c['driver_name']}'),
                    subtitle: Text(
                        (c['last_message'] ?? s.t('no_message')).toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    onTap: () => context.push('/chat/${c['chat_id']}'),
                    onLongPress: () => _openChatMenu(c, s),
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
