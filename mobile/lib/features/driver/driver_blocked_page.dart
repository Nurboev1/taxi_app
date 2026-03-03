import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_error.dart';
import '../../core/i18n/strings.dart';
import '../auth/auth_controller.dart';

class DriverBlockedPage extends ConsumerWidget {
  const DriverBlockedPage({super.key});

  Future<void> _openContact() async {
    final uri = Uri.parse('https://t.me/Ilyos2618');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final s = AppStrings.of(auth.profile?['language']?.toString());
    final userId = auth.userId;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          userId == null
              ? s.t('driver_blocked_title')
              : '${s.t('driver_blocked_title')}  #$userId',
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.t('driver_blocked_title'),
                        style: Theme.of(context).textTheme.titleLarge),
                    if (userId != null) ...[
                      const SizedBox(height: 6),
                      Text('ID: $userId',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                    const SizedBox(height: 10),
                    Text(s.t('driver_blocked_message')),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openContact,
                        icon: const Icon(Icons.support_agent),
                        label: Text(s.t('contact_support')),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () async {
                          try {
                            await ref
                                .read(authControllerProvider.notifier)
                                .setRole('passenger');
                            if (!context.mounted) return;
                            context.go('/passenger');
                          } on DioException catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(apiErrorMessage(e,
                                      fallback: s.t('generic_error')))),
                            );
                          }
                        },
                        child: Text(s.t('switch_to_passenger')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
