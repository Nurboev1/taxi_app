import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taxi_mobile/core/api/api_client.dart';
import 'package:taxi_mobile/core/i18n/strings.dart';
import 'package:taxi_mobile/core/theme/theme_controller.dart';
import 'package:taxi_mobile/core/widgets/animated_blobs_background.dart';
import 'package:taxi_mobile/core/widgets/daytime_wave_background.dart';
import 'package:taxi_mobile/core/widgets/first_time_tutorial_dialog.dart';
import 'package:taxi_mobile/core/api/api_error.dart';
import 'package:taxi_mobile/features/chat/chat_controller.dart';
import 'package:taxi_mobile/features/driver/driver_blocked_page.dart';
import 'package:taxi_mobile/features/notifications/notifications_controller.dart';

import '../auth/auth_controller.dart';

class DriverHomePage extends ConsumerStatefulWidget {
  const DriverHomePage({super.key});

  @override
  ConsumerState<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends ConsumerState<DriverHomePage> {
  int _tab = 0;
  bool _tutorialChecked = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_maybeShowTutorial);
  }

  Future<void> _maybeShowTutorial() async {
    if (_tutorialChecked) return;
    _tutorialChecked = true;
    final auth = ref.read(authControllerProvider);
    if (auth.profile?['driver_blocked'] == true) return;

    final store = ref.read(secureStoreProvider);
    final seen = await store.readDriverTutorialSeen();
    if (seen || !mounted) return;

    final s = AppStrings.of(auth.profile?['language']?.toString());
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
            description: s.t('tutorial_driver_home_desc'),
          ),
          TutorialStepData(
            icon: Icons.route_outlined,
            title: s.t('nav_trips'),
            description: s.t('tutorial_driver_trips_desc'),
          ),
          TutorialStepData(
            icon: Icons.chat_bubble_outline,
            title: s.t('nav_chat'),
            description: s.t('tutorial_driver_chat_desc'),
          ),
          TutorialStepData(
            icon: Icons.person_outline,
            title: s.t('nav_profile'),
            description: s.t('tutorial_profile_desc'),
          ),
        ],
      ),
    );

    await store.saveDriverTutorialSeen(true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isBlocked = auth.profile?['driver_blocked'] == true;
    if (isBlocked) {
      return const DriverBlockedPage();
    }
    final s = AppStrings.of(auth.profile?['language']?.toString());
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    final bg1 = isDark ? const Color(0xFF111827) : const Color(0xFFECFDF5);
    final bg2 = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    final pages = <Widget>[
      _DriverDashboard(s: s),
      _DriverTripsTab(s: s),
      _DriverChatTab(s: s),
      _DriverProfileTab(s: s, isDark: isDark),
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
        title: Text(s.t('driver_home')),
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
              colors: [bg1, bg2],
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
              label: s.t('nav_home')),
          NavigationDestination(
              icon: const Icon(Icons.route_outlined),
              selectedIcon: const Icon(Icons.route),
              label: s.t('nav_trips')),
          NavigationDestination(
              icon: const Icon(Icons.chat_bubble_outline),
              selectedIcon: const Icon(Icons.chat_bubble),
              label: s.t('nav_chat')),
          NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: s.t('nav_profile')),
        ],
      ),
    );
  }
}

class _DriverChatTab extends ConsumerWidget {
  const _DriverChatTab({required this.s});

  final AppStrings s;

  Future<void> _deleteChat(
      BuildContext context, WidgetRef ref, int chatId) async {
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
    if (ok != true) return;
    try {
      await ref.read(chatActionsProvider).deleteChat(chatId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Chat o'chirildi")));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(apiErrorMessage(e, fallback: s.t('generic_error')))),
      );
    }
  }

  Future<void> _openChatMenu(
      BuildContext context, WidgetRef ref, Map<String, dynamic> c) async {
    final chatId = c['chat_id'] as int;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Suhbatni ochish'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/chat/$chatId');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text("Chatni o'chirish",
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                await _deleteChat(context, ref, chatId);
              },
            ),
          ],
        ),
      ),
    );
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
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                    height: 320, child: Center(child: Text(s.t('no_chats')))),
              ],
            );
          }
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final c = items[i];
              final chatId = c['chat_id'] as int;
              final last = c['last_message']?.toString();
              return ListTile(
                leading:
                    const CircleAvatar(child: Icon(Icons.chat_bubble_outline)),
                title: Text(c['passenger_name']?.toString() ??
                    c['driver_name']?.toString() ??
                    s.t('chat')),
                subtitle: Text(
                    (last == null || last.isEmpty) ? s.t('no_message') : last),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/chat/$chatId'),
                onLongPress: () => _openChatMenu(context, ref, c),
              );
            },
          );
        },
        error: (_, __) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
                height: 320,
                child: Center(child: Text(s.t('chats_load_error')))),
          ],
        ),
        loading: () => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(
                height: 320, child: Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }
}

class _DriverDashboard extends StatelessWidget {
  const _DriverDashboard({required this.s});
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(s.t('home_driver_banner')),
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.add_circle_outline,
          title: s.t('create_trip_ad'),
          subtitle: s.t('home_driver_create_trip_subtitle'),
          onTap: () => context.push('/driver/create-trip'),
        ),
        _ActionTile(
          icon: Icons.groups_2_outlined,
          title: s.t('browse_requests'),
          subtitle: s.t('home_driver_browse_requests_subtitle'),
          onTap: () => context.push('/driver/open-requests'),
        ),
      ],
    );
  }
}

class _DriverTripsTab extends StatelessWidget {
  const _DriverTripsTab({required this.s});
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        _ActionTile(
          icon: Icons.route_outlined,
          title: s.t('my_trips'),
          subtitle: s.t('home_driver_my_trips_subtitle'),
          onTap: () => context.push('/driver/my-trips'),
        ),
        _ActionTile(
          icon: Icons.star_outline,
          title: s.t('home_driver_my_ratings'),
          subtitle: s.t('home_driver_my_ratings_subtitle'),
          onTap: () => context.push('/driver/my-ratings'),
        ),
      ],
    );
  }
}

class _DriverProfileTab extends ConsumerWidget {
  const _DriverProfileTab({required this.s, required this.isDark});
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
        _ActionTile(
          icon: isDark ? Icons.light_mode : Icons.dark_mode,
          title: isDark ? s.t('theme_light') : s.t('theme_dark'),
          subtitle: s.t('app_theme'),
          onTap: () => ref.read(themeModeProvider.notifier).toggle(),
        ),
        _ActionTile(
          icon: Icons.notifications_outlined,
          title: s.t('notifications'),
          subtitle: notificationsSubtitle,
          onTap: () => context.push('/notifications'),
        ),
        _ActionTile(
          icon: Icons.person_outline,
          title: s.t('profile'),
          subtitle: s.t('profile_info_subtitle'),
          onTap: () => context.push('/profile'),
        ),
        _ActionTile(
          icon: Icons.settings_outlined,
          title: s.t('settings'),
          subtitle: s.t('settings_manage_subtitle'),
          onTap: () => context.push('/settings'),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
