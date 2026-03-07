import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:taxi_mobile/core/api/api_error.dart';
import 'package:taxi_mobile/core/i18n/strings.dart';
import 'package:taxi_mobile/core/location/location_selector.dart';

import '../auth/auth_controller.dart';
import 'passenger_controller.dart';

class CreateRequestPage extends ConsumerStatefulWidget {
  const CreateRequestPage({super.key});

  @override
  ConsumerState<CreateRequestPage> createState() => _CreateRequestPageState();
}

class _CreateRequestPageState extends ConsumerState<CreateRequestPage> {
  DateTime? _preferredTime;
  String? _error;
  int _seatsNeeded = 1;
  int _maleSeats = 1;
  int _femaleSeats = 0;

  String? _fromRegion;
  String? _fromDistrict;
  String? _toRegion;
  String? _toDistrict;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      initialDate: _preferredTime ?? now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_preferredTime ?? now),
    );
    if (time == null) return;
    setState(() {
      _preferredTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _setTotalSeats(int seats) {
    final normalized = seats.clamp(1, 4);
    setState(() {
      _seatsNeeded = normalized;
      if (_maleSeats + _femaleSeats > _seatsNeeded) {
        final overflow = (_maleSeats + _femaleSeats) - _seatsNeeded;
        if (_femaleSeats >= overflow) {
          _femaleSeats -= overflow;
        } else {
          final remaining = overflow - _femaleSeats;
          _femaleSeats = 0;
          _maleSeats = (_maleSeats - remaining).clamp(0, _seatsNeeded);
        }
      }
      if (_maleSeats + _femaleSeats < _seatsNeeded) {
        _maleSeats = (_maleSeats + (_seatsNeeded - (_maleSeats + _femaleSeats)))
            .clamp(0, _seatsNeeded);
      }
    });
  }

  void _setMaleSeats(int value) {
    final normalized = value.clamp(0, _seatsNeeded);
    setState(() {
      _maleSeats = normalized;
      _femaleSeats = _seatsNeeded - normalized;
    });
  }

  void _setFemaleSeats(int value) {
    final normalized = value.clamp(0, _seatsNeeded);
    setState(() {
      _femaleSeats = normalized;
      _maleSeats = _seatsNeeded - normalized;
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
    if (_preferredTime == null) {
      setState(() => _error = s.t('enter_time'));
      return;
    }
    if (_maleSeats + _femaleSeats != _seatsNeeded) {
      setState(() => _error = s.t('seat_mix_invalid'));
      return;
    }

    try {
      final id = await ref.read(passengerActionsProvider).createRequest(
            from: '$_fromRegion, $_fromDistrict',
            to: '$_toRegion, $_toDistrict',
            preferredTime: _preferredTime!,
            seatsNeeded: _seatsNeeded,
            maleSeats: _maleSeats,
            femaleSeats: _femaleSeats,
          );
      if (!mounted) return;
      if (context.mounted) {
        context.go('/passenger/request-status?requestId=$id');
      }
    } catch (e) {
      setState(
        () => _error = apiErrorMessage(e, fallback: s.t('request_create_error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang =
        ref.watch(authControllerProvider).profile?['language']?.toString();
    final s = AppStrings.of(lang);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final totalSelected = _maleSeats + _femaleSeats;

    return Scaffold(
      appBar: AppBar(title: Text(s.t('create_request'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.20),
                  theme.colorScheme.secondary.withValues(alpha: 0.10),
                  theme.colorScheme.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('create_request'),
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  s.t('request_create_subtitle'),
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
                    _MetricChip(
                      icon: Icons.event_seat_rounded,
                      label: '${s.t('needed_seats')}: $_seatsNeeded',
                    ),
                    _MetricChip(
                      icon: Icons.groups_rounded,
                      label: '${s.t('selected_total')}: $totalSelected/$_seatsNeeded',
                    ),
                    _MetricChip(
                      icon: Icons.schedule_rounded,
                      label: _preferredTime == null
                          ? s.t('select_time')
                          : DateFormat('dd.MM HH:mm').format(_preferredTime!),
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
                    s.t('group_composition'),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.t('request_create_subtitle'),
                    style: textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SeatCounterRow(
                    icon: Icons.event_seat_rounded,
                    color: theme.colorScheme.primary,
                    label: s.t('needed_seats'),
                    value: _seatsNeeded,
                    onChanged: _setTotalSeats,
                    max: 4,
                  ),
                  const SizedBox(height: 12),
                  _SeatCounterRow(
                    icon: Icons.male_rounded,
                    color: Colors.blue.shade600,
                    label: s.t('male_seats'),
                    value: _maleSeats,
                    onChanged: _setMaleSeats,
                    max: _seatsNeeded,
                  ),
                  const SizedBox(height: 12),
                  _SeatCounterRow(
                    icon: Icons.female_rounded,
                    color: Colors.pink.shade400,
                    label: s.t('female_seats'),
                    value: _femaleSeats,
                    onChanged: _setFemaleSeats,
                    max: _seatsNeeded,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: totalSelected == _seatsNeeded
                          ? theme.colorScheme.primary.withValues(alpha: 0.08)
                          : theme.colorScheme.error.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      '${s.t('selected_total')}: $totalSelected / $_seatsNeeded',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: totalSelected == _seatsNeeded
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                      ),
                    ),
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
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _pickDate,
                    child: Ink(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: theme.colorScheme.secondary.withValues(alpha: 0.08),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.schedule_rounded,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.t('departure_time'),
                                  style: textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _preferredTime == null
                                      ? s.t('select_time')
                                      : DateFormat('dd.MM.yyyy  HH:mm')
                                          .format(_preferredTime!),
                                  style: textTheme.titleMedium?.copyWith(
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
            icon: const Icon(Icons.rocket_launch_rounded),
            label: Text(s.t('save')),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
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

class _SeatCounterRow extends StatelessWidget {
  const _SeatCounterRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.max,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final canDecrease = value > 0;
    final canIncrease = value < max;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.16),
            foregroundColor: color,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          IconButton.filledTonal(
            onPressed: canDecrease ? () => onChanged(value - 1) : null,
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
            onPressed: canIncrease ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}
