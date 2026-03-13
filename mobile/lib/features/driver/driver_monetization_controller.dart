import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class DriverMonetizationInfo {
  const DriverMonetizationInfo({
    required this.enabled,
    required this.monthlyPrice,
    required this.providers,
    required this.hasActiveSubscription,
    required this.remainingSeconds,
    required this.remainingDays,
    required this.status,
    required this.showPaymentMenu,
    required this.canSwitchToDriver,
  });

  final bool enabled;
  final int monthlyPrice;
  final List<String> providers;
  final bool hasActiveSubscription;
  final int remainingSeconds;
  final int remainingDays;
  final String status;
  final bool showPaymentMenu;
  final bool canSwitchToDriver;

  factory DriverMonetizationInfo.fromMap(Map<String, dynamic> map) {
    return DriverMonetizationInfo(
      enabled: map['enabled'] == true,
      monthlyPrice: (map['monthly_price'] as num?)?.toInt() ?? 0,
      providers: ((map['providers'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      hasActiveSubscription: map['has_active_subscription'] == true,
      remainingSeconds: (map['remaining_seconds'] as num?)?.toInt() ?? 0,
      remainingDays: (map['remaining_days'] as num?)?.toInt() ?? 0,
      status: map['status']?.toString() ?? 'inactive',
      showPaymentMenu: map['show_payment_menu'] == true,
      canSwitchToDriver: map['can_switch_to_driver'] == true,
    );
  }
}

final driverMonetizationProvider =
    FutureProvider<DriverMonetizationInfo>((ref) async {
  final res =
      await ref.read(apiClientProvider).get(Endpoints.driverMonetization);
  return DriverMonetizationInfo.fromMap(
    (res.data as Map).cast<String, dynamic>(),
  );
});

class DriverMonetizationActions {
  DriverMonetizationActions(this.ref);

  final Ref ref;

  Future<Map<String, dynamic>> createCheckout(
    String provider, {
    int monthsCount = 1,
  }) async {
    final res = await ref.read(apiClientProvider).post(
      Endpoints.driverMonetizationCheckout,
      data: {
        'provider': provider,
        'months_count': monthsCount,
      },
    );
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> paymentStatus(int paymentId) async {
    final res = await ref
        .read(apiClientProvider)
        .get(Endpoints.driverMonetizationPayment(paymentId));
    return (res.data as Map).cast<String, dynamic>();
  }

  void refresh() {
    ref.invalidate(driverMonetizationProvider);
  }
}

final driverMonetizationActionsProvider =
    Provider<DriverMonetizationActions>((ref) {
  return DriverMonetizationActions(ref);
});
