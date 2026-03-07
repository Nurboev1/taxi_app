import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_error.dart';
import '../../core/i18n/strings.dart';
import '../../core/widgets/rating_badge.dart';
import '../auth/auth_controller.dart';
import '../chat/chat_controller.dart';
import 'chosen_driver_provider.dart';
import 'passenger_controller.dart';

class RequestStatusPage extends ConsumerWidget {
  const RequestStatusPage({super.key, this.requestId});

  final int? requestId;

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<bool> _confirmChoose(BuildContext context, AppStrings s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('confirm')),
        content: Text(s.t('choose_confirm_body')),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Yo'q"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Ha"),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang =
        ref.watch(authControllerProvider).profile?['language']?.toString();
    final s = AppStrings.of(lang);
    final rid = requestId ?? ref.watch(currentRequestIdProvider);
    if (rid == null) {
      return Scaffold(body: Center(child: Text(s.t('before_create_request'))));
    }

    final requestAsync = ref.watch(passengerRequestProvider(rid));
    final claimsAsync = ref.watch(claimsPollingProvider(rid));
    final chosenInfoState = ref.watch(chosenDriverInfoProvider);
    final chatsAsync = ref.watch(myChatsProvider);

    return Scaffold(
      appBar: AppBar(title: Text('${s.t('request_status')} #$rid')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(passengerRequestProvider(rid));
          ref.invalidate(claimsPollingProvider(rid));
          ref.invalidate(myChatsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            requestAsync.when(
              data: (req) => Card(
                child: ListTile(
                  title:
                      Text('${req['from_location']} -> ${req['to_location']}'),
                  subtitle: Text(
                      '${s.t('status')}: ${req['status']} | ${s.t('required_seats')}: ${req['seats_needed']}\n${s.t('male_seats')}: ${req['male_seats'] ?? 0} | ${s.t('female_seats')}: ${req['female_seats'] ?? 0}'),
                ),
              ),
              error: (_, __) => Text(s.t('request_load_error')),
              loading: () => const LinearProgressIndicator(),
            ),
            const SizedBox(height: 12),
            Text(s.t('claims_title')),
            const SizedBox(height: 8),
            claimsAsync.when(
              data: (claims) {
                if (claims.isEmpty) {
                  return Text(s.t('no_claims'));
                }
                return Column(
                  children: claims.map((c) {
                    final startTimeRaw = c['start_time']?.toString();
                    final startTime =
                        DateTime.tryParse(startTimeRaw ?? '')?.toLocal();
                    final departure = startTime == null
                        ? '-'
                        : DateFormat('dd.MM.yyyy HH:mm').format(startTime);
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${c['driver_name']} (${c['driver_gender'] ?? '-'})',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                RatingBadge(
                                  rating: (c['driver_average_rating'] as num?)
                                          ?.toDouble() ??
                                      0,
                                  compact: true,
                                ),
                                const SizedBox(width: 8),
                                Text('(${c['driver_ratings_total'] ?? 0})'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('${s.t('price')}: ${c['price_per_seat']}'),
                            Text(
                                'Mashina modeli: ${c['driver_car_model'] ?? '-'}'),
                            Text(
                                'Mashina raqami: ${c['driver_car_number'] ?? '-'}'),
                            Text('Jo\'nash vaqti: $departure'),
                            Text(
                                '${s.t('occupancy')}: ${c['seats_taken']}/${c['seats_total']}'),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.male, color: Colors.blue.shade600),
                                const SizedBox(width: 4),
                                Text('${c['trip_male_count'] ?? 0}'),
                                const SizedBox(width: 12),
                                Icon(Icons.female, color: Colors.pink.shade400),
                                const SizedBox(width: 4),
                                Text('${c['trip_female_count'] ?? 0}'),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  final confirmed =
                                      await _confirmChoose(context, s);
                                  if (!confirmed) return;
                                  try {
                                    final result = await ref
                                        .read(passengerActionsProvider)
                                        .chooseDriver(rid, c['id'] as int);
                                    ref
                                        .read(chosenDriverInfoProvider.notifier)
                                        .state = result;
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content:
                                                Text(s.t('choose_success'))),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(apiErrorMessage(e,
                                                fallback:
                                                    s.t('choose_error')))),
                                      );
                                    }
                                  }
                                },
                                child: Text(s.t('choose')),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              error: (_, __) => Text(s.t('claims_load_error')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
            const SizedBox(height: 12),
            Consumer(
              builder: (context, ref, _) {
                final req = requestAsync.valueOrNull;
                final claims =
                    claimsAsync.valueOrNull ?? const <Map<String, dynamic>>[];
                final chats =
                    chatsAsync.valueOrNull ?? const <Map<String, dynamic>>[];

                Map<String, dynamic>? chosen = chosenInfoState;

                if (chosen == null &&
                    req != null &&
                    req['chosen_claim_id'] != null) {
                  final chosenClaimId = req['chosen_claim_id'];
                  final chosenClaim =
                      claims.cast<Map<String, dynamic>?>().firstWhere(
                            (c) => c?['id'] == chosenClaimId,
                            orElse: () => null,
                          );
                  final chat = chats.cast<Map<String, dynamic>?>().firstWhere(
                        (c) => c?['request_id'] == rid,
                        orElse: () => null,
                      );

                  if (chosenClaim != null) {
                    chosen = {
                      'driver_name': chosenClaim['driver_name'],
                      'driver_phone': chosenClaim['driver_phone'],
                      'chat_id': chat?['chat_id'],
                    };
                  }
                }

                if (chosen == null) return const SizedBox.shrink();
                final phone = chosen['driver_phone']?.toString();

                return Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${s.t('selected_driver')}: ${chosen['driver_name']}'),
                        Text(
                            '${s.t('phone')}: ${chosen['driver_phone'] ?? s.t('hidden')}'),
                        const SizedBox(height: 8),
                        if (phone != null && phone.isNotEmpty) ...[
                          ElevatedButton.icon(
                            onPressed: () => _call(phone),
                            icon: const Icon(Icons.call),
                            label: const Text('Qo\'ng\'iroq qilish'),
                          ),
                          const SizedBox(height: 8),
                        ],
                        ElevatedButton(
                          onPressed: chosen['chat_id'] == null
                              ? null
                              : () =>
                                  context.push('/chat/${chosen!['chat_id']}'),
                          child: Text(s.t('open_chat')),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
