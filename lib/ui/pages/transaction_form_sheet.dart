import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/constants/currency.dart';
import 'package:finance_tracker/core/constants/palette.dart';
import 'package:finance_tracker/core/theme/app_theme.dart';
import 'package:finance_tracker/core/utils/formatters.dart';
import 'package:finance_tracker/logic/exchange_rate_view_model.dart';
import 'package:finance_tracker/logic/finance_view_model.dart';
import 'package:finance_tracker/models/models.dart';

/// Opens the add/edit form. Shows a SnackBar if the save crossed a budget threshold.
Future<void> showTransactionForm(BuildContext context, {FinanceTransaction? existing}) async {
  final warning = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _TransactionForm(existing: existing),
  );
  if (warning != null && warning.isNotEmpty && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(warning),
        backgroundColor: AppColors.warning,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

class _TransactionForm extends StatefulWidget {
  const _TransactionForm({this.existing});

  final FinanceTransaction? existing;

  @override
  State<_TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<_TransactionForm> {
  late String _type;
  late int? _categoryId;
  late int? _accountId;
  String? _currency;
  late DateTime _date;
  late TimeOfDay _time;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final now = DateTime.now();
    _type = (e?.isIncome ?? false) ? 'INCOME' : 'EXPENSE';
    _categoryId = e?.categoryId;
    _accountId = e?.accountId;
    _currency = e?.currency;
    _date = DateTime(e?.date.year ?? now.year, e?.date.month ?? now.month, e?.date.day ?? now.day);
    _time = TimeOfDay.fromDateTime(e?.date ?? now);
    _amount = TextEditingController(
      text: e == null ? '' : e.amount.toStringAsFixed(2).replaceAll('.', ','),
    );
    _note = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  double? get _parsedAmount =>
      double.tryParse(_amount.text.replaceAll(' ', '').replaceAll(',', '.'));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('uk'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save(int categoryId, int accountId, String accountCurrency) async {
    final amount = _parsedAmount;
    if (amount == null || amount <= 0) return;
    final currency = _currency ?? accountCurrency;
    final accountAmount = context
        .read<ExchangeRateViewModel>()
        .rates
        .convert(amount, from: currency, to: accountCurrency);
    if (accountAmount == null) return;

    setState(() => _saving = true);
    final vm = context.read<FinanceViewModel>();
    final note = _note.text.trim();
    final warning = await vm.saveTransaction(
      FinanceTransaction(
        id: widget.existing?.id,
        accountId: accountId,
        categoryId: categoryId,
        amount: amount,
        currency: currency,
        accountAmount: accountAmount,
        date: DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute),
        note: note.isEmpty ? null : note,
      ),
    );
    if (mounted) Navigator.pop(context, warning ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FinanceViewModel>();
    final isEdit = widget.existing != null;

    final categories = vm.categories.where((c) => c.type == _type).toList();
    final categoryId = categories.any((c) => c.id == _categoryId) ? _categoryId : null;
    final accounts = vm.accounts;
    final accountId = accounts.any((a) => a.id == _accountId)
        ? _accountId
        : (accounts.isEmpty ? null : accounts[0].id);
    final selectedAccount = accounts.where((a) => a.id == accountId);
    final accountCurrency = selectedAccount.isEmpty ? Currencies.base : selectedAccount.first.currency;
    final currency = _currency ?? accountCurrency;
    final rates = context.watch<ExchangeRateViewModel>().rates;

    final amount = _parsedAmount;
    final hint = amount == null || amount <= 0
        ? 'Введіть суму більше нуля'
        : categoryId == null
            ? 'Оберіть категорію'
            : accountId == null
                ? 'Оберіть рахунок'
                : rates.convert(amount, from: currency, to: accountCurrency) == null
                    ? 'Немає курсу для $currency. Спробуйте оновити курси'
                    : null;
    final canSave = hint == null && !_saving;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEdit ? 'Редагування операції' : 'Нова операція',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'EXPENSE',
                  label: Text('Витрата'),
                  icon: Icon(Icons.arrow_upward_rounded),
                ),
                ButtonSegment(
                  value: 'INCOME',
                  label: Text('Дохід'),
                  icon: Icon(Icons.arrow_downward_rounded),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                if (!vm.categories.any((c) => c.id == _categoryId && c.type == _type)) {
                  _categoryId = null;
                }
              }),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: [
                for (final code in Currencies.all)
                  ButtonSegment(value: code, label: Text(code)),
              ],
              selected: {currency},
              onSelectionChanged: (s) => setState(() => _currency = s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              autofocus: !isEdit,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: 'Сума',
                prefixText: '${Currencies.symbol(currency)} ',
              ),
            ),
            const SizedBox(height: 12),
            Text('Категорія', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in categories)
                  ChoiceChip(
                    avatar: Icon(iconFor(c.icon), size: 18, color: colorFromHex(c.color)),
                    label: Text(c.name),
                    selected: categoryId == c.id,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _categoryId = c.id),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: accountId,
              decoration: const InputDecoration(labelText: 'Рахунок'),
              items: [
                for (final a in accounts)
                  DropdownMenuItem<int>(value: a.id!, child: Text(a.name)),
              ],
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(Fmt.day(_date)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(_time.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Примітка (необов’язково)'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: canSave ? () => _save(categoryId!, accountId!, accountCurrency) : null,
              child: Text(isEdit ? 'Зберегти зміни' : 'Додати операцію'),
            ),
            if (hint != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
