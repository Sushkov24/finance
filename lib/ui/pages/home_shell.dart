import 'package:flutter/material.dart';

import 'package:finance_tracker/core/theme/app_theme.dart';
import 'package:finance_tracker/ui/pages/analytics_page.dart';
import 'package:finance_tracker/ui/pages/budgets_page.dart';
import 'package:finance_tracker/ui/pages/dashboard_page.dart';
import 'package:finance_tracker/ui/pages/settings_page.dart';
import 'package:finance_tracker/ui/pages/transactions_page.dart';

/// Root navigation: five sections in a bottom NavigationBar.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _items = <({IconData icon, IconData selected, String label})>[
    (icon: Icons.dashboard_outlined, selected: Icons.dashboard_rounded, label: 'Огляд'),
    (icon: Icons.receipt_long_outlined, selected: Icons.receipt_long_rounded, label: 'Операції'),
    (icon: Icons.savings_outlined, selected: Icons.savings_rounded, label: 'Бюджети'),
    (icon: Icons.pie_chart_outline_rounded, selected: Icons.pie_chart_rounded, label: 'Аналітика'),
    (icon: Icons.settings_outlined, selected: Icons.settings_rounded, label: 'Налаштування'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          DashboardPage(onViewAll: () => setState(() => _index = 1)),
          const TransactionsPage(),
          BudgetsPage(),
          AnalyticsPage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: _NavItem(
                      icon: _items[i].icon,
                      selectedIcon: _items[i].selected,
                      label: _items[i].label,
                      selected: _index == i,
                      onTap: () => setState(() => _index = i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: selected ? AppColors.primaryGradient : null,
                shape: BoxShape.circle,
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.primaryBright.withValues(alpha: 0.45),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                selected ? selectedIcon : icon,
                color: selected ? Colors.white : scheme.onSurfaceVariant,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

