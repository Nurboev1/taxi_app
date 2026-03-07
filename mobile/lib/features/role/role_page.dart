import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taxi_mobile/core/api/api_error.dart';
import 'package:taxi_mobile/core/i18n/strings.dart';
import 'package:taxi_mobile/core/widgets/neo_sections.dart';
import 'package:taxi_mobile/core/widgets/neo_shell.dart';

import '../auth/auth_controller.dart';

class RolePage extends ConsumerWidget {
  const RolePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang =
        ref.watch(authControllerProvider).profile?['language']?.toString();
    final s = AppStrings.of(lang);

    return NeoScaffold(
      title: s.t('choose_role'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
        children: [
          NeoHeroCard(
            title: s.t('choose_role'),
            subtitle: s.t('role_select_subtitle'),
            icon: Icons.swap_horiz_rounded,
            badges: [
              NeoBadge(
                icon: Icons.local_taxi_outlined,
                label: s.t('driver'),
              ),
              NeoBadge(
                icon: Icons.person_outline_rounded,
                label: s.t('passenger'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                _RoleCard(
                  icon: Icons.local_taxi_outlined,
                  title: s.t('driver'),
                  subtitle: s.t('role_driver_subtitle'),
                  onTap: () async {
                    try {
                      await ref
                          .read(authControllerProvider.notifier)
                          .setRole('driver');
                      if (context.mounted) context.go('/profile-setup');
                    } catch (e) {
                      if (!context.mounted) return;
                      if (apiErrorCode(e) == 'DRIVER_BLOCKED') {
                        context.go('/driver-blocked');
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(apiErrorMessage(e,
                              fallback: s.t('generic_error'))),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                _RoleCard(
                  icon: Icons.person_outline,
                  title: s.t('passenger'),
                  subtitle: s.t('role_passenger_subtitle'),
                  onTap: () async {
                    await ref
                        .read(authControllerProvider.notifier)
                        .setRole('passenger');
                    if (context.mounted) context.go('/profile-setup');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
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
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.42),
              Theme.of(context).colorScheme.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(subtitle),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
