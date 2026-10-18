import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/theme/app_theme.dart';
import 'package:finance_tracker/logic/app_settings_view_model.dart';
import 'package:finance_tracker/logic/security_view_model.dart';
import 'package:finance_tracker/ui/components/pin_pad.dart';

class LockPage extends StatefulWidget {
  const LockPage({super.key});

  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometrics());
  }

  Future<void> _tryBiometrics() async {
    if (!context.read<AppSettingsViewModel>().biometricEnabled) return;
    await context.read<SecurityViewModel>().unlockWithBiometrics();
  }

  Future<void> _onPin(String pin) async {
    setState(() => _error = null);
    final ok = await context.read<SecurityViewModel>().unlockWithPin(pin);
    if (!ok && mounted) setState(() => _error = 'Невірний PIN-код');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final biometricEnabled = context.watch<AppSettingsViewModel>().biometricEnabled;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 56, color: scheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Фінанси',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Введіть PIN-код',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 20,
                  child: _error == null
                      ? null
                      : Text(_error!, style: const TextStyle(color: AppColors.expense)),
                ),
                const SizedBox(height: 24),
                PinPad(onCompleted: _onPin),
                const SizedBox(height: 16),
                if (biometricEnabled)
                  TextButton.icon(
                    onPressed: _tryBiometrics,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Використати біометрію'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
