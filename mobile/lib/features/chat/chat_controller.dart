import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

final chatDataProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, chatId) async {
  final res = await ref.read(apiClientProvider).get(Endpoints.getChat(chatId));
  return (res.data as Map).cast<String, dynamic>();
});

class ChatSocketService {
  ChatSocketService(this.ref);

  final Ref ref;
  WebSocketChannel? _channel;

  Future<WebSocketChannel> connect(int chatId) async {
    final token = await ref.read(secureStoreProvider).readToken();
    final url = Endpoints.wsChat(chatId, token ?? '');
    _channel = WebSocketChannel.connect(Uri.parse(url));
    return _channel!;
  }

  void send(String body) {
    _channel?.sink.add(jsonEncode({'body': body}));
  }

  void dispose() {
    _channel?.sink.close();
  }
}

final chatSocketProvider = Provider<ChatSocketService>((ref) {
  final service = ChatSocketService(ref);
  ref.onDispose(service.dispose);
  return service;
});

class ChatActions {
  ChatActions(this.ref);

  final Ref ref;

  Future<void> sendMessage(int chatId, String body) async {
    await ref.read(apiClientProvider).post(Endpoints.sendMessage(chatId), data: {'body': body});
    ref.invalidate(chatDataProvider(chatId));
  }
}

final chatActionsProvider = Provider<ChatActions>((ref) => ChatActions(ref));
