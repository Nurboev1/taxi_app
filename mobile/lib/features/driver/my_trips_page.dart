import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taxi_mobile/core/i18n/strings.dart';
import 'package:taxi_mobile/core/widgets/neo_sections.dart';
import 'package:taxi_mobile/core/widgets/neo_shell.dart';

import '../auth/auth_controller.dart';
import 'driver_controller.dart';

class MyTripsPage extends ConsumerWidget {
  const MyTripsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(
      ref.watch(authControllerProvider).profile?['language']?.toString(),
    );
    final trips = ref.watch(driverTripsProvider);

    return NeoScaffold(
      title: s.t('my_trips'),
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(driverTripsProvider);
        },
        child: trips.when(
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  NeoHeroCard(
                    title: s.t('my_trips'),
                    subtitle: s.t('home_driver_my_trips_subtitle'),
                    icon: Icons.route_rounded,
                  ),
                  const SizedBox(height: 24),
                  NeoEmptyState(
                    icon: Icons.route_outlined,
                    title: s.t('no_trips'),
                    subtitle: s.t('home_driver_create_trip_subtitle'),
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
                      title: s.t('my_trips'),
                      subtitle: s.t('home_driver_my_trips_subtitle'),
                      icon: Icons.route_rounded,
                      badges: [
                        NeoBadge(
                          icon: Icons.groups_rounded,
                          label: '${items.length}',
                        ),
                      ],
                    ),
                  );
                }

                final t = items[index - 1];
                final seatsTaken = '${t['seats_taken']}/${t['seats_total']}';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () =>
                          context.push('/driver/trip-passengers/${t['id']}'),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    Icons.local_taxi_rounded,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${t['from_location']} -> ${t['to_location']}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${s.t('price')}: ${t['price_per_seat']}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Chat',
                                  onPressed: () => context.push('/chats'),
                                  icon: const Icon(
                                      Icons.chat_bubble_outline_rounded),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: NeoMetricCard(
                                    label: s.t('seats'),
                                    value: seatsTaken,
                                    icon: Icons.event_seat_outlined,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: NeoMetricCard(
                                    label: s.t('price'),
                                    value: '${t['price_per_seat']}',
                                    icon: Icons.payments_outlined,
                                    tint:
                                        Theme.of(context).colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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
                child: Center(child: Text(s.t('generic_error'))),
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
    );
  }
}
