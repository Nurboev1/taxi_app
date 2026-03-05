import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taxi_mobile/core/api/endpoints.dart';
import 'package:taxi_mobile/core/i18n/strings.dart';
import 'package:taxi_mobile/core/widgets/neo_shell.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_controller.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _phoneCtrl = TextEditingController(text: '+998');
  final _passwordCtrl = TextEditingController();
  bool _acceptedLegal = false;

  Future<void> _openLegalDoc(String path) async {
    final uri = Uri.parse('${Endpoints.baseUrl}$path');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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

    return NeoScaffold(
      title: s.t('login'),
      child: ListView(
        padding: const EdgeInsets.only(top: 24),
        children: [
          NeoPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SafarUz',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('Telefon raqamingizni kiriting va davom eting.'),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: s.t('phone_number')),
                ),
                const SizedBox(height: 10),
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
                            if (!_acceptedLegal) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(s.t('must_accept_legal'))),
                              );
                              return;
                            }

                            final hasPassword = await ref
                                .read(authControllerProvider.notifier)
                                .checkPhoneStatus(_phoneCtrl.text.trim());
                            if (!context.mounted) return;
                            if (hasPassword != true) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Bu raqam uchun parol hali o\'rnatilmagan',
                                  ),
                                ),
                              );
                              return;
                            }

                            final ok = await ref
                                .read(authControllerProvider.notifier)
                                .requestOtp(
                                  _phoneCtrl.text.trim(),
                                  reason: 'reset_password',
                                );
                            if (!context.mounted || !ok) return;
                            context.go('/otp?reason=reset_password');
                          },
                    child: const Text('Parolni unutdim'),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _acceptedLegal,
                  onChanged: (v) => setState(() => _acceptedLegal = v == true),
                  title: Text(s.t('accept_legal')),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => _openLegalDoc('/legal/terms'),
                      child: Text(s.t('terms_of_use')),
                    ),
                    TextButton(
                      onPressed: () => _openLegalDoc('/legal/privacy'),
                      child: Text(s.t('privacy_policy')),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: state.loading
                      ? null
                      : () async {
                          if (!_acceptedLegal) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(s.t('must_accept_legal'))),
                            );
                            return;
                          }

                          final phone = _phoneCtrl.text.trim();
                          final hasPassword = await ref
                              .read(authControllerProvider.notifier)
                              .checkPhoneStatus(phone);
                          if (!context.mounted || hasPassword == null) return;

                          if (hasPassword) {
                            if (_passwordCtrl.text.trim().length < 8) {
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
                                .loginWithPassword(phone, _passwordCtrl.text.trim());
                            if (!context.mounted || !ok) return;
                            _goAfterAuth();
                            return;
                          }

                          final ok = await ref
                              .read(authControllerProvider.notifier)
                              .requestOtp(phone, reason: 'register');
                          if (!context.mounted || !ok) return;
                          context.go('/otp?reason=register');
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
