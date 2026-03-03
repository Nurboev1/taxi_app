import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/widgets/rating_badge.dart';
import '../auth/auth_controller.dart';
import 'passenger_controller.dart';

class MyRatingsPage extends ConsumerWidget {
  const MyRatingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(
        ref.watch(authControllerProvider).profile?['language']?.toString());
    final ratingsAsync = ref.watch(myGivenRatingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Qo'ygan baholarim")),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myGivenRatingsProvider);
        },
        child: ratingsAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                      height: 320,
                      child: Center(child: Text(s.t('no_pending_ratings'))))
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final r = items[i];
                final stars = (r['stars'] as num).toDouble();
                return Card(
                  child: ListTile(
                    title: Text(r['target_name'].toString()),
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
              },
            );
          },
          error: (_, __) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                  height: 320,
                  child: Center(child: Text(s.t('pending_ratings_error'))))
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
    );
  }
}
