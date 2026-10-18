import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/constants/palette.dart';
import 'package:finance_tracker/core/theme/app_theme.dart';
import 'package:finance_tracker/core/utils/formatters.dart';
import 'package:finance_tracker/logic/exchange_rate_view_model.dart';
import 'package:finance_tracker/models/models.dart';

/// Shows details of [transaction]. [onEdit] is called when the user chooses to edit it.
Future<void> showTransactionDetails(
  BuildContext context,
  FinanceTransaction transaction, {
  required VoidCallback onEdit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => _TransactionDetails(
      transaction: transaction,
      onEdit: () {
        Navigator.pop(sheetContext);
        onEdit();
      },
    ),
  );
}

class _TransactionDetails extends StatelessWidget {
  const _TransactionDetails({required this.transaction, required this.onEdit});

  final FinanceTransaction transaction;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final theme = Theme.of(context);
    final rates = context.watch<ExchangeRateViewModel>().rates;
    final color = t.isIncome ? AppColors.income : AppColors.expense;
    final categoryColor = colorFromHex(t.categoryColor);
    final isForeign = t.currency != t.accountCurrency;

    final operationRate = t.amount == 0 ? null : t.accountAmount / t.amount;
    final currentRate = rates.convert(1, from: t.currency, to: t.accountCurrency);
    final currentValue = rates.convert(t.amount, from: t.currency, to: t.accountCurrency);

    final rows = <_DetailRow>[
      _DetailRow('Рахунок', t.accountName),
      _DetailRow('Дата і час', Fmt.dateTime(t.date)),
      if (isForeign) ...[
        _DetailRow('Сума у валюті рахунку', Fmt.money(t.accountAmount, currency: t.accountCurrency)),
        if (operationRate != null)
          _DetailRow(
            'Курс на момент операції',
            '1 ${t.currency} = ${Fmt.rate(operationRate)} ${t.accountCurrency}',
          ),
        _DetailRow(
          'Поточний курс НБУ',
          currentRate == null
              ? 'Немає курсу'
              : '1 ${t.currency} = ${Fmt.rate(currentRate)} ${t.accountCurrency}',
        ),
        if (currentValue != null)
          _DetailRow(
            'Сума за поточним курсом',
            Fmt.money(currentValue, currency: t.accountCurrency),
          ),
        if (rates.date != null) _DetailRow('Дата курсу НБУ', rates.date!),
      ],
      if (t.note != null && t.note!.isNotEmpty) _DetailRow('Примітка', t.note!),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: categoryColor.withValues(alpha: 0.15),
                child: Icon(iconFor(t.categoryIcon), color: categoryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.categoryName,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      t.isIncome ? 'Дохід' : 'Витрата',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '${t.isIncome ? '+' : '-'}${Fmt.money(t.amount, currency: t.currency)}',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          for (final row in rows) row.build(context),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Редагувати'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
