import 'package:flutter/material.dart';

/// Numeric keypad for PIN entry. Calls [onCompleted] with the PIN once [length] digits are entered.
class PinPad extends StatefulWidget {
  const PinPad({super.key, required this.onCompleted, this.length = 4});

  final ValueChanged<String> onCompleted;
  final int length;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';

  Future<void> _press(String digit) async {
    if (_pin.length >= widget.length) return;
    setState(() => _pin += digit);
    if (_pin.length == widget.length) {
      widget.onCompleted(_pin);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted) setState(() => _pin = '');
    }
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Widget _key(String label) {
    if (label.isEmpty) return const SizedBox(width: 76, height: 76);
    final isBackspace = label == '⌫';
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () {
        if (isBackspace) {
          _backspace();
        } else {
          _press(label);
        }
      },
      child: SizedBox(
        width: 76,
        height: 76,
        child: Center(
          child: isBackspace
              ? const Icon(Icons.backspace_outlined)
              : Text(
                  label,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length ? scheme.primary : scheme.outlineVariant,
                ),
              ),
          ],
        ),
        const SizedBox(height: 36),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', '⌫'],
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [for (final key in row) _key(key)],
            ),
          ),
      ],
    );
  }
}
