import 'package:flutter/foundation.dart';

import 'package:finance_tracker/services/security_service.dart';

/// Tracks whether the app is locked and handles PIN and biometric unlock.
class SecurityViewModel extends ChangeNotifier {
  SecurityViewModel(this._service);

  final SecurityService _service;

  bool _hasPin = false;
  bool _locked = false;

  bool get hasPin => _hasPin;
  bool get isLocked => _locked;

  Future<void> init() async {
    _hasPin = await _service.hasPin();
    _locked = _hasPin;
    notifyListeners();
  }

  void lockIfNeeded() {
    if (_hasPin && !_locked) {
      _locked = true;
      notifyListeners();
    }
  }

  Future<bool> unlockWithPin(String pin) async {
    final ok = await _service.verifyPin(pin);
    if (ok) {
      _locked = false;
      notifyListeners();
    }
    return ok;
  }

  Future<bool> unlockWithBiometrics() async {
    final ok = await _service.authenticateWithBiometrics();
    if (ok) {
      _locked = false;
      notifyListeners();
    }
    return ok;
  }

  Future<bool> canUseBiometrics() => _service.canUseBiometrics();

  Future<void> setPin(String pin) async {
    await _service.setPin(pin);
    _hasPin = true;
    notifyListeners();
  }

  Future<void> disablePin() async {
    await _service.clearPin();
    _hasPin = false;
    _locked = false;
    notifyListeners();
  }
}
