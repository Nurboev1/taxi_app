import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:taxi_mobile/core/api/api_error.dart';
import 'package:taxi_mobile/core/i18n/strings.dart';
import 'package:taxi_mobile/core/location/location_selector.dart';

import '../auth/auth_controller.dart';
import 'driver_controller.dart';

class CreateTripPage extends ConsumerStatefulWidget {
  const CreateTripPage({super.key});

  @override
  ConsumerState<CreateTripPage> createState() => _CreateTripPageState();
}

class _CreateTripPageState extends ConsumerState<CreateTripPage> {
  final _priceCtrl = TextEditingController();
  int _seatsTotal = 4;
  DateTime? _start;
  DateTime? _end;
  String? _error;

  String? _fromRegion;
  String? _fromDistrict;
  String? _toRegion;
  String? _toDistrict;

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final current = isStart ? (_start ?? now) : (_end ?? _start ?? now);
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      initialDate: current,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;
    final dt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _start = dt;
        if (_end != null && _end!.isBefore(dt)) {
          _end = dt.add(const Duration(hours: 1));
        }
      } else {
        _end = dt;
      }
    });
  }

  Future<void> _submit(AppStrings s) async {
    if (_fromRegion == null ||
        _fromDistrict == null ||
        _toRegion == null ||
        _toDistrict == null) {
      setState(() => _error = s.t('fill_locations'));
      return;
    }
    if (_start == null || _end == null) {
      setState(() => _error = s.t('enter_range'));
      return;
    }
    if (!_end!.isAfter(_start!)) {
      setState(() => _error = s.t('enter_range'));
      return;
    }
    if (_priceCtrl.text.trim().isEmpty) {
      setState(() => _error = s.t('trip_create_error'));
      return;
    }

    try {
      await ref.read(driverActionsProvider).createTrip(
            from: '$_fromRegion, $_fromDistrict',
            to: '$_toRegion, $_toDistrict',
            start: _start!,
            end: _end!,
            seatsTotal: _seatsTotal,
            price: _priceCtrl.text.trim(),
          );
      if (!mounted) return;
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      setState(() =>
          _error = apiErrorMessage(e, fallback: s.t('trip_create_error')));
    }
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang =
        ref.watch(authControllerProvider).profile?['language']?.toString();
    final s = AppStrings.of(lang);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(s.t('trip_create'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.secondary.withValues(alpha: 0.18),
                  theme.colorScheme.primary.withValues(alpha: 0.10),
                  theme.colorScheme.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: theme.colorScheme.secondary.withValues(alpha: 0.14),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('trip_create'),
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  s.t('trip_create_subtitle'),
                  style: textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _TopChip(
                      icon: Icons.event_seat_rounded,
                      label: '${s.t('seat_count')}: $_seatsTotal',
                    ),
                    _TopChip(
                      icon: Icons.payments_outlined,
                      label: _priceCtrl.text.trim().isEmpty
                          ? s.t('seat_price')
                          : '${_priceCtrl.text.trim()} so\'m',
                    ),
                    _TopChip(
                      icon: Icons.schedule_rounded,
                      label: _start == null
                          ? s.t('pick_start')
                          : DateFormat('dd.MM HH:mm').format(_start!),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          LocationSelector(
            title: s.t('from_location'),
            strings: s,
            value: LocationValue(region: _fromRegion, district: _fromDistrict),
            onRegionChanged: (v) => setState(() {
              _fromRegion = v;
              _fromDistrict = null;
            }),
            onDistrictChanged: (v) => setState(() => _fromDistrict = v),
          ),
          LocationSelector(
            title: s.t('to_location'),
            strings: s,
            value: LocationValue(region: _toRegion, district: _toDistrict),
            onRegionChanged: (v) => setState(() {
              _toRegion = v;
              _toDistrict = null;
            }),
            onDistrictChanged: (v) => setState(() => _toDistrict = v),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t('seat_price'),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.payments_outlined),
                      suffixText: 'so\'m',
                      hintText: '25000',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  _SeatStepper(
                    label: s.t('seat_count'),
                    value: _seatsTotal,
                    onChanged: (value) => setState(() => _seatsTotal = value),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t('time'),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _TimeTile(
                    icon: Icons.flight_takeoff_rounded,
                    color: theme.colorScheme.primary,
                    label: s.t('start_time_label'),
                    value: _start == null
                        ? s.t('pick_start')
                        : DateFormat('dd.MM.yyyy  HH:mm').format(_start!),
                    onTap: () => _pickDate(true),
                  ),
                  const SizedBox(height: 12),
                  _TimeTile(
                    icon: Icons.flag_circle_rounded,
                    color: theme.colorScheme.secondary,
                    label: s.t('end_time_label'),
                    value: _end == null
                        ? s.t('pick_end')
                        : DateFormat('dd.MM.yyyy  HH:mm').format(_end!),
                    onTap: () => _pickDate(false),
                  ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _submit(s),
            icon: const Icon(Icons.add_road_rounded),
            label: Text(s.t('save')),
          ),
        ],
      ),
    );
  }
}

class _TopChip extends StatelessWidget {
  const _TopChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _SeatStepper extends StatelessWidget {
  const _SeatStepper({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          IconButton.filledTonal(
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 34,
            child: Center(
              child: Text(
                '$value',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
          ),
          IconButton.filled(
            onPressed: value < 8 ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: color.withValues(alpha: 0.08),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withValues(alpha: 0.16),
              foregroundColor: color,
              child: Icon(icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
