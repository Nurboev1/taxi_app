import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

final currentRequestIdProvider = StateProvider<int?>((ref) => null);

final passengerRequestProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, requestId) async {
  final res = await ref.read(apiClientProvider).get(Endpoints.getPassengerRequest(requestId));
  return (res.data as Map).cast<String, dynamic>();
});

final requestMatchesProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, requestId) async {
  final res = await ref.read(apiClientProvider).get(Endpoints.getMatches(requestId));
  return (res.data as List).cast<Map<String, dynamic>>();
});

final claimsPollingProvider = StreamProvider.family<List<Map<String, dynamic>>, int>((ref, requestId) async* {
  while (true) {
    final res = await ref.read(apiClientProvider).get(Endpoints.claims(requestId));
    final items = (res.data as List).cast<Map<String, dynamic>>();
    yield items;

    final reqRes = await ref.read(apiClientProvider).get(Endpoints.getPassengerRequest(requestId));
    final status = reqRes.data['status'] as String;
    if (status == 'chosen' || status == 'locked' || status == 'cancelled' || status == 'expired') {
      break;
    }
    await Future<void>.delayed(const Duration(seconds: 6));
  }
});

class PassengerActions {
  PassengerActions(this.ref);

  final Ref ref;

  Future<int> createRequest({
    required String from,
    required String to,
    required DateTime start,
    required DateTime end,
    required int seatsNeeded,
  }) async {
    final res = await ref.read(apiClientProvider).post(
          Endpoints.createPassengerRequest,
          data: {
            'from_location': from,
            'to_location': to,
            'start_time': start.toUtc().toIso8601String(),
            'end_time': end.toUtc().toIso8601String(),
            'seats_needed': seatsNeeded,
          },
        );
    final id = res.data['id'] as int;
    ref.read(currentRequestIdProvider.notifier).state = id;
    return id;
  }

  Future<Map<String, dynamic>> chooseDriver(int requestId, int claimId) async {
    final res = await ref.read(apiClientProvider).post(
          Endpoints.choose(requestId),
          data: {'claim_id': claimId},
        );
    return (res.data as Map).cast<String, dynamic>();
  }
}

final passengerActionsProvider = Provider<PassengerActions>((ref) => PassengerActions(ref));
