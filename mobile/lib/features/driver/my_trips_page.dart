import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'driver_controller.dart';

class MyTripsPage extends ConsumerWidget {
  const MyTripsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(driverTripsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mening safarlarim')),
      body: trips.when(
        data: (items) {
          if (items.isEmpty) return const Center(child: Text('Safarlar topilmadi'));
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final t = items[i];
              return ListTile(
                title: Text('${t['from_location']} -> ${t['to_location']}'),
                subtitle: Text('Narx: ${t['price_per_seat']} | Joy: ${t['seats_taken']}/${t['seats_total']}'),
              );
            },
          );
        },
        error: (_, __) => const Center(child: Text('Xatolik yuz berdi')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
