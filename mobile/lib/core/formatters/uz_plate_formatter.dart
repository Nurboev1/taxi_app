import 'package:flutter/services.dart';

class UzPlateTextInputFormatter extends TextInputFormatter {
  const UzPlateTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw =
        newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (raw.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final mode2 = raw.length >= 3 && RegExp(r'\d').hasMatch(raw[2]);
    final pattern = mode2 ? _mode2 : _mode1;
    final accepted = StringBuffer();
    var pos = 0;

    for (final ch in raw.split('')) {
      if (pos >= pattern.length) break;
      if (_matches(ch, pattern[pos])) {
        accepted.write(ch);
        pos++;
      }
    }

    final compact = accepted.toString();
    final text = compact.length <= 2
        ? compact
        : '${compact.substring(0, 2)} ${compact.substring(2)}';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  static bool _matches(String ch, String expected) {
    if (expected == 'D') return RegExp(r'\d').hasMatch(ch);
    return RegExp(r'[A-Z]').hasMatch(ch);
  }

  static const List<String> _mode1 = [
    'D',
    'D',
    'L',
    'D',
    'D',
    'D',
    'L',
    'L'
  ]; // 01 A123BC
  static const List<String> _mode2 = [
    'D',
    'D',
    'D',
    'D',
    'D',
    'L',
    'L',
    'L'
  ]; // 01 123ABC
}

String normalizeUzPlate(String input) {
  final formatted = const UzPlateTextInputFormatter().formatEditUpdate(
    const TextEditingValue(text: ''),
    TextEditingValue(text: input),
  );
  return formatted.text;
}

bool isValidUzPlate(String input) {
  final normalized = normalizeUzPlate(input);
  final compact = normalized.replaceAll(' ', '');
  if (compact.length != 8) return false;

  final region = int.tryParse(compact.substring(0, 2));
  if (region == null || region < 1 || region > 99) return false;

  final mode1 = RegExp(r'^\d{2}[A-Z]\d{3}[A-Z]{2}$');
  final mode2 = RegExp(r'^\d{5}[A-Z]{3}$');
  return mode1.hasMatch(compact) || mode2.hasMatch(compact);
}
