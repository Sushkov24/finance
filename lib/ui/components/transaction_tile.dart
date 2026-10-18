import 'package:flutter/material.dart';

import 'package:finance_tracker/core/constants/palette.dart';
import 'package:finance_tracker/core/theme/app_theme.dart';
import 'package:finance_tracker/core/utils/formatters.dart';
import 'package:finance_tracker/models/models.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.transaction, this.onTap});

  final FinanceTransaction transaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final theme = Theme.of(context);
    final categoryColor = colorFromHex(t.categoryColor);
    final amountColor = t.isIncome ? AppColors.income : AppColors.expense;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: categoryColor.withValues(alpha: 0.15),
        child: Icon(iconFor(t.categoryIcon), color: categoryColor),
      ),
      title: Text(
        t.categoryName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${t.accountName} · ${Fmt.dateTime(t.date)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '${t.isIncome ? '+' : '-'}${Fmt.money(t.amount, currency: t.currency)}',
        style: theme.textTheme.bodyLarge?.copyWith(
          color: amountColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
