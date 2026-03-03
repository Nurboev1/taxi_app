import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

final driverTripsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) async* {
  while (true) {
    final res = await ref.read(apiClientProvider).get(Endpoints.myTrips);
    yield (res.data as List).cast<Map<String, dynamic>>();
    await Future<void>.delayed(const Duration(seconds: 5));
  }
});

final openPassengerRequestsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) async* {
  while (true) {
    final res = await ref.read(apiClientProvider).get(Endpoints.openRequests);
    yield (res.data as List).cast<Map<String, dynamic>>();
    await Future<void>.delayed(const Duration(seconds: 7));
  }
});

final tripPassengersProvider =
    StreamProvider.family<List<Map<String, dynamic>>, int>(
        (ref, tripId) async* {
  while (true) {
    final res =
        await ref.read(apiClientProvider).get(Endpoints.tripPassengers(tripId));
    yield (res.data as List).cast<Map<String, dynamic>>();
    await Future<void>.delayed(const Duration(seconds: 5));
  }
});

final receivedRatingsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res =
      await ref.read(apiClientProvider).get(Endpoints.myReceivedRatings);
  return (res.data as List).cast<Map<String, dynamic>>();
});

class DriverActions {
  DriverActions(this.ref);

  final Ref ref;

  Future<void> createTrip({
    required String from,
    required String to,
    required DateTime start,
    required DateTime end,
    required int seatsTotal,
    required String price,
  }) async {
    await ref.read(apiClientProvider).post(
      Endpoints.createTrip,
      data: {
        'from_location': from,
        'to_location': to,
        'start_time': start.toUtc().toIso8601String(),
        'end_time': end.toUtc().toIso8601String(),
        'seats_total': seatsTotal,
        'price_per_seat': price,
      },
    );
    ref.invalidate(driverTripsProvider);
    ref.invalidate(openPassengerRequestsProvider);
  }

  Future<void> claimRequest(int requestId, int tripId) async {
    await ref
        .read(apiClientProvider)
        .post(Endpoints.claim(requestId), data: {'trip_id': tripId});
    ref.invalidate(openPassengerRequestsProvider);
    ref.invalidate(driverTripsProvider);
  }

  Future<void> finishTrip(int tripId) async {
    await ref.read(apiClientProvider).post(Endpoints.finishTrip(tripId));
    ref.invalidate(driverTripsProvider);
    ref.invalidate(tripPassengersProvider(tripId));
  }

  Future<void> finishPassenger(int tripId, int requestId) async {
    await ref
        .read(apiClientProvider)
        .post(Endpoints.finishPassenger(tripId, requestId));
    ref.invalidate(driverTripsProvider);
    ref.invalidate(tripPassengersProvider(tripId));
  }
}

final driverActionsProvider =
    Provider<DriverActions>((ref) => DriverActions(ref));
