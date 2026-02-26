import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'chosen_driver_provider.dart';
import 'passenger_controller.dart';

class RequestStatusPage extends ConsumerWidget {
  const RequestStatusPage({super.key, this.requestId});

  final int? requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rid = requestId ?? ref.watch(currentRequestIdProvider);
    if (rid == null) {
      return const Scaffold(body: Center(child: Text('Avval so‘rov yarating')));
    }

    final requestAsync = ref.watch(passengerRequestProvider(rid));
    final claimsAsync = ref.watch(claimsPollingProvider(rid));
    final chosenInfo = ref.watch(chosenDriverInfoProvider);

    return Scaffold(
      appBar: AppBar(title: Text('So‘rov #$rid holati')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          requestAsync.when(
            data: (req) => Card(
              child: ListTile(
                title: Text('${req['from_location']} -> ${req['to_location']}'),
                subtitle: Text('Holat: ${req['status']} | Kerakli joy: ${req['seats_needed']}'),
              ),
            ),
            error: (_, __) => const Text('So‘rovni yuklashda xatolik'),
            loading: () => const LinearProgressIndicator(),
          ),
          const SizedBox(height: 12),
          const Text('Claim bergan haydovchilar (max 10):'),
          const SizedBox(height: 8),
          claimsAsync.when(
            data: (claims) {
              if (claims.isEmpty) {
                return const Text('Hozircha claim yo‘q');
              }
              return Column(
                children: claims.map((c) {
                  return Card(
                    child: ListTile(
                      title: Text('${c['driver_name']} | ${c['from_location']} -> ${c['to_location']}'),
                      subtitle: Text(
                        'Narx: ${c['price_per_seat']} | Bandlik: ${c['seats_taken']}/${c['seats_total']}',
                      ),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          try {
                            final result = await ref.read(passengerActionsProvider).chooseDriver(rid, c['id'] as int);
                            ref.read(chosenDriverInfoProvider.notifier).state = result;
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Haydovchi tanlandi')),
                              );
                            }
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Tanlashda xatolik')),
                              );
                            }
                          }
                        },
                        child: const Text('Tanlash'),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
            error: (_, __) => const Text('Claimlarni yuklashda xatolik'),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
          if (chosenInfo != null) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tanlangan haydovchi: ${chosenInfo['driver_name']}'),
                    Text('Telefon: ${chosenInfo['driver_phone']}'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => context.push('/chat/${chosenInfo['chat_id']}'),
                      child: const Text('Chatni ochish'),
                    ),
                  ],
                ),
              ),
            )
          ]
        ],
      ),
    );
  }
}
