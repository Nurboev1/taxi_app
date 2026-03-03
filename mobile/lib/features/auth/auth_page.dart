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
  bool _acceptedLegal = false;

  Future<void> _openLegalDoc(String path) async {
    final uri = Uri.parse('${Endpoints.baseUrl}$path');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
                const Text(
                    'Telefon raqamingizni kiriting, SMS kod bilan tez kiramiz.'),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: s.t('phone_number')),
                ),
                const SizedBox(height: 10),
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
                          final ok = await ref
                              .read(authControllerProvider.notifier)
                              .requestOtp(_phoneCtrl.text.trim());
                          if (ok && context.mounted) context.go('/otp');
                        },
                  child: Text(state.loading ? s.t('sending') : s.t('get_otp')),
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
