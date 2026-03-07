import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/i18n/strings.dart';
import '../../core/widgets/neo_sections.dart';
import '../../core/widgets/neo_shell.dart';
import '../../core/widgets/rating_badge.dart';
import '../auth/auth_controller.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final p = auth.profile ?? <String, dynamic>{};
    final s = AppStrings.of(p['language']?.toString());
    final role = (auth.role ?? 'passenger') == 'driver'
        ? s.t('driver')
        : s.t('passenger');
    final fullName =
        '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim().trim();

    return NeoScaffold(
      title: s.t('profile'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          NeoHeroCard(
            title: fullName.isEmpty ? s.t('profile') : fullName,
            subtitle: '${s.t('phone')}: ${p['phone'] ?? '-'}',
            icon: Icons.account_circle_rounded,
            badges: [
              NeoBadge(icon: Icons.badge_outlined, label: role),
              NeoBadge(
                icon: Icons.language_rounded,
                label: p['language']?.toString() ?? 'uz',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: NeoMetricCard(
                  label: s.t('gender'),
                  value: p['gender']?.toString() ?? '-',
                  icon: Icons.wc_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NeoMetricCard(
                  label: s.t('phone'),
                  value: p['phone_visible'] == true
                      ? s.t('visibility_on')
                      : s.t('visibility_off'),
                  icon: Icons.phone_outlined,
                  tint: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NeoSectionHeader(
                    title: s.t('profile'),
                    subtitle: s.t('profile_info_subtitle'),
                  ),
                  const SizedBox(height: 12),
                  NeoInfoRow(
                    label: s.t('first_name'),
                    value: p['first_name']?.toString().isNotEmpty == true
                        ? p['first_name'].toString()
                        : '-',
                    icon: Icons.person_outline,
                  ),
                  NeoInfoRow(
                    label: s.t('last_name'),
                    value: p['last_name']?.toString().isNotEmpty == true
                        ? p['last_name'].toString()
                        : '-',
                    icon: Icons.person_pin_outlined,
                  ),
                  NeoInfoRow(
                    label: s.t('phone'),
                    value: p['phone']?.toString() ?? '-',
                    icon: Icons.phone_outlined,
                  ),
                  NeoInfoRow(
                    label: s.t('language'),
                    value: p['language']?.toString() ?? 'uz',
                    icon: Icons.language_rounded,
                  ),
                  if ((auth.role ?? '') == 'driver') ...[
                    const Divider(height: 24),
                    NeoInfoRow(
                      label: s.t('car_model'),
                      value: p['car_model']?.toString().isNotEmpty == true
                          ? p['car_model'].toString()
                          : '-',
                      icon: Icons.directions_car_outlined,
                    ),
                    NeoInfoRow(
                      label: s.t('car_number'),
                      value: p['car_number']?.toString().isNotEmpty == true
                          ? p['car_number'].toString()
                          : '-',
                      icon: Icons.pin_outlined,
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<Map<String, dynamic>>(
                      future: () async {
                        final id = auth.userId;
                        if (id == null) {
                          return {'average': 0.0, 'total': 0};
                        }
                        final res = await ref
                            .read(apiClientProvider)
                            .get(Endpoints.ratingSummary(id));
                        return (res.data as Map).cast<String, dynamic>();
                      }(),
                      builder: (context, snapshot) {
                        final avg =
                            (snapshot.data?['average'] as num?)?.toDouble() ??
                                0;
                        final total =
                            (snapshot.data?['total'] as num?)?.toInt() ?? 0;
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RatingBadge(rating: avg),
                              const SizedBox(height: 10),
                              Text(
                                '${s.t('rating_count')}: $total',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          NeoActionCard(
            icon: Icons.edit_outlined,
            title: s.t('edit'),
            subtitle: s.t('settings_manage_subtitle'),
            onTap: () => context.push('/settings'),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(s.t('confirm')),
                    content: Text(s.t('logout_confirm_body')),
                    actionsAlignment: MainAxisAlignment.spaceBetween,
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text("Yo'q"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Ha'),
                      ),
                    ],
                  ),
                );
                if (ok != true || !context.mounted) return;
                await ref.read(authControllerProvider.notifier).logout();
                if (context.mounted) context.go('/auth');
              },
              icon: const Icon(Icons.logout_rounded),
              label: Text(s.t('logout')),
            ),
          ),
        ],
      ),
    );
  }
}
