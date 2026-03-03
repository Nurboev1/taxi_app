import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  final _seatsCtrl = TextEditingController(text: '1');
  DateTime? _preferredTime;
  String? _error;

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
      initialDate: now,
    );
    if (date == null || !mounted) return;
    final time =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    final dt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() => _preferredTime = dt);
  }

  @override
  void dispose() {
    _seatsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang =
        ref.watch(authControllerProvider).profile?['language']?.toString();
    final s = AppStrings.of(lang);

    return Scaffold(
      appBar: AppBar(title: Text(s.t('create_request'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          const SizedBox(height: 8),
          TextField(
              controller: _seatsCtrl,
              decoration: InputDecoration(labelText: s.t('needed_seats'))),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _pickDate,
            child: Text(_preferredTime == null
                ? s.t('select_time')
                : '${s.t('time')}: $_preferredTime'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async {
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

              try {
                final id =
                    await ref.read(passengerActionsProvider).createRequest(
                          from: '$_fromRegion, $_fromDistrict',
                          to: '$_toRegion, $_toDistrict',
                          preferredTime: _preferredTime!,
                          seatsNeeded: int.tryParse(_seatsCtrl.text) ?? 1,
                        );
                if (context.mounted) {
                  context.go('/passenger/request-status?requestId=$id');
                }
              } catch (e) {
                setState(() => _error =
                    apiErrorMessage(e, fallback: s.t('request_create_error')));
              }
            },
            child: Text(s.t('save')),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ]
        ],
      ),
    );
  }
}
