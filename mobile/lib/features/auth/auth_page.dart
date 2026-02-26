import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_controller.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _phoneCtrl = TextEditingController(text: '+998');

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kirish')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefon raqam'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: state.loading
                  ? null
                  : () async {
                      final ok = await ref.read(authControllerProvider.notifier).requestOtp(_phoneCtrl.text.trim());
                      if (ok && context.mounted) context.go('/otp');
                    },
              child: Text(state.loading ? 'Yuborilmoqda...' : 'OTP olish'),
            ),
            if (state.error != null) ...[
              const SizedBox(height: 12),
              Text(state.error!, style: const TextStyle(color: Colors.red)),
            ]
          ],
        ),
      ),
    );
  }
}
