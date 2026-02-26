import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_controller.dart';

class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({super.key});

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  final _otpCtrl = TextEditingController(text: '0000');

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('OTP tasdiqlash')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Test rejimida kod: 0000'),
            const SizedBox(height: 12),
            TextField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'OTP kod'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: state.loading
                  ? null
                  : () async {
                      final ok = await ref.read(authControllerProvider.notifier).verifyOtp(_otpCtrl.text.trim());
                      if (!context.mounted || !ok) return;
                      final role = ref.read(authControllerProvider).role;
                      if (role == 'driver') {
                        context.go('/driver');
                      } else if (role == 'passenger') {
                        context.go('/passenger');
                      } else {
                        context.go('/role');
                      }
                    },
              child: Text(state.loading ? 'Tekshirilmoqda...' : 'Tasdiqlash'),
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
