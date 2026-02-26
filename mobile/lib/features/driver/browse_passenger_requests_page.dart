import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'driver_controller.dart';

class BrowsePassengerRequestsPage extends ConsumerWidget {
  const BrowsePassengerRequestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(openPassengerRequestsProvider);
    final trips = ref.watch(driverTripsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mos mijoz so‘rovlari')),
      body: requests.when(
        data: (items) {
          if (items.isEmpty) return const Center(child: Text('Mos so‘rovlar topilmadi'));
          return trips.when(
            data: (tripItems) {
              if (tripItems.isEmpty) {
                return const Center(child: Text('Avval safar yarating'));
              }
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final r = items[i];
                  return Card(
                    child: ListTile(
                      title: Text('${r['from_location']} -> ${r['to_location']}'),
                      subtitle: Text('Kerakli joy: ${r['seats_needed']} | Holat: ${r['status']}'),
                      trailing: PopupMenuButton<int>(
                        onSelected: (tripId) async {
                          try {
                            await ref.read(driverActionsProvider).claimRequest(r['id'] as int, tripId);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Claim muvaffaqiyatli yuborildi')),
                              );
                            }
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Claim yuborishda xatolik')),
                              );
                            }
                          }
                        },
                        itemBuilder: (_) {
                          return tripItems
                              .map(
                                (t) => PopupMenuItem<int>(
                                  value: t['id'] as int,
                                  child: Text('${t['from_location']} -> ${t['to_location']} (#${t['id']})'),
                                ),
                              )
                              .toList();
                        },
                        child: const Chip(label: Text('Claim berish')),
                      ),
                    ),
                  );
                },
              );
            },
            error: (_, __) => const Center(child: Text('Safarlarni yuklashda xatolik')),
            loading: () => const Center(child: CircularProgressIndicator()),
          );
        },
        error: (_, __) => const Center(child: Text('So‘rovlarni yuklashda xatolik')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
