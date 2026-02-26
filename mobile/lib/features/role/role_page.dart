import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';

class RolePage extends ConsumerWidget {
  const RolePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rol tanlash')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () async {
                await ref.read(authControllerProvider.notifier).setRole('driver');
                if (context.mounted) context.go('/driver');
              },
              child: const Text('Taxist'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await ref.read(authControllerProvider.notifier).setRole('passenger');
                if (context.mounted) context.go('/passenger');
              },
              child: const Text('Mijoz'),
            ),
          ],
        ),
      ),
    );
  }
}
