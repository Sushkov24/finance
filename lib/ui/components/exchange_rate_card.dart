import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/constants/currency.dart';
import 'package:finance_tracker/core/utils/formatters.dart';
import 'package:finance_tracker/logic/exchange_rate_view_model.dart';

/// Shows the current NBU rates for USD and EUR. Tap to refresh.
class ExchangeRateCard extends StatelessWidget {
  const ExchangeRateCard({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ExchangeRateViewModel>();
    final rates = vm.rates;
    final theme = Theme.of(context);

    final title = rates.isEmpty
        ? 'Курс недоступний'
        : [Currencies.usd, Currencies.eur]
            .map((code) => _pair(code, rates.toUah[code]))
            .join('    ');

    final subtitle = vm.error ??
        (rates.date != null ? 'НБУ, на ${rates.date}' : 'Натисніть, щоб оновити курс');

    return Card(
      child: ListTile(
        leading: const Icon(Icons.currency_exchange_rounded),
        title: Text(title, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: vm.isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh_rounded),
        onTap: vm.isLoading ? null : () => vm.refresh(),
      ),
    );
  }

  static String _pair(String code, double? rate) {
    final value = rate == null ? '—' : '${Fmt.rate(rate)} ₴';
    return '${Currencies.symbol(code)} 1 = $value';
  }
}
