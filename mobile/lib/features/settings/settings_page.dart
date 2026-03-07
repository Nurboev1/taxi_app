import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taxi_mobile/core/api/api_error.dart';
import 'package:taxi_mobile/core/api/endpoints.dart';
import 'package:taxi_mobile/core/formatters/uz_plate_formatter.dart';
import 'package:taxi_mobile/core/i18n/strings.dart';
import 'package:taxi_mobile/core/widgets/neo_sections.dart';
import 'package:taxi_mobile/core/widgets/neo_shell.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_controller.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late TextEditingController _firstName;
  late TextEditingController _lastName;
  late TextEditingController _carModel;
  late TextEditingController _carNumber;
  late String _gender;
  late String _language;
  bool _phoneVisible = true;

  Future<void> _openLegalDoc(String path) async {
    final uri = Uri.parse('${Endpoints.baseUrl}$path');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<Map<String, String>?> _askDriverCarInfo(AppStrings s) async {
    final modelCtrl = TextEditingController(text: _carModel.text.trim());
    final numberCtrl =
        TextEditingController(text: normalizeUzPlate(_carNumber.text));
    final formKey = GlobalKey<FormState>();

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Haydovchi ma'lumotlari",
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextFormField(
                  controller: modelCtrl,
                  decoration: InputDecoration(labelText: s.t('car_model')),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Majburiy maydon'
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: numberCtrl,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: const <TextInputFormatter>[
                    UzPlateTextInputFormatter()
                  ],
                  decoration: InputDecoration(
                    labelText: s.t('car_number'),
                    hintText: '01 A123BC',
                  ),
                  validator: (v) {
                    final val = (v ?? '').trim();
                    if (val.isEmpty) return 'Majburiy maydon';
                    if (!isValidUzPlate(val)) {
                      return "Format xato. Masalan: 01 A123BC";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      Navigator.pop(ctx, {
                        'car_model': modelCtrl.text.trim(),
                        'car_number': normalizeUzPlate(numberCtrl.text),
                      });
                    },
                    child: Text(s.t('save')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    modelCtrl.dispose();
    numberCtrl.dispose();
    return result;
  }

  Future<bool> _confirmRoleSwitch(AppStrings s, String nextRole) async {
    final roleName = nextRole == 'driver' ? s.t('driver') : s.t('passenger');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tasdiqlash'),
        content: Text('Rolni "$roleName" ga almashtirishni tasdiqlaysizmi?'),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Yo'q")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ha')),
        ],
      ),
    );
    return ok == true;
  }

  bool _validateCarPlateIfNeeded(bool isDriver) {
    if (!isDriver) return true;
    final val = normalizeUzPlate(_carNumber.text);
    if (val.isNotEmpty && !isValidUzPlate(val)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Mashina raqami formati xato. Masalan: 01 A123BC")),
      );
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    final p = ref.read(authControllerProvider).profile ?? {};
    _firstName =
        TextEditingController(text: (p['first_name'] ?? '').toString());
    _lastName = TextEditingController(text: (p['last_name'] ?? '').toString());
    _carModel = TextEditingController(text: (p['car_model'] ?? '').toString());
    _carNumber = TextEditingController(
        text: normalizeUzPlate((p['car_number'] ?? '').toString()));
    _gender = (p['gender'] ?? 'male').toString();
    _language = (p['language'] ?? 'uz').toString();
    _phoneVisible = (p['phone_visible'] ?? true) == true;
  }

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
    final role = ref.watch(authControllerProvider).role ?? 'passenger';
    final isDriver = role == 'driver';
    final s = AppStrings.of(_language);

    return NeoScaffold(
      title: s.t('settings'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          NeoHeroCard(
            title: s.t('settings'),
            subtitle: s.t('settings_manage_subtitle'),
            icon: Icons.tune_rounded,
            badges: [
              NeoBadge(
                icon: isDriver
                    ? Icons.local_taxi_outlined
                    : Icons.person_outline_rounded,
                label: isDriver ? s.t('driver') : s.t('passenger'),
              ),
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
                  const NeoSectionHeader(
                    title: 'Basic Info',
                    subtitle: 'Identity, language and visibility settings',
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
                  SwitchListTile(
                    value: _phoneVisible,
                    onChanged: (v) => setState(() => _phoneVisible = v),
                    title: Text(s.t('show_phone')),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (!_validateCarPlateIfNeeded(isDriver)) return;
                        final normalizedCarNumber =
                            normalizeUzPlate(_carNumber.text);
                        await ref
                            .read(authControllerProvider.notifier)
                            .updateProfile({
                          'first_name': _capWords(_firstName.text),
                          'last_name': _capWords(_lastName.text),
                          'car_model':
                              isDriver && _carModel.text.trim().isNotEmpty
                                  ? _carModel.text.trim()
                                  : null,
                          'car_number':
                              isDriver && normalizedCarNumber.isNotEmpty
                                  ? normalizedCarNumber
                                  : null,
                          'gender': _gender,
                          'language': _language,
                          'phone_visible': _phoneVisible,
                        });
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(s.t('settings_saved'))),
                        );
                      },
                      child: Text(s.t('save')),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const NeoSectionHeader(
                    title: 'Role & Documents',
                    subtitle: 'Switch mode or open legal documents',
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        final nextRole =
                            role == 'driver' ? 'passenger' : 'driver';
                        if (nextRole == 'driver' &&
                            (_carModel.text.trim().isEmpty ||
                                _carNumber.text.trim().isEmpty)) {
                          final filled = await _askDriverCarInfo(s);
                          if (filled == null) return;
                          _carModel.text = filled['car_model'] ?? '';
                          _carNumber.text = filled['car_number'] ?? '';
                          await ref
                              .read(authControllerProvider.notifier)
                              .updateProfile({
                            'car_model': _carModel.text.trim(),
                            'car_number': _carNumber.text.trim(),
                          });
                        }

                        if (!_validateCarPlateIfNeeded(nextRole == 'driver')) {
                          return;
                        }
                        final hasCarInfo = _carModel.text.trim().isNotEmpty ||
                            _carNumber.text.trim().isNotEmpty;
                        if (hasCarInfo) {
                          final ok = await _confirmRoleSwitch(s, nextRole);
                          if (!ok) return;
                        }
                        try {
                          await ref
                              .read(authControllerProvider.notifier)
                              .setRole(nextRole);
                        } catch (e) {
                          if (!context.mounted) return;
                          if (apiErrorCode(e) == 'DRIVER_BLOCKED') {
                            context.go('/driver-blocked');
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(apiErrorMessage(
                                e,
                                fallback: s.t('generic_error'),
                              )),
                            ),
                          );
                          return;
                        }
                        if (!context.mounted) return;
                        context.go(
                          nextRole == 'driver' ? '/driver' : '/passenger',
                        );
                      },
                      child: Text(
                        role == 'driver'
                            ? s.t('switch_to_passenger')
                            : s.t('switch_to_driver'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: Text(s.t('privacy_policy')),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => _openLegalDoc('/legal/privacy'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.gavel_outlined),
                    title: Text(s.t('terms_of_use')),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => _openLegalDoc('/legal/terms'),
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
