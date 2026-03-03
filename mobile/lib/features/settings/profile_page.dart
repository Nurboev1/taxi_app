import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/i18n/strings.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(s.t('profile'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim(),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('${s.t('phone')}: ${p['phone'] ?? '-'}'),
                  Text('${s.t('gender')}: ${p['gender'] ?? '-'}'),
                  Text('${s.t('language')}: ${p['language'] ?? 'uz'}'),
                  Text('Rol: $role'),
                  if ((auth.role ?? '') == 'driver') ...[
                    Text('${s.t('car_model')}: ${p['car_model'] ?? '-'}'),
                    Text('${s.t('car_number')}: ${p['car_number'] ?? '-'}'),
                    const SizedBox(height: 10),
                    FutureBuilder<Map<String, dynamic>>(
                      future: () async {
                        final id = auth.userId;
                        if (id == null) return {'average': 0.0, 'total': 0};
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
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            RatingBadge(rating: avg),
                            const SizedBox(height: 4),
                            Text('Baholar soni: $total'),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => context.push('/settings'),
            child: Text(s.t('edit')),
          ),
          const SizedBox(height: 24),
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
                    title: const Text('Tasdiqlash'),
                    content: const Text('Hisobdan chiqishni tasdiqlaysizmi?'),
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
              icon: const Icon(Icons.logout),
              label: const Text('Chiqish'),
            ),
          ),
        ],
      ),
    );
  }
}
