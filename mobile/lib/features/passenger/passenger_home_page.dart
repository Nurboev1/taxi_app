import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';

class PassengerHomePage extends ConsumerWidget {
  const PassengerHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mijoz oynasi'),
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
            onPressed: () => context.push('/passenger/create-request'),
            child: const Text('So‘rov yaratish'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => context.push('/passenger/request-status'),
            child: const Text('So‘rov holatini ko‘rish'),
          ),
        ],
      ),
    );
  }
}
