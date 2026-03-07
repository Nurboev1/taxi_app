import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taxi_mobile/core/i18n/strings.dart';
import 'package:taxi_mobile/core/widgets/neo_shell.dart';

import 'auth_controller.dart';

class SetPasswordPage extends ConsumerStatefulWidget {
  const SetPasswordPage({
    super.key,
    required this.reason,
    required this.otp,
  });

  final String reason;
  final String otp;

  @override
  ConsumerState<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends ConsumerState<SetPasswordPage> {
  final _passwordCtrl = TextEditingController();
  final _passwordConfirmCtrl = TextEditingController();

  void _goAfterAuth() {
    final role = ref.read(authControllerProvider).role;
    final profile = ref.read(authControllerProvider).profile ?? {};
    final blocked = profile['driver_blocked'] == true;
    if (role == 'driver') {
      context.go(blocked ? '/driver-blocked' : '/driver');
    } else if (role == 'passenger') {
      context.go('/passenger');
    } else {
      context.go('/role');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final s = AppStrings.of(state.profile?['language']?.toString());

    return NeoScaffold(
      title: s.t('login'),
      child: ListView(
        padding: const EdgeInsets.only(top: 24),
        children: [
          NeoPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.reason == 'reset_password'
                      ? 'Yangi parol kiriting'
                      : 'Yangi akkaunt uchun parol kiriting',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Parol'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordConfirmCtrl,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Parolni takrorlang'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: state.loading
                      ? null
                      : () async {
                          final pwd = _passwordCtrl.text.trim();
                          if (pwd.length < 8) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Parol kamida 8 ta belgidan iborat bo\'lishi kerak',
                                ),
                              ),
                            );
                            return;
                          }
                          if (_passwordCtrl.text != _passwordConfirmCtrl.text) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Parollar mos kelmadi')),
                            );
                            return;
                          }

                          final ok = await ref
                              .read(authControllerProvider.notifier)
                              .completeOtpAndSetPassword(
                                widget.otp,
                                pwd,
                                reason: widget.reason,
                              );
                          if (!context.mounted || !ok) return;
                          _goAfterAuth();
                        },
                  child: Text(state.loading ? s.t('sending') : s.t('confirm')),
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
