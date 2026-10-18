import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode and biometric preference, persisted with SharedPreferences.
class AppSettingsViewModel extends ChangeNotifier {
  AppSettingsViewModel(this._prefs)
      : _themeMode = _themeFromIndex(_prefs.getInt(_themeKey)),
        _biometricEnabled = _prefs.getBool(_biometricKey) ?? false;

  static ThemeMode _themeFromIndex(int? index) {
    if (index == null || index < 0 || index >= ThemeMode.values.length) {
      return ThemeMode.dark;
    }
    return ThemeMode.values[index];
  }

  static const _themeKey = 'theme_mode';
  static const _biometricKey = 'biometric_enabled';

  final SharedPreferences _prefs;

  ThemeMode _themeMode;
  bool _biometricEnabled;

  ThemeMode get themeMode => _themeMode;
  bool get biometricEnabled => _biometricEnabled;

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _prefs.setInt(_themeKey, mode.index);
  }

  Future<void> setBiometricEnabled(bool value) async {
    _biometricEnabled = value;
    notifyListeners();
    await _prefs.setBool(_biometricKey, value);
  }
}
