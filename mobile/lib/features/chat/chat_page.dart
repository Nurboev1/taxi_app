import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/strings.dart';
import '../../core/widgets/neo_sections.dart';
import '../../core/widgets/neo_shell.dart';
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

    return NeoScaffold(
      title: chatAsync.maybeWhen(
        data: (c) =>
            c['peer_name']?.toString() ?? '${s.t('chat')} #${widget.chatId}',
        orElse: () => '${s.t('chat')} #${widget.chatId}',
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
        ),
      ],
      child: Column(
        children: [
          chatAsync.maybeWhen(
            data: (chat) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: NeoHeroCard(
                title: chat['peer_name']?.toString() ?? s.t('chat'),
                subtitle:
                    chat['peer_phone']?.toString() ?? s.t('write_message'),
                icon: Icons.forum_outlined,
                badges: [
                  NeoBadge(
                    icon: Icons.chat_bubble_outline_rounded,
                    label:
                        '${((chat['messages'] as List?) ?? const []).length}',
                  ),
                ],
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
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
                          child: NeoEmptyState(
                            icon: Icons.mark_chat_read_outlined,
                            title: s.t('messages_empty'),
                            subtitle: s.t('write_message'),
                          ),
                        ),
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
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
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
                          constraints: const BoxConstraints(maxWidth: 300),
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isMine
                                  ? [
                                      theme.colorScheme.primary
                                          .withValues(alpha: 0.18),
                                      theme.colorScheme.primaryContainer,
                                    ]
                                  : [
                                      theme.colorScheme.surface,
                                      theme.colorScheme.surfaceContainerHighest,
                                    ],
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(isMine ? 18 : 6),
                              bottomRight: Radius.circular(isMine ? 6 : 18),
                            ),
                            border: Border.all(
                              color: isMine
                                  ? theme.colorScheme.primary
                                      .withValues(alpha: 0.16)
                                  : theme.dividerColor.withValues(alpha: 0.35),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 14,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  body,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              if (hhmm.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  hhmm,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
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
                      child: Center(child: Text(s.t('chat_load_error'))),
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
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: s.t('write_message'),
                          border: InputBorder.none,
                          isCollapsed: true,
                          hintStyle: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
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
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
