import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_tracker/app.dart';
import 'package:finance_tracker/logic/app_settings_view_model.dart';
import 'package:finance_tracker/logic/exchange_rate_view_model.dart';
import 'package:finance_tracker/logic/finance_view_model.dart';
import 'package:finance_tracker/logic/security_view_model.dart';
import 'package:finance_tracker/services/database_helper.dart';
import 'package:finance_tracker/services/exchange_rate_service.dart';
import 'package:finance_tracker/services/finance_repository.dart';
import 'package:finance_tracker/services/security_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('uk');

  final prefs = await SharedPreferences.getInstance();
  final security = SecurityViewModel(SecurityService());
  await security.init();

  final finance = FinanceViewModel(SqliteFinanceRepository(DatabaseHelper.instance));
  final exchange = ExchangeRateViewModel(ExchangeRateService(prefs));
  finance.setRates(exchange.rates);
  exchange.addListener(() => finance.setRates(exchange.rates));
  await finance.load();
  unawaited(exchange.refresh());

  final settings = AppSettingsViewModel(prefs);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: security),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: finance),
        ChangeNotifierProvider.value(value: exchange),
      ],
      child: const FinanceApp(),
    ),
  );
}
