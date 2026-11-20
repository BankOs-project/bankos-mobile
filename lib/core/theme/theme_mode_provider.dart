import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final themeModeProvider = AsyncNotifierProvider<ThemePreference, ThemeMode>(
  ThemePreference.new,
);

class ThemePreference extends AsyncNotifier<ThemeMode> {
  static const _storage = FlutterSecureStorage();
  static const _key = 'bankos.appearance.v1';
  bool _writing = false;

  @override
  Future<ThemeMode> build() async {
    try {
      return await _storage.read(key: _key) == ThemeMode.light.name
          ? ThemeMode.light
          : ThemeMode.dark;
    } catch (_) {
      return ThemeMode.dark;
    }
  }

  Future<void> select(ThemeMode mode) async {
    if (_writing || state.isLoading || state.value == mode) return;
    _writing = true;
    try {
      await _storage.write(key: _key, value: mode.name);
      if (ref.mounted) state = AsyncData(mode);
    } finally {
      _writing = false;
    }
  }
}
