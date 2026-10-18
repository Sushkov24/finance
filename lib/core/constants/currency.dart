/// Supported account currencies. [base] is the currency used for all totals.
abstract final class Currencies {
  static const uah = 'UAH';
  static const usd = 'USD';
  static const eur = 'EUR';

  static const base = uah;
  static const all = [uah, usd, eur];

  static String symbol(String code) => switch (code) {
        usd => r'$',
        eur => '€',
        _ => '₴',
      };

  static String label(String code) => switch (code) {
        usd => 'Долар США (USD)',
        eur => 'Євро (EUR)',
        _ => 'Гривня (UAH)',
      };
}
