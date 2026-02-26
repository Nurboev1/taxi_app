import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';

class DriverHomePage extends ConsumerWidget {
  const DriverHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Taxist oynasi'),
        actions: [
          IconButton(
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) context.go('/auth');
            },
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton(
            onPressed: () => context.push('/driver/create-trip'),
            child: const Text('Safar e‘lonini yaratish'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => context.push('/driver/my-trips'),
            child: const Text('Mening safarlarim'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => context.push('/driver/open-requests'),
            child: const Text('Mos so‘rovlarni ko‘rish'),
          ),
        ],
      ),
    );
  }
}
