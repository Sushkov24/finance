import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/constants/currency.dart';
import 'package:finance_tracker/logic/app_settings_view_model.dart';
import 'package:finance_tracker/logic/finance_view_model.dart';
import 'package:finance_tracker/logic/security_view_model.dart';
import 'package:finance_tracker/models/models.dart';
import 'package:finance_tracker/services/csv_exporter.dart';
import 'package:finance_tracker/ui/components/common_widgets.dart';
import 'package:finance_tracker/ui/pages/categories_page.dart';
import 'package:finance_tracker/ui/pages/pin_setup_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final Future<bool> _biometricsAvailable =
      context.read<SecurityViewModel>().canUseBiometrics();

  Future<void> _togglePin(bool enable) async {
    final security = context.read<SecurityViewModel>();
    final settings = context.read<AppSettingsViewModel>();

    if (enable) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const PinSetupPage()),
      );
      return;
    }

    final ok = await confirmAction(
      context,
      title: 'Вимкнути PIN-код?',
      message: 'Застосунок більше не буде блокуватися при запуску.',
      confirmLabel: 'Вимкнути',
    );
    if (!ok) return;
    await security.disablePin();
    await settings.setBiometricEnabled(false);
  }

  Future<void> _toggleBiometrics(bool enable) async {
    final security = context.read<SecurityViewModel>();
    final settings = context.read<AppSettingsViewModel>();

    if (enable) {
      final ok = await security.unlockWithBiometrics();
      if (!ok) return;
    }
    await settings.setBiometricEnabled(enable);
  }

  Future<void> _exportCsv() async {
    final messenger = ScaffoldMessenger.of(context);
    final transactions = context.read<FinanceViewModel>().transactions;
    if (transactions.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Немає операцій для експорту')));
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    await CsvExporter.export(transactions, sharePositionOrigin: origin);
  }

  @override
  Widget build(BuildContext context) {
    final security = context.watch<SecurityViewModel>();
    final settings = context.watch<AppSettingsViewModel>();
    final finance = context.watch<FinanceViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Налаштування')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const SectionHeader(title: 'Безпека'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.pin_outlined),
                  title: const Text('PIN-код'),
                  subtitle: const Text('Блокування при запуску та поверненні'),
                  value: security.hasPin,
                  onChanged: _togglePin,
                ),
                if (security.hasPin)
                  FutureBuilder<bool>(
                    future: _biometricsAvailable,
                    builder: (context, snapshot) {
                      if (snapshot.data != true) return const SizedBox.shrink();
                      return SwitchListTile(
                        secondary: const Icon(Icons.fingerprint),
                        title: const Text('Біометрія'),
                        subtitle: const Text('Face ID або відбиток пальця'),
                        value: settings.biometricEnabled,
                        onChanged: _toggleBiometrics,
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Вигляд'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('Системна')),
                  ButtonSegment(value: ThemeMode.light, label: Text('Світла')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Темна')),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (s) => settings.setThemeMode(s.first),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Дані'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: const Text('Категорії'),
                  subtitle: Text('${finance.categories.length} категорій'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CategoriesPage()),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: const Text('Рахунки'),
                  subtitle: Text('${finance.accounts.length} рахунків · натисніть, щоб додати'),
                  trailing: const Icon(Icons.add_rounded),
                  onTap: () => showAccountDialog(context),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: const Text('Експорт у CSV'),
                  subtitle: const Text('Надіслати файл з усіма операціями'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _exportCsv,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Про застосунок'),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Фінанси'),
              subtitle: Text('Версія 1.0.0'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Adds a new account with an optional starting balance.
Future<void> showAccountDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _AccountDialog(),
  );
}

class _AccountDialog extends StatefulWidget {
  const _AccountDialog();

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  final _name = TextEditingController();
  final _balance = TextEditingController(text: '0');
  String _currency = Currencies.base;

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final balance = double.tryParse(_balance.text.replaceAll(' ', '').replaceAll(',', '.'));
    if (name.isEmpty || balance == null) return;

    await context.read<FinanceViewModel>().addAccount(
          Account(name: name, balance: balance, currency: _currency),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _name.text.trim().isNotEmpty;

    return AlertDialog(
      title: const Text('Новий рахунок'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _currency,
            decoration: const InputDecoration(labelText: 'Валюта'),
            items: [
              for (final code in Currencies.all)
                DropdownMenuItem(value: code, child: Text(Currencies.label(code))),
            ],
            onChanged: (value) => setState(() => _currency = value ?? _currency),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _balance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: InputDecoration(
              labelText: 'Початковий баланс',
              prefixText: '${Currencies.symbol(_currency)} ',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Скасувати'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: canSave ? _save : null,
          child: const Text('Додати'),
        ),
      ],
    );
  }
}
