import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_error.dart';
import '../../core/widgets/neo_sections.dart';
import 'driver_monetization_controller.dart';

Future<bool> showDriverSubscriptionSheet(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String message,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _DriverSubscriptionSheet(
      title: title,
      message: message,
    ),
  );
  if (result == true) {
    ref.read(driverMonetizationActionsProvider).refresh();
  }
  return result == true;
}

class _DriverSubscriptionSheet extends ConsumerStatefulWidget {
  const _DriverSubscriptionSheet({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  ConsumerState<_DriverSubscriptionSheet> createState() =>
      _DriverSubscriptionSheetState();
}

class _DriverSubscriptionSheetState
    extends ConsumerState<_DriverSubscriptionSheet> {
  bool _loading = false;
  int? _paymentId;
  int _monthsCount = 1;

  Future<void> _checkout(String provider) async {
    try {
      setState(() => _loading = true);
      final res = await ref
          .read(driverMonetizationActionsProvider)
          .createCheckout(provider, monthsCount: _monthsCount);
      final paymentUrl = res['payment_url']?.toString() ?? '';
      _paymentId = (res['payment_id'] as num?)?.toInt();
      if (paymentUrl.isNotEmpty) {
        await launchUrl(
          Uri.parse(paymentUrl),
          mode: LaunchMode.externalApplication,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "To'lov oynasi ochildi. To'lovdan keyin shu yerga qaytib Tekshirish tugmasini bosing.",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(apiErrorMessage(e, fallback: "To'lovni boshlab bo'lmadi")),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refreshStatus() async {
    try {
      setState(() => _loading = true);
      if (_paymentId != null) {
        await ref
            .read(driverMonetizationActionsProvider)
            .paymentStatus(_paymentId!);
      }
      ref.read(driverMonetizationActionsProvider).refresh();
      final info = await ref.read(driverMonetizationProvider.future);
      if (!mounted) return;
      if (info.hasActiveSubscription) {
        Navigator.pop(context, true);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "To'lov hali faollashmagan. Kerak bo'lsa birozdan keyin yana tekshiring.",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(apiErrorMessage(e, fallback: "Holatni tekshirib bo'lmadi")),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _providerLabel(String provider) {
    switch (provider) {
      case 'click':
        return 'Click orqali to\'lash';
      case 'payme':
        return 'Payme orqali to\'lash';
      default:
        return provider;
    }
  }

  @override
  Widget build(BuildContext context) {
    final infoAsync = ref.watch(driverMonetizationProvider);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.52,
      maxChildSize: 0.92,
      builder: (context, controller) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: infoAsync.when(
          data: (info) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              children: [
                Center(
                  child: Container(
                    width: 54,
                    height: 6,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                NeoHeroCard(
                  title: widget.title,
                  subtitle: widget.message,
                  icon: Icons.workspace_premium_outlined,
                  badges: [
                    NeoBadge(
                      icon: Icons.payments_outlined,
                      label: "${info.monthlyPrice} so'm / oy",
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Pullik rejim yoqilgan",
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Haydovchi rejimidan foydalanish uchun faol oylik obuna kerak bo'ladi.",
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          info.hasActiveSubscription
                              ? "Sizda faol obuna bor. Qolgan kun: ${info.remainingDays}"
                              : "Hozircha faol obuna yo'q.",
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Necha oyga to'lamoqchisiz?",
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [1, 3, 6, 12].map((months) {
                            final selected = _monthsCount == months;
                            return ChoiceChip(
                              label: Text("$months oy"),
                              selected: selected,
                              onSelected: _loading
                                  ? null
                                  : (_) =>
                                      setState(() => _monthsCount = months),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "To'lov xulosasi",
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "${info.monthlyPrice} so'm x $_monthsCount oy",
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Jami: ${info.monthlyPrice * _monthsCount} so'm",
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (info.providers.isNotEmpty)
                  ...info.providers.map(
                    (provider) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FilledButton.icon(
                        onPressed: _loading ? null : () => _checkout(provider),
                        icon: const Icon(Icons.open_in_new),
                        label: Text(
                          "${_providerLabel(provider)} • ${info.monthlyPrice * _monthsCount} so'm",
                        ),
                      ),
                    ),
                  )
                else
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        "Hozircha to'lov usullari sozlanmagan. Admin paneldan yoqilgach shu yerda chiqadi.",
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _refreshStatus,
                  icon: const Icon(Icons.refresh),
                  label: const Text("To'lov holatini tekshirish"),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed:
                      _loading ? null : () => Navigator.pop(context, false),
                  child: const Text("Hozircha yopish"),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            children: [
              const SizedBox(height: 24),
              Text(
                apiErrorMessage(e,
                    fallback: "Pullik rejim ma'lumotini yuklab bo'lmadi"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DriverSubscriptionRequiredView extends ConsumerWidget {
  const DriverSubscriptionRequiredView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(driverMonetizationProvider);
    return infoAsync.when(
      data: (info) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            NeoHeroCard(
              title: "Haydovchi rejimi vaqtincha yopiq",
              subtitle:
                  "Pullik rejim yoqilgan. Davom etish uchun oylik obunani faollashtiring.",
              icon: Icons.lock_clock_outlined,
              badges: [
                NeoBadge(
                  icon: Icons.calendar_month_outlined,
                  label: "${info.monthlyPrice} so'm / oy",
                ),
              ],
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Faol obuna bo'lmasa yangi safar ochish va haydovchi imkoniyatlaridan foydalanish to'xtatiladi.",
                    ),
                    const SizedBox(height: 12),
                    if (info.remainingDays > 0)
                      Text(
                          "Sizda muzlatilgan ${info.remainingDays} kun qolgan."),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () async {
                await showDriverSubscriptionSheet(
                  context,
                  ref,
                  title: "Haydovchi obunasi",
                  message:
                      "Haydovchi bo'lib ishlash uchun oylik obunani yoqish kerak.",
                );
              },
              icon: const Icon(Icons.payments_outlined),
              label: const Text("Obunani ko'rish"),
            ),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            apiErrorMessage(e,
                fallback: "Monetization holatini yuklab bo'lmadi"),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
