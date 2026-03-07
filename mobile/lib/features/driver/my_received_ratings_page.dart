import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/i18n/strings.dart';
import '../../core/widgets/rating_badge.dart';
import '../auth/auth_controller.dart';
import 'driver_controller.dart';

class MyReceivedRatingsPage extends ConsumerWidget {
  const MyReceivedRatingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final s = AppStrings.of(auth.profile?['language']?.toString());
    final ratingsAsync = ref.watch(receivedRatingsProvider);
    final summaryAsync = FutureBuilder<Map<String, dynamic>>(
      future: () async {
        final id = auth.userId;
        if (id == null) return {'average': 0.0, 'total': 0};
        final res =
            await ref.read(apiClientProvider).get(Endpoints.ratingSummary(id));
        return (res.data as Map).cast<String, dynamic>();
      }(),
      builder: (context, snapshot) {
        final avg = (snapshot.data?['average'] as num?)?.toDouble() ?? 0;
        final total = (snapshot.data?['total'] as num?)?.toInt() ?? 0;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t('overall_rating'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                RatingBadge(rating: avg),
                const SizedBox(height: 8),
                Text('${s.t('rating_count')}: $total'),
              ],
            ),
          ),
        );
      },
    );

    return Scaffold(
      appBar: AppBar(title: Text(s.t('home_driver_my_ratings'))),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(receivedRatingsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            summaryAsync,
            const SizedBox(height: 12),
            ratingsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return Center(child: Text(s.t('no_pending_ratings')));
                }
                return Column(
                  children: items.map((r) {
                    final stars = (r['stars'] as num).toDouble();
                    return Card(
                      child: ListTile(
                        title: Text(r['from_name'].toString()),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            RatingBadge(rating: stars, compact: true),
                            if ((r['comment'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(r['comment'].toString()),
                            ],
                            const SizedBox(height: 4),
                            Text((r['created_at'] ?? '').toString()),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              error: (_, __) => Text(s.t('pending_ratings_error')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }
}
