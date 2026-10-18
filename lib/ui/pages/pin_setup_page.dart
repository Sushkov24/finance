import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/theme/app_theme.dart';
import 'package:finance_tracker/logic/security_view_model.dart';
import 'package:finance_tracker/ui/components/pin_pad.dart';

/// Two-step PIN creation: enter, then repeat. Pops with `true` on success.
class PinSetupPage extends StatefulWidget {
  const PinSetupPage({super.key});

  @override
  State<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<PinSetupPage> {
  String? _first;
  String? _error;

  Future<void> _onPin(String pin) async {
    if (_first == null) {
      setState(() {
        _first = pin;
        _error = null;
      });
      return;
    }
    if (pin != _first) {
      setState(() {
        _first = null;
        _error = 'PIN-коди не співпадають. Спробуйте ще раз';
      });
      return;
    }
    await context.read<SecurityViewModel>().setPin(pin);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('PIN-код')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _first == null ? 'Придумайте 4-значний PIN-код' : 'Повторіть PIN-код',
                  style: theme.textTheme.titleMedium,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
