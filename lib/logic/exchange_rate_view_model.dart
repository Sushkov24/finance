import 'package:flutter/foundation.dart';

import 'package:finance_tracker/services/exchange_rate_service.dart';

/// Holds the current NBU rates and the refresh state.
class ExchangeRateViewModel extends ChangeNotifier {
  ExchangeRateViewModel(this._service)
      : _rates = _service.readCache() ?? ExchangeRates.empty;

  final ExchangeRateService _service;

  ExchangeRates _rates;
  bool _loading = false;
  String? _error;

  ExchangeRates get rates => _rates;
  bool get isLoading => _loading;
  String? get error => _error;

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _rates = await _service.fetch();
    } on Exception {
      _error = 'Не вдалося оновити курс. Показано останній збережений.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
