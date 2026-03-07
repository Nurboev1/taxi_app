import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_error.dart';
import '../../core/i18n/strings.dart';
import '../auth/auth_controller.dart';
import 'driver_controller.dart';

class TripPassengersPage extends ConsumerStatefulWidget {
  const TripPassengersPage({super.key, required this.tripId});

  final int tripId;

  @override
  ConsumerState<TripPassengersPage> createState() => _TripPassengersPageState();
}

class _TripPassengersPageState extends ConsumerState<TripPassengersPage> {
  String? _error;

  String _seatComposition(Map<String, dynamic> p, AppStrings s) {
    final maleSeats = (p['male_seats'] as num?)?.toInt() ?? 0;
    final femaleSeats = (p['female_seats'] as num?)?.toInt() ?? 0;
    final parts = <String>[];
    if (maleSeats > 0) parts.add('${s.t('male_seats')}: $maleSeats');
    if (femaleSeats > 0) parts.add('${s.t('female_seats')}: $femaleSeats');
    return parts.isEmpty ? '${s.t('seats')}: ${p['seats_needed']}' : parts.join(' | ');
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openChat(int? chatId) {
    if (chatId == null) return;
    context.push('/chat/$chatId');
  }

  Future<void> _openPassenger(Map<String, dynamic> p, AppStrings s) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final phone = p['passenger_phone']?.toString();
        final chatId = p['chat_id'] as int?;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p['passenger_name']?.toString() ?? '-',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('${s.t('first_name')}: ${p['passenger_first_name'] ?? '-'}'),
              Text('${s.t('last_name')}: ${p['passenger_last_name'] ?? '-'}'),
              Text('${s.t('gender_short')}: ${p['passenger_gender'] ?? '-'}'),
              Text(_seatComposition(p, s)),
              Text('${s.t('phone')}: ${phone ?? s.t('hidden')}'),
              Text('Safarlar soni: ${p['passenger_trips_count'] ?? 0}'),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (phone != null && phone.isNotEmpty)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _call(phone),
                        icon: const Icon(Icons.call),
                        label: Text('${s.t('phone')} qilish'),
                      ),
                    ),
                  if (phone != null && phone.isNotEmpty)
                    const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          chatId == null ? null : () => _openChat(chatId),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Chat'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: ctx,
                      builder: (dCtx) => AlertDialog(
                        title: Text(s.t('finish_trip')),
                        content: const Text('Safarni yakunlaysizmi?'),
                        actionsAlignment: MainAxisAlignment.spaceBetween,
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(dCtx, false),
                              child: const Text('Yo\'q')),
                          TextButton(
                              onPressed: () => Navigator.pop(dCtx, true),
                              child: const Text('Ha')),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    try {
                      await ref.read(driverActionsProvider).finishPassenger(
                          widget.tripId, p['request_id'] as int);
                      if (!mounted || !ctx.mounted || !context.mounted) return;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(s.t('trip_finished'))));
                    } catch (e) {
                      if (!mounted) return;
                      setState(() => _error = apiErrorMessage(e,
                          fallback: s.t('finish_trip_error')));
                    }
                  },
                  icon: const Icon(Icons.flag_circle_outlined),
                  label: Text(s.t('finish_trip')),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _finishTrip(AppStrings s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Safarni butunlay tugatish'),
        content: const Text('Safarni yakunlaysizmi?'),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Yo\'q')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ha')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(driverActionsProvider).finishTrip(widget.tripId);
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Safar tugatildi')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() =>
          _error = apiErrorMessage(e, fallback: s.t('finish_trip_error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(
        ref.watch(authControllerProvider).profile?['language']?.toString());
    final passengers = ref.watch(tripPassengersProvider(widget.tripId));

    return Scaffold(
      appBar:
          AppBar(title: Text('${s.t('trip_passengers')} #${widget.tripId}')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(tripPassengersProvider(widget.tripId));
          ref.invalidate(driverTripsProvider);
        },
        child: Column(
          children: [
            Expanded(
              child: passengers.when(
                data: (items) {
                  if (items.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                            height: 320,
                            child: Center(child: Text(s.t('no_passengers'))))
                      ],
                    );
                  }
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final p = items[i];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text((p['passenger_name']
                                      ?.toString()
                                      .isNotEmpty ??
                                  false)
                              ? p['passenger_name'].toString()[0].toUpperCase()
                              : '?'),
                        ),
                        title: Text(p['passenger_name'].toString()),
                        subtitle: Text(
                            '${s.t('gender_short')}: ${p['passenger_gender'] ?? '-'} | ${_seatComposition(p, s)}'),
                        trailing: Wrap(
                          spacing: 2,
                          children: [
                            if ((p['passenger_phone']?.toString().isNotEmpty ??
                                false))
                              IconButton(
                                tooltip: '${s.t('phone')} qilish',
                                onPressed: () =>
                                    _call(p['passenger_phone'].toString()),
                                icon: const Icon(Icons.call_outlined),
                              ),
                            IconButton(
                              tooltip: 'Chat',
                              onPressed: p['chat_id'] == null
                                  ? null
                                  : () => _openChat(p['chat_id'] as int?),
                              icon: const Icon(Icons.chat_bubble_outline),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () => _openPassenger(p, s),
                      );
                    },
                  );
                },
                error: (_, __) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                        height: 320,
                        child:
                            Center(child: Text(s.t('passengers_load_error'))))
                  ],
                ),
                loading: () => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(
                        height: 320,
                        child: Center(child: CircularProgressIndicator()))
                  ],
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _finishTrip(s),
                  icon: const Icon(Icons.task_alt_outlined),
                  label: const Text('Safarni butunlay tugatish'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
