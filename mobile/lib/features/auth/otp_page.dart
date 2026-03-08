import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taxi_mobile/core/i18n/strings.dart';
import 'package:taxi_mobile/core/widgets/neo_shell.dart';

import 'auth_controller.dart';

class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({super.key, required this.reason});

  final String reason;

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  final _otpCtrl = TextEditingController();

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
                const Text('SMS orqali kelgan 4 xonali kodni kiriting.'),
                const SizedBox(height: 14),
                TextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: s.t('otp_code')),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: state.loading
                      ? null
                      : () {
                          final otp = _otpCtrl.text.trim();
                          if (otp.length != 4) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('4 xonali OTP kiriting')),
                            );
                            return;
                          }
                          final encodedOtp = Uri.encodeQueryComponent(otp);
                          context.push(
                            '/set-password?reason=${widget.reason}&otp=$encodedOtp',
                          );
                        },
                  child: Text(state.loading ? s.t('verifying') : s.t('confirm')),
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
