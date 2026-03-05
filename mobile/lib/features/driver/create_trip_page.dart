import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final _seatsCtrl = TextEditingController(text: '4');
  DateTime? _start;
  DateTime? _end;
  String? _error;

  String? _fromRegion;
  String? _fromDistrict;
  String? _toRegion;
  String? _toDistrict;

  Future<void> _pickDate(bool isStart) async {
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
    setState(() {
      if (isStart) {
        _start = dt;
      } else {
        _end = dt;
      }
    });
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _seatsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang =
        ref.watch(authControllerProvider).profile?['language']?.toString();
    final s = AppStrings.of(lang);

    return Scaffold(
      appBar: AppBar(title: Text(s.t('trip_create'))),
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
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: s.t('seat_price')),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _seatsCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: s.t('seat_count')),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _pickDate(true),
            child: Text(_start == null
                ? s.t('pick_start')
                : '${s.t('start')}: $_start'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _pickDate(false),
            child:
                Text(_end == null ? s.t('pick_end') : '${s.t('end')}: $_end'),
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
              if (_start == null || _end == null) {
                setState(() => _error = s.t('enter_range'));
                return;
              }
              try {
                await ref.read(driverActionsProvider).createTrip(
                      from: '$_fromRegion, $_fromDistrict',
                      to: '$_toRegion, $_toDistrict',
                      start: _start!,
                      end: _end!,
                      seatsTotal: int.tryParse(_seatsCtrl.text) ?? 4,
                      price: _priceCtrl.text.trim(),
                    );
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                setState(() => _error =
                    apiErrorMessage(e, fallback: s.t('trip_create_error')));
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
