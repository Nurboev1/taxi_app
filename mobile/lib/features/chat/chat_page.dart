import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'chat_controller.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, required this.chatId});

  final int chatId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _ctrl = TextEditingController();
  WebSocketChannel? _ws;
  List<Map<String, dynamic>> _liveMessages = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final ws = await ref.read(chatSocketProvider).connect(widget.chatId);
      setState(() => _ws = ws);
      ws.stream.listen((event) {
        final data = jsonDecode(event.toString()) as Map<String, dynamic>;
        setState(() => _liveMessages = [..._liveMessages, data]);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatAsync = ref.watch(chatDataProvider(widget.chatId));

    return Scaffold(
      appBar: AppBar(title: Text('Chat #${widget.chatId}')),
      body: Column(
        children: [
          Expanded(
            child: chatAsync.when(
              data: (chat) {
                final history = (chat['messages'] as List).cast<Map<String, dynamic>>();
                final all = [...history, ..._liveMessages];
                if (all.isEmpty) return const Center(child: Text('Xabarlar yo‘q'));
                return ListView.builder(
                  itemCount: all.length,
                  itemBuilder: (context, i) {
                    final m = all[i];
                    return ListTile(
                      title: Text(m['body']?.toString() ?? ''),
                      subtitle: Text('Yuboruvchi ID: ${m['sender_id']}'),
                    );
                  },
                );
              },
              error: (_, __) => const Center(child: Text('Chatni yuklashda xatolik')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(hintText: 'Xabar yozing'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final text = _ctrl.text.trim();
                    if (text.isEmpty) return;
                    if (_ws != null) {
                      ref.read(chatSocketProvider).send(text);
                    } else {
                      await ref.read(chatActionsProvider).sendMessage(widget.chatId, text);
                    }
                    _ctrl.clear();
                  },
                  child: const Text('Yuborish'),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
