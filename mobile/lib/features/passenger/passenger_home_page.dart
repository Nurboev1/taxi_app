import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:taxi_mobile/core/api/api_client.dart';
import 'package:taxi_mobile/core/api/api_error.dart';
import 'package:taxi_mobile/core/i18n/strings.dart';
import 'package:taxi_mobile/core/theme/theme_controller.dart';
import 'package:taxi_mobile/core/widgets/animated_blobs_background.dart';
import 'package:taxi_mobile/core/widgets/daytime_wave_background.dart';
import 'package:taxi_mobile/core/widgets/first_time_tutorial_dialog.dart';
import 'package:taxi_mobile/core/widgets/neo_sections.dart';
import 'package:taxi_mobile/features/chat/chat_controller.dart';
import 'package:taxi_mobile/features/notifications/notifications_controller.dart';

import '../auth/auth_controller.dart';
import 'passenger_controller.dart';

Future<void> _openSupportBot() async {
  final uri = Uri.parse('https://t.me/SafarUzSupportBot');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class PassengerHomePage extends ConsumerStatefulWidget {
  const PassengerHomePage({super.key});

  @override
  ConsumerState<PassengerHomePage> createState() => _PassengerHomePageState();
}

class _PassengerHomePageState extends ConsumerState<PassengerHomePage> {
  int _tab = 0;
  bool _tutorialChecked = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(passengerActionsProvider).restoreLastRequestId();
      if (mounted) {
        _maybeShowTutorial();
      }
    });
  }

  Future<void> _maybeShowTutorial() async {
    if (_tutorialChecked) return;
    _tutorialChecked = true;

    final store = ref.read(secureStoreProvider);
    final seen = await store.readPassengerTutorialSeen();
    if (seen || !mounted) return;

    final lang =
        ref.read(authControllerProvider).profile?['language']?.toString();
    final s = AppStrings.of(lang);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => FirstTimeTutorialDialog(
        title: s.t('tutorial_title'),
        skipText: s.t('tutorial_skip'),
        nextText: s.t('tutorial_next'),
        doneText: s.t('tutorial_done'),
        steps: [
          TutorialStepData(
            icon: Icons.dashboard_outlined,
            title: s.t('nav_home'),
            description: s.t('tutorial_passenger_home_desc'),
          ),
          TutorialStepData(
            icon: Icons.route_outlined,
            title: s.t('nav_trips'),
            description: s.t('tutorial_passenger_trips_desc'),
          ),
          TutorialStepData(
            icon: Icons.chat_bubble_outline,
            title: s.t('nav_chat'),
            description: s.t('tutorial_passenger_chat_desc'),
          ),
          TutorialStepData(
            icon: Icons.person_outline,
            title: s.t('nav_profile'),
            description: s.t('tutorial_profile_desc'),
          ),
        ],
      ),
    );

    await store.savePassengerTutorialSeen(true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final s = AppStrings.of(auth.profile?['language']?.toString());
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    final pages = <Widget>[
      _PassengerDashboard(s: s),
      _PassengerTripsTab(s: s),
      _PassengerChatTab(s: s),
      _PassengerProfileTab(s: s, isDark: isDark),
    ];

    final tabContent = SafeArea(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        child: KeyedSubtree(
          key: ValueKey(_tab),
          child: pages[_tab],
        ),
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(s.t('passenger_home')),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: isDark
            ? const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
              )
            : const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                statusBarBrightness: Brightness.light,
              ),
        elevation: 0,
      ),
      body: isDark
          ? AnimatedBlobsBackground(
              colors: const [Color(0xFF0F172A), Color(0xFF111827)],
              child: tabContent,
            )
          : DaytimeWaveBackground(child: tabContent),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (v) => setState(() => _tab = v),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: s.t('nav_home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.route_outlined),
            selectedIcon: const Icon(Icons.route),
            label: s.t('nav_trips'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: s.t('nav_chat'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: s.t('nav_profile'),
          ),
        ],
      ),
    );
  }
}

class _PassengerChatTab extends ConsumerWidget {
  const _PassengerChatTab({required this.s});

  final AppStrings s;

  Future<void> _deleteChat(
      BuildContext context, WidgetRef ref, int chatId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Chatni o'chirish"),
        content: const Text(
          "Ushbu chat ikkala tomon uchun ham butunlay o'chiriladi. Davom etasizmi?",
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Yo'q"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Ha, o'chir"),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(chatActionsProvider).deleteChat(chatId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Chat o'chirildi")),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(apiErrorMessage(e, fallback: s.t('generic_error'))),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(myChatsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myChatsProvider),
      child: chatsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                NeoHeroCard(
                  title: s.t('nav_chat'),
                  subtitle: s.t('tutorial_passenger_chat_desc'),
                  icon: Icons.chat_bubble_outline_rounded,
                ),
                const SizedBox(height: 24),
                NeoEmptyState(
                  icon: Icons.forum_outlined,
                  title: s.t('no_chats'),
                  subtitle: s.t('tutorial_passenger_chat_desc'),
                ),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: items.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: NeoHeroCard(
                    title: s.t('nav_chat'),
                    subtitle: s.t('tutorial_passenger_chat_desc'),
                    icon: Icons.chat_bubble_outline_rounded,
                    badges: [
                      NeoBadge(
                        icon: Icons.mark_chat_unread_outlined,
                        label: '${items.length}',
                      ),
                    ],
                  ),
                );
              }

              final c = items[index - 1];
              final chatId = c['chat_id'] as int;
              final name = c['driver_name']?.toString() ??
                  c['passenger_name']?.toString() ??
                  s.t('chat');
              final last =
                  (c['last_message']?.toString().trim().isNotEmpty ?? false)
                      ? c['last_message'].toString().trim()
                      : s.t('no_message');

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: NeoActionCard(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: name,
                  subtitle: last,
                  onTap: () => context.push('/chat/$chatId'),
                  tint: Theme.of(context).colorScheme.secondary,
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz_rounded),
                    onSelected: (value) async {
                      if (value == 'open') {
                        context.push('/chat/$chatId');
                      } else if (value == 'delete') {
                        await _deleteChat(context, ref, chatId);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'open', child: Text("Suhbatni ochish")),
                      PopupMenuItem(
                          value: 'delete', child: Text("Chatni o'chirish")),
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
              child: Center(child: Text(s.t('chats_load_error'))),
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
    );
  }
}

class _PassengerDashboard extends ConsumerWidget {
  const _PassengerDashboard({required this.s});

  final AppStrings s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final name =
        (auth.profile?['first_name']?.toString().trim().isNotEmpty ?? false)
            ? auth.profile!['first_name'].toString().trim()
            : s.t('passenger');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        NeoHeroCard(
          title: '$name, ${s.t('passenger_home')}',
          subtitle: s.t('home_passenger_banner'),
          icon: Icons.explore_outlined,
          badges: [
            NeoBadge(
              icon: Icons.add_road_rounded,
              label: s.t('create_request'),
            ),
            NeoBadge(
              icon: Icons.analytics_outlined,
              label: s.t('request_status'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const NeoSectionHeader(
          title: 'Passenger Flow',
          subtitle: 'Create a request, track matching and rate completed trips',
        ),
        const SizedBox(height: 10),
        NeoActionCard(
          icon: Icons.add_road_rounded,
          title: s.t('create_request'),
          subtitle: s.t('home_passenger_create_request_subtitle'),
          onTap: () => context.push('/passenger/create-request'),
        ),
        NeoActionCard(
          icon: Icons.analytics_outlined,
          title: s.t('request_status'),
          subtitle: s.t('home_passenger_request_status_subtitle'),
          onTap: () => context.push('/passenger/request-status'),
          tint: Theme.of(context).colorScheme.secondary,
        ),
      ],
    );
  }
}

class _PassengerTripsTab extends StatelessWidget {
  const _PassengerTripsTab({required this.s});

  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        NeoHeroCard(
          title: s.t('nav_trips'),
          subtitle: s.t('tutorial_passenger_trips_desc'),
          icon: Icons.route_rounded,
          badges: [
            NeoBadge(
              icon: Icons.star_outline_rounded,
              label: s.t('rate_trip'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        NeoActionCard(
          icon: Icons.star_outline_rounded,
          title: s.t('rate_trip'),
          subtitle: s.t('home_passenger_rate_subtitle'),
          onTap: () => context.push('/passenger/rate-trip'),
        ),
        NeoActionCard(
          icon: Icons.history_toggle_off_rounded,
          title: s.t('home_passenger_my_ratings'),
          subtitle: s.t('home_passenger_my_ratings_subtitle'),
          onTap: () => context.push('/passenger/my-ratings'),
          tint: Theme.of(context).colorScheme.tertiary,
        ),
      ],
    );
  }
}

class _PassengerProfileTab extends ConsumerWidget {
  const _PassengerProfileTab({required this.s, required this.isDark});

  final AppStrings s;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsCountProvider);
    final notificationsSubtitle = unread > 0
        ? s.t('notifications_new_count').replaceFirst('{count}', '$unread')
        : s.t('notifications_new_none');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        NeoHeroCard(
          title: s.t('nav_profile'),
          subtitle: s.t('tutorial_profile_desc'),
          icon: Icons.account_circle_rounded,
          badges: [
            NeoBadge(
              icon: Icons.notifications_outlined,
              label: unread > 0 ? '$unread' : s.t('notifications'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        NeoActionCard(
          icon: isDark ? Icons.light_mode : Icons.dark_mode,
          title: isDark ? s.t('theme_light') : s.t('theme_dark'),
          subtitle: s.t('app_theme'),
          onTap: () => ref.read(themeModeProvider.notifier).toggle(),
        ),
        NeoActionCard(
          icon: Icons.notifications_outlined,
          title: s.t('notifications'),
          subtitle: notificationsSubtitle,
          onTap: () => context.push('/notifications'),
        ),
        NeoActionCard(
          icon: Icons.person_outline,
          title: s.t('profile'),
          subtitle: s.t('profile_info_subtitle'),
          onTap: () => context.push('/profile'),
        ),
        NeoActionCard(
          icon: Icons.settings_outlined,
          title: s.t('settings'),
          subtitle: s.t('settings_manage_subtitle'),
          onTap: () => context.push('/settings'),
        ),
        NeoActionCard(
          icon: Icons.support_agent_outlined,
          title: s.t('contact_support'),
          subtitle: 'Telegram: @SafarUzSupportBot',
          onTap: _openSupportBot,
          tint: Colors.orange.shade700,
        ),
      ],
    );
  }
}
