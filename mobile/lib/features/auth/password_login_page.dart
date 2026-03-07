import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taxi_mobile/core/i18n/strings.dart';
import 'package:taxi_mobile/core/widgets/neo_shell.dart';

import 'auth_controller.dart';

class PasswordLoginPage extends ConsumerStatefulWidget {
  const PasswordLoginPage({super.key});

  @override
  ConsumerState<PasswordLoginPage> createState() => _PasswordLoginPageState();
}

class _PasswordLoginPageState extends ConsumerState<PasswordLoginPage> {
  final _passwordCtrl = TextEditingController();

  Future<bool> _confirmResetOtpSend() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Tasdiqlash'),
          content: const Text(
            'Parolni tiklash uchun telefon raqamingizga SMS kod yuborilsinmi?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text("Yo'q"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Ha'),
            ),
          ],
        );
      },
    );
    return result == true;
  }

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
    final phone = state.phone;

    if (phone == null || phone.isEmpty) {
      return NeoScaffold(
        title: s.t('login'),
        child: Center(
          child: ElevatedButton(
            onPressed: () => context.go('/auth'),
            child: const Text('Telefon raqamga qaytish'),
          ),
        ),
      );
    }

    return NeoScaffold(
      title: s.t('login'),
      child: ListView(
        padding: const EdgeInsets.only(top: 24),
        children: [
          NeoPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(phone,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Parol'),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: state.loading
                        ? null
                        : () async {
                            final confirmed = await _confirmResetOtpSend();
                            if (!confirmed || !context.mounted) return;
                            final ok = await ref
                                .read(authControllerProvider.notifier)
                                .requestOtp(phone, reason: 'reset_password');
                            if (!context.mounted || !ok) return;
                            context.push('/otp?reason=reset_password');
                          },
                    child: const Text('Parolni unutdingizmi?'),
                  ),
                ),
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
                          final ok = await ref
                              .read(authControllerProvider.notifier)
                              .loginWithPassword(phone, pwd);
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
