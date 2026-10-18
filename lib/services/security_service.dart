import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// PIN storage (salted SHA-256 in secure storage) and biometric checks.
class SecurityService {
  SecurityService({FlutterSecureStorage? storage, LocalAuthentication? localAuth})
      : _storage = storage ?? const FlutterSecureStorage(),
        _localAuth = localAuth ?? LocalAuthentication();

  static const _hashKey = 'pin_hash';
  static const _saltKey = 'pin_salt';

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  static String hashPin(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  Future<bool> hasPin() async => (await _storage.read(key: _hashKey)) != null;

  Future<void> setPin(String pin) async {
    final salt = _randomSalt();
    await _storage.write(key: _saltKey, value: salt);
    await _storage.write(key: _hashKey, value: hashPin(pin, salt));
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _saltKey);
    final stored = await _storage.read(key: _hashKey);
    if (salt == null || stored == null) return false;
    return _constantTimeEquals(hashPin(pin, salt), stored);
  }

  Future<void> clearPin() async {
    await _storage.delete(key: _hashKey);
    await _storage.delete(key: _saltKey);
  }

  Future<bool> canUseBiometrics() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Підтвердіть особу для входу у застосунок',
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    }
  }

  static String _randomSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
