import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taxi_mobile/core/api/api_error.dart';
import 'package:taxi_mobile/core/i18n/strings.dart';

import '../auth/auth_controller.dart';
import 'driver_controller.dart';

class BrowsePassengerRequestsPage extends ConsumerStatefulWidget {
  const BrowsePassengerRequestsPage({super.key});

  @override
  ConsumerState<BrowsePassengerRequestsPage> createState() =>
      _BrowsePassengerRequestsPageState();
}

class _BrowsePassengerRequestsPageState
    extends ConsumerState<BrowsePassengerRequestsPage> {
  final Set<int> _locallyClaimed = <int>{};
  final Map<int, DateTime> _decisionSeenAt = <int, DateTime>{};
  static const Duration _decisionHighlightDuration = Duration(seconds: 22);

  String _matchText(AppStrings s, String? level) {
    switch (level) {
      case 'high':
        return s.t('match_high');
      case 'medium':
        return s.t('match_medium');
      default:
        return s.t('match_low');
    }
  }

  (IconData, Color) _genderIcon(String? gender) {
    switch (gender) {
      case 'male':
        return (Icons.male, Colors.blue);
      case 'female':
        return (Icons.female, Colors.pink);
      default:
        return (Icons.person_outline, Colors.grey);
    }
  }

  Future<bool> _confirmClaim(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Tasdiqlash"),
        content:
            const Text("Ushbu yo'lovchiga claim yuborishni tasdiqlaysizmi?"),
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

  void _syncDecisionHighlights(List<Map<String, dynamic>> items) {
    final now = DateTime.now();
    final visibleIds = <int>{};
    for (final item in items) {
      final id = item['id'] as int?;
      if (id == null) continue;
      visibleIds.add(id);
      final claimState = item['claim_state']?.toString() ?? 'none';
      if (claimState == 'accepted' || claimState == 'rejected') {
        _decisionSeenAt.putIfAbsent(id, () => now);
      } else {
        _decisionSeenAt.remove(id);
      }
    }
    _decisionSeenAt.removeWhere(
      (id, seenAt) =>
          !visibleIds.contains(id) ||
          now.difference(seenAt) > _decisionHighlightDuration,
    );
  }

  bool _isDecisionHighlighted(int requestId, String claimState) {
    if (claimState != 'accepted' && claimState != 'rejected') return false;
    final seenAt = _decisionSeenAt[requestId];
    if (seenAt == null) return false;
    return DateTime.now().difference(seenAt) <= _decisionHighlightDuration;
  }

  Widget _statusBadge(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text),
    );
  }

  Color? _cardColor(
    String claimState,
    bool locallyClaimed,
    bool decisionHighlighted,
  ) {
    if (claimState == 'accepted' && decisionHighlighted) {
      return Colors.green.withValues(alpha: 0.22);
    }
    if (claimState == 'rejected' && decisionHighlighted) {
      return Colors.red.withValues(alpha: 0.18);
    }
    if (claimState == 'pending' || (locallyClaimed && claimState == 'none')) {
      return Colors.amber.withValues(alpha: 0.26);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(
        ref.watch(authControllerProvider).profile?['language']?.toString());
    final requests = ref.watch(openPassengerRequestsProvider);
    final trips = ref.watch(driverTripsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.t('open_passenger_requests'))),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(openPassengerRequestsProvider);
          ref.invalidate(driverTripsProvider);
        },
        child: requests.when(
          data: (items) {
            _syncDecisionHighlights(items);
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                      height: 320,
                      child: Center(child: Text(s.t('no_matching_requests'))))
                ],
              );
            }
            return trips.when(
              data: (tripItems) {
                if (tripItems.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                          height: 320,
                          child: Center(child: Text(s.t('create_trip_first'))))
                    ],
                  );
                }
                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final r = items[i];
                    final requestId = r['id'] as int;
                    final iconMeta =
                        _genderIcon(r['passenger_gender']?.toString());
                    final timeGap = r['time_gap_minutes'];
                    final claimState = (r['claim_state']?.toString() ?? 'none');
                    final localClaimed = _locallyClaimed.contains(requestId);
                    final decisionHighlighted =
                        _isDecisionHighlighted(requestId, claimState);
                    final isAccepted = claimState == 'accepted';
                    final isPending =
                        claimState == 'pending' ||
                        (localClaimed && claimState == 'none');
                    final isRejected = claimState == 'rejected';
                    final cardColor = _cardColor(
                      claimState,
                      localClaimed,
                      decisionHighlighted,
                    );
                    return Card(
                      color: cardColor,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${r['from_location']} -> ${r['to_location']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            CircleAvatar(
                              radius: 16,
                              backgroundColor:
                                  iconMeta.$2.withValues(alpha: 0.15),
                              child: Icon(iconMeta.$1,
                                  color: iconMeta.$2, size: 20),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(
                                label: Text(
                                    '${s.t('required_seats')}: ${r['seats_needed']}'),
                                visualDensity: VisualDensity.compact,
                              ),
                              Chip(
                                label: Text(
                                    '${s.t('match_level')}: ${_matchText(s, r['match_level']?.toString())}'),
                                visualDensity: VisualDensity.compact,
                              ),
                              if (timeGap is int && timeGap > 0)
                                Chip(
                                  label:
                                      Text('${s.t('time_gap')}: $timeGap min'),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                        ),
                        trailing: isAccepted
                            ? _statusBadge(
                                context,
                                s.t('claim_accepted_short'),
                                decisionHighlighted
                                    ? Colors.green.withValues(alpha: 0.22)
                                    : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                              )
                            : isRejected
                                ? _statusBadge(
                                    context,
                                    s.t('claim_rejected_short'),
                                    decisionHighlighted
                                        ? Colors.red.withValues(alpha: 0.2)
                                        : Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                  )
                                : isPending
                                    ? _statusBadge(
                                        context,
                                        s.t('claim_pending_short'),
                                        Colors.amber.withValues(alpha: 0.26),
                                      )
                                    : PopupMenuButton<int>(
                                    onSelected: (tripId) async {
                                      final confirmed =
                                          await _confirmClaim(context);
                                      if (!confirmed) return;
                                      try {
                                        await ref
                                            .read(driverActionsProvider)
                                            .claimRequest(requestId, tripId);
                                        if (mounted) {
                                          setState(() {
                                            _locallyClaimed.add(requestId);
                                          });
                                        }
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content:
                                                    Text(s.t('claim_sent'))),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text(apiErrorMessage(e,
                                                    fallback: s
                                                        .t('claim_error')))),
                                          );
                                        }
                                      }
                                    },
                                    itemBuilder: (_) {
                                      return tripItems
                                          .map(
                                            (t) => PopupMenuItem<int>(
                                              value: t['id'] as int,
                                              child: Text(
                                                  '${t['from_location']} -> ${t['to_location']}\n#${t['id']}'),
                                            ),
                                          )
                                          .toList();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primaryContainer
                                            .withValues(alpha: 0.55),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.send_outlined,
                                              size: 18),
                                          const SizedBox(width: 6),
                                          Text(s.t('claim_send')),
                                        ],
                                      ),
                                    ),
                                  ),
                      ),
                    );
                  },
                );
              },
              error: (_, __) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                      height: 320,
                      child: Center(child: Text(s.t('trips_load_error'))))
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
            );
          },
          error: (_, __) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                  height: 320,
                  child: Center(child: Text(s.t('requests_load_error'))))
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
    );
  }
}
