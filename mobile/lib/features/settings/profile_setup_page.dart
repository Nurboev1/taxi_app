import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taxi_mobile/core/formatters/uz_plate_formatter.dart';
import 'package:taxi_mobile/core/i18n/strings.dart';
import 'package:taxi_mobile/core/widgets/neo_sections.dart';
import 'package:taxi_mobile/core/widgets/neo_shell.dart';

import '../auth/auth_controller.dart';

class ProfileSetupPage extends ConsumerStatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  ConsumerState<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends ConsumerState<ProfileSetupPage> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _carModel = TextEditingController();
  final _carNumber = TextEditingController();
  String _gender = 'male';
  String _language = 'uz';

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _carModel.dispose();
    _carNumber.dispose();
    super.dispose();
  }

  String _capWords(String value) {
    final parts =
        value.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    return parts
        .map((p) => p.length == 1
            ? p.toUpperCase()
            : '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authControllerProvider).role;
    final isDriver = role == 'driver';
    final s = AppStrings.of(_language);

    return NeoScaffold(
      title: s.t('profile_setup'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          NeoHeroCard(
            title: s.t('profile_setup'),
            subtitle: isDriver
                ? s.t('profile_setup_driver_subtitle')
                : s.t('profile_setup_passenger_subtitle'),
            icon: isDriver ? Icons.local_taxi_rounded : Icons.person_rounded,
            badges: [
              NeoBadge(
                icon: Icons.language_rounded,
                label: _language,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NeoSectionHeader(
                    title: s.t('finish_setup_title'),
                    subtitle: s.t('finish_setup_subtitle'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _firstName,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: s.t('first_name')),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _lastName,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: s.t('last_name')),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _gender,
                    decoration: InputDecoration(labelText: s.t('gender')),
                    items: [
                      DropdownMenuItem(value: 'male', child: Text(s.t('male'))),
                      DropdownMenuItem(
                          value: 'female', child: Text(s.t('female'))),
                    ],
                    onChanged: (v) => setState(() => _gender = v ?? 'male'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _language,
                    decoration: InputDecoration(labelText: s.t('language')),
                    items: const [
                      DropdownMenuItem(value: 'uz', child: Text('Uzbek')),
                      DropdownMenuItem(value: 'ru', child: Text('Russkiy')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (v) => setState(() => _language = v ?? 'uz'),
                  ),
                  if (isDriver) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _carModel,
                      decoration: InputDecoration(labelText: s.t('car_model')),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _carNumber,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: const <TextInputFormatter>[
                        UzPlateTextInputFormatter()
                      ],
                      decoration: InputDecoration(
                        labelText: s.t('car_number'),
                        hintText: '01 A123BC',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final normalizedCarNumber =
                            normalizeUzPlate(_carNumber.text);
                        if (isDriver &&
                            normalizedCarNumber.isNotEmpty &&
                            !isValidUzPlate(normalizedCarNumber)) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(s.t('plate_format_error'))),
                          );
                          return;
                        }

                        await ref
                            .read(authControllerProvider.notifier)
                            .updateProfile({
                          'first_name': _capWords(_firstName.text),
                          'last_name': _capWords(_lastName.text),
                          'gender': _gender,
                          'language': _language,
                          'car_model':
                              isDriver && _carModel.text.trim().isNotEmpty
                                  ? _carModel.text.trim()
                                  : null,
                          'car_number':
                              isDriver && normalizedCarNumber.isNotEmpty
                                  ? normalizedCarNumber
                                  : null,
                        });
                        if (!context.mounted) return;
                        context.go(role == 'driver' ? '/driver' : '/passenger');
                      },
                      child: Text(s.t('save')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
