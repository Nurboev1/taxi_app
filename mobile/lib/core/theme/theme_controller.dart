import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';

class ThemeController extends StateNotifier<ThemeMode> {
  ThemeController(this.ref) : super(ThemeMode.light) {
    _load();
  }

  final Ref ref;

  Future<void> _load() async {
    final isDark = await ref.read(secureStoreProvider).readDarkMode();
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggle() async {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await ref.read(secureStoreProvider).saveDarkMode(state == ThemeMode.dark);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeController, ThemeMode>(
  (ref) => ThemeController(ref),
);
