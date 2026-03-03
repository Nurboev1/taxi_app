import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/i18n/strings.dart';
import '../../core/widgets/rating_badge.dart';
import '../auth/auth_controller.dart';
import 'passenger_controller.dart';

class RateTripPage extends ConsumerStatefulWidget {
  const RateTripPage({super.key});

  @override
  ConsumerState<RateTripPage> createState() => _RateTripPageState();
}

class _RateTripPageState extends ConsumerState<RateTripPage> {
  final _commentCtrl = TextEditingController();
  int _stars = 5;
  String? _error;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(
        ref.watch(authControllerProvider).profile?['language']?.toString());
    final pendingAsync = ref.watch(pendingRatingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.t('rate_trip'))),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(pendingRatingsProvider);
        },
        child: pendingAsync.when(
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
                final item = items[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['driver_name'].toString(),
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                            '${item['from_location']} -> ${item['to_location']}'),
                        const SizedBox(height: 10),
                        RatingBadge(rating: _stars.toDouble()),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 2,
                          children: List.generate(5, (idx) {
                            final n = idx + 1;
                            return IconButton(
                              onPressed: () => setState(() => _stars = n),
                              icon: Icon(
                                n <= _stars
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: const Color(0xFFF4C430),
                                size: 30,
                              ),
                            );
                          }),
                        ),
                        TextField(
                          controller: _commentCtrl,
                          maxLines: 3,
                          decoration: InputDecoration(
                              labelText: s.t('comment_optional')),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              try {
                                await ref
                                    .read(passengerActionsProvider)
                                    .rateTrip(
                                      tripId: item['trip_id'] as int,
                                      stars: _stars,
                                      comment: _commentCtrl.text,
                                    );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(s.t('rating_submitted'))),
                                );
                                _commentCtrl.clear();
                                setState(() {
                                  _stars = 5;
                                  _error = null;
                                });
                                ref.invalidate(pendingRatingsProvider);
                              } catch (e) {
                                setState(() => _error = apiErrorMessage(e));
                              }
                            },
                            child: Text(s.t('submit_rating')),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(_error!,
                              style: const TextStyle(color: Colors.red)),
                        ]
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
