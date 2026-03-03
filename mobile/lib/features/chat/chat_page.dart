import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/strings.dart';
import '../auth/auth_controller.dart';
import 'chat_controller.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, required this.chatId});

  final int chatId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _pollTimer;
  bool _isNearBottom = true;
  int? _lastMessageId;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      ref.invalidate(chatDataProvider(widget.chatId));
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scrollCtrl.removeListener(_onScroll);
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final gap = _scrollCtrl.position.maxScrollExtent - _scrollCtrl.offset;
    _isNearBottom = gap <= 96;
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollCtrl.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      final target = _scrollCtrl.position.maxScrollExtent;
      if (animate) {
        _scrollCtrl.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      } else {
        _scrollCtrl.jumpTo(target);
      }
    });
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final s = AppStrings.of(auth.profile?['language']?.toString());
    final myId = auth.userId;
    final chatAsync = ref.watch(chatDataProvider(widget.chatId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: chatAsync.maybeWhen(
          data: (c) => Text(
              c['peer_name']?.toString() ?? '${s.t('chat')} #${widget.chatId}'),
          orElse: () => Text('${s.t('chat')} #${widget.chatId}'),
        ),
        actions: [
          chatAsync.maybeWhen(
            data: (c) {
              final phone = c['peer_phone']?.toString();
              if (phone == null || phone.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                onPressed: () => _call(phone),
                icon: const Icon(Icons.call_outlined),
              );
            },
            orElse: () => const SizedBox.shrink(),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(chatDataProvider(widget.chatId));
              },
              child: chatAsync.when(
                data: (chat) {
                  final all =
                      (chat['messages'] as List).cast<Map<String, dynamic>>();
                  if (all.isEmpty) {
                    _lastMessageId = null;
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                            height: 320,
                            child: Center(child: Text(s.t('messages_empty'))))
                      ],
                    );
                  }
                  final latestId = all.last['id'] as int?;
                  final hadMessagesBefore = _lastMessageId != null;
                  final shouldStick = !hadMessagesBefore ||
                      (_isNearBottom && latestId != _lastMessageId);
                  _lastMessageId = latestId;
                  if (shouldStick) {
                    _scrollToBottom(animate: hadMessagesBefore);
                  }
                  return ListView.builder(
                    controller: _scrollCtrl,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    itemCount: all.length,
                    itemBuilder: (context, i) {
                      final m = all[i];
                      final isMine = myId != null && m['sender_id'] == myId;
                      final body = m['body']?.toString() ?? '';
                      final created =
                          DateTime.tryParse(m['created_at']?.toString() ?? '');
                      final hhmm = created == null
                          ? ''
                          : DateFormat('HH:mm').format(created.toLocal());

                      return Align(
                        alignment: isMine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 280),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isMine
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(14),
                              topRight: const Radius.circular(14),
                              bottomLeft: Radius.circular(isMine ? 14 : 4),
                              bottomRight: Radius.circular(isMine ? 4 : 14),
                            ),
                            border: Border.all(
                                color:
                                    theme.dividerColor.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(body,
                                    style: const TextStyle(fontSize: 15)),
                              ),
                              if (hhmm.isNotEmpty)
                                Text(
                                  hhmm,
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 11),
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
                        child: Center(child: Text(s.t('chat_load_error'))))
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
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 4,
                      decoration:
                          InputDecoration(hintText: s.t('write_message')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () async {
                      final text = _ctrl.text.trim();
                      if (text.isEmpty) return;
                      await ref
                          .read(chatActionsProvider)
                          .sendMessage(widget.chatId, text);
                      _ctrl.clear();
                      _isNearBottom = true;
                      ref.invalidate(chatDataProvider(widget.chatId));
                      _scrollToBottom();
                    },
                    icon: const Icon(Icons.send),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
