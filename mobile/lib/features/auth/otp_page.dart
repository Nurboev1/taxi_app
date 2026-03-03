import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taxi_mobile/core/i18n/strings.dart';
import 'package:taxi_mobile/core/widgets/neo_shell.dart';

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
    final s = AppStrings.of(state.profile?['language']?.toString());

    return NeoScaffold(
      title: s.t('otp_verify'),
      child: ListView(
        padding: const EdgeInsets.only(top: 24),
        children: [
          NeoPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t('otp_test')),
                const SizedBox(height: 12),
                TextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: s.t('otp_code')),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: state.loading
                      ? null
                      : () async {
                          final ok = await ref
                              .read(authControllerProvider.notifier)
                              .verifyOtp(_otpCtrl.text.trim());
                          if (!context.mounted || !ok) return;
                          final role = ref.read(authControllerProvider).role;
                          final profile =
                              ref.read(authControllerProvider).profile ?? {};
                          final blocked = profile['driver_blocked'] == true;
                          if (role == 'driver') {
                            context.go(blocked ? '/driver-blocked' : '/driver');
                          } else if (role == 'passenger') {
                            context.go('/passenger');
                          } else {
                            context.go('/role');
                          }
                        },
                  child:
                      Text(state.loading ? s.t('verifying') : s.t('confirm')),
                ),
                if (state.error != null) ...[
                  const SizedBox(height: 12),
                  Text(state.error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
