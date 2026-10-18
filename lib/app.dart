import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/theme/app_theme.dart';
import 'package:finance_tracker/logic/app_settings_view_model.dart';
import 'package:finance_tracker/logic/security_view_model.dart';
import 'package:finance_tracker/ui/pages/home_shell.dart';
import 'package:finance_tracker/ui/pages/lock_page.dart';

class FinanceApp extends StatefulWidget {
  const FinanceApp({super.key});

  @override
  State<FinanceApp> createState() => _FinanceAppState();
}

class _FinanceAppState extends State<FinanceApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      context.read<SecurityViewModel>().lockIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsViewModel>();
    final security = context.watch<SecurityViewModel>();

    return MaterialApp(
      title: 'Фінанси',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      builder: (context, child) => DecoratedBox(
        decoration: AppTheme.backdrop(Theme.of(context).brightness),
        child: child,
      ),
      locale: const Locale('uk'),
      supportedLocales: const [Locale('uk'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: security.isLocked ? const LockPage() : const HomeShell(),
    );
  }
}
