import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_tracker/core/constants/currency.dart';

/// Official National Bank of Ukraine rates. Each value is UAH per 1 unit of currency.
class ExchangeRates {
  const ExchangeRates({this.date, this.toUah = const {}});

  static const empty = ExchangeRates();

  /// Publication date from the NBU response, `dd.MM.yyyy`.
  final String? date;
  final Map<String, double> toUah;

  bool get isEmpty => toUah.isEmpty;

  /// Converts [amount] in [currency] to the base currency.
  /// Without a known rate the amount is returned unchanged.
  double toBase(double amount, String currency) {
    if (currency == Currencies.base) return amount;
    final rate = toUah[currency];
    return rate == null ? amount : amount * rate;
  }

  /// Converts [amount] between two currencies through the base currency.
  /// Returns `null` if a rate for either currency is unknown.
  double? convert(double amount, {required String from, required String to}) {
    if (from == to) return amount;
    final fromRate = from == Currencies.base ? 1.0 : toUah[from];
    final toRate = to == Currencies.base ? 1.0 : toUah[to];
    if (fromRate == null || toRate == null) return null;
    return amount * fromRate / toRate;
  }

  factory ExchangeRates.fromNbuJson(List<dynamic> items) {
    final rates = <String, double>{};
    String? date;
    for (final item in items) {
      final map = item as Map<String, dynamic>;
      final code = map['cc'] as String;
      if (code == Currencies.usd || code == Currencies.eur) {
        rates[code] = (map['rate'] as num).toDouble();
        date ??= map['exchangedate'] as String?;
      }
    }
    return ExchangeRates(date: date, toUah: rates);
  }
}

class ExchangeRateService {
  ExchangeRateService(this._prefs);

  final SharedPreferences _prefs;

  static final _endpoint = Uri.parse(
    'https://bank.gov.ua/NBUStatService/v1/statdirectory/exchange?json',
  );
  static const _cacheKey = 'exchange_rates_nbu';

  /// Last successfully fetched rates, or `null` if none were stored yet.
  ExchangeRates? readCache() {
    final raw = _prefs.getString(_cacheKey);
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final rates = (map['rates'] as Map<String, dynamic>).map(
      (code, value) => MapEntry(code, (value as num).toDouble()),
    );
    return ExchangeRates(date: map['date'] as String?, toUah: rates);
  }

  /// Downloads the current NBU rates and stores them for offline use.
  Future<ExchangeRates> fetch() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(_endpoint);
      final response = await request.close().timeout(const Duration(seconds: 10));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('НБУ відповів статусом ${response.statusCode}', uri: _endpoint);
      }
      final body = await response.transform(utf8.decoder).join();
      final rates = ExchangeRates.fromNbuJson(jsonDecode(body) as List<dynamic>);
      if (rates.isEmpty) {
        throw const FormatException('У відповіді немає курсів USD або EUR');
      }
      await _prefs.setString(
        _cacheKey,
        jsonEncode({'date': rates.date, 'rates': rates.toUah}),
      );
      return rates;
    } finally {
      client.close();
    }
  }
}
