import 'package:flutter/material.dart';
import 'package:taxi_mobile/core/i18n/strings.dart';
import 'package:taxi_mobile/core/location/uz_locations.dart';

class LocationValue {
  const LocationValue({required this.region, required this.district});

  final String? region;
  final String? district;

  String? asLabel() {
    if (region == null || district == null) return null;
    return '$region, $district';
  }
}

class LocationSelector extends StatelessWidget {
  const LocationSelector({
    super.key,
    required this.title,
    required this.value,
    required this.onRegionChanged,
    required this.onDistrictChanged,
    required this.strings,
  });

  final String title;
  final LocationValue value;
  final ValueChanged<String?> onRegionChanged;
  final ValueChanged<String?> onDistrictChanged;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final regions = uzbekistanLocations.keys.toList()..sort();
    final districts = value.region == null
        ? <String>[]
        : (uzbekistanLocations[value.region] ?? <String>[]);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              key: ValueKey<String?>('region-${value.region}'),
              initialValue: value.region,
              decoration: InputDecoration(labelText: strings.t('province')),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(strings.t('select_province')),
                ),
                ...regions.map(
                    (r) => DropdownMenuItem<String?>(value: r, child: Text(r))),
              ],
              onChanged: onRegionChanged,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              key: ValueKey<String?>(
                  'district-${value.region}-${value.district}'),
              initialValue: value.district,
              decoration: InputDecoration(labelText: strings.t('district')),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(strings.t('select_district')),
                ),
                ...districts.map(
                    (d) => DropdownMenuItem<String?>(value: d, child: Text(d))),
              ],
              onChanged: value.region == null ? null : onDistrictChanged,
            ),
          ],
        ),
      ),
    );
  }
}
