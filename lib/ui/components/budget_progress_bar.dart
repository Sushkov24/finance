import 'package:flutter/material.dart';

import 'package:finance_tracker/core/constants/palette.dart';
import 'package:finance_tracker/core/theme/app_theme.dart';
import 'package:finance_tracker/core/utils/formatters.dart';
import 'package:finance_tracker/logic/budget_validator.dart';

/// Category progress bar with colour levels: green (ok), amber (80%), red (100%).
class BudgetProgressBar extends StatelessWidget {
  const BudgetProgressBar({super.key, required this.status, this.onTap});

  final BudgetStatus status;
  final VoidCallback? onTap;

  Color get _levelColor => switch (status.level) {
        BudgetLevel.ok => AppColors.income,
        BudgetLevel.warning => AppColors.warning,
        BudgetLevel.exceeded => AppColors.expense,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final budget = status.budget;
    final remaining = status.remaining;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Column(
          children: [
            Row(
              children: [
                Icon(iconFor(budget.categoryIcon), size: 20, color: colorFromHex(budget.categoryColor)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    budget.categoryName,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${Fmt.money(status.spent)} / ${Fmt.money(budget.limitAmount)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: status.ratio.clamp(0.0, 1.0).toDouble(),
                minHeight: 8,
                color: _levelColor,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  Fmt.percent(status.ratio),
                  style: theme.textTheme.bodySmall?.copyWith(color: _levelColor, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  remaining >= 0
                      ? 'Залишок ${Fmt.money(remaining)}'
                      : 'Перевищення ${Fmt.money(-remaining)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
