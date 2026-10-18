import 'package:intl/intl.dart';

import 'package:finance_tracker/core/constants/currency.dart';

abstract final class Fmt {
  static final _amount = NumberFormat('#,##0.00', 'uk');
  static final _dateTime = DateFormat('d MMM yyyy, HH:mm', 'uk');
  static final _day = DateFormat('d MMMM yyyy', 'uk');
  static final _dayShort = DateFormat('d MMM', 'uk');
  static final _monthYear = DateFormat('LLLL yyyy', 'uk');

  static String money(double value, {String currency = Currencies.base}) {
    final sign = value < 0 ? '-' : '';
    return '$sign${Currencies.symbol(currency)} ${_amount.format(value.abs())}';
  }

  static String rate(double value) => _amount.format(value);

  static String dateTime(DateTime value) => _dateTime.format(value);

  static String day(DateTime value) => _day.format(value);

  static String dayShort(DateTime value) => _dayShort.format(value);

  static String monthYear(DateTime value) => _monthYear.format(value);

  static String percent(double ratio) => '${(ratio * 100).round()}%';
}
