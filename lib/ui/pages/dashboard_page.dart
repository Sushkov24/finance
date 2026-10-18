import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/theme/app_theme.dart';
import 'package:finance_tracker/core/utils/formatters.dart';
import 'package:finance_tracker/logic/analytics_calculator.dart';
import 'package:finance_tracker/logic/finance_view_model.dart';
import 'package:finance_tracker/models/models.dart';
import 'package:finance_tracker/ui/components/budget_progress_bar.dart';
import 'package:finance_tracker/ui/components/common_widgets.dart';
import 'package:finance_tracker/ui/components/exchange_rate_card.dart';
import 'package:finance_tracker/ui/components/stat_card.dart';
import 'package:finance_tracker/ui/components/transaction_details_sheet.dart';
import 'package:finance_tracker/ui/components/transaction_tile.dart';
import 'package:finance_tracker/ui/pages/transaction_form_sheet.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, this.onViewAll});

  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FinanceViewModel>();
    final now = DateTime.now();
    final month = vm.analytics(Period.month, now);
    final budgets = vm.budgetStatusesFor(now);
    final recent = vm.transactions.take(5).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image(image: AssetImage('assets/images/logo.png'), height: 28),
            SizedBox(width: 8),
            Text('Огляд'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => showTransactionForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Операція'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _BalanceCard(total: vm.totalBalance, accounts: vm.accounts),
          const SizedBox(height: 12),
          const ExchangeRateCard(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Доходи, ${Fmt.monthYear(now)}',
                  value: Fmt.money(month.income),
                  icon: Icons.arrow_downward_rounded,
                  color: AppColors.income,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Витрати',
                  value: Fmt.money(month.expense),
                  icon: Icons.arrow_upward_rounded,
                  color: AppColors.expense,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Бюджети цього місяця'),
          if (budgets.isEmpty)
            const EmptyNotice('Ліміти ще не задано. Додайте їх у розділі «Бюджети».')
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [for (final s in budgets.take(3)) BudgetProgressBar(status: s)],
                ),
              ),
            ),
          const SizedBox(height: 24),
          SectionHeader(
            title: 'Останні операції',
            action: TextButton(onPressed: onViewAll, child: const Text('Усі')),
          ),
          if (recent.isEmpty)
            const EmptyNotice('Операцій ще немає. Натисніть «Операція», щоб додати першу.')
          else
            Card(
              child: Column(
                children: [
                  for (final t in recent)
                    TransactionTile(
                      transaction: t,
                      onTap: () => showTransactionDetails(
                        context,
                        t,
                        onEdit: () => showTransactionForm(context, existing: t),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.total, required this.accounts});

  final double total;
  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryBright, AppColors.primaryDeep, Color(0xFF0B1F4D)],
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withValues(alpha: 0.45),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -50,
            child: _GlowCircle(size: 160, alpha: 0.16),
          ),
          Positioned(
            left: -30,
            bottom: -60,
            child: _GlowCircle(size: 140, alpha: 0.10),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Загальний баланс (у ₴)',
                    style: TextStyle(
                      color: scheme.onPrimary.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.account_balance_wallet_rounded, size: 18, color: scheme.onPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  Fmt.money(total),
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in accounts)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Text(
                          '${a.name}: ${Fmt.money(a.balance, currency: a.currency)}',
                          style: TextStyle(
                            color: scheme.onPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.alpha});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
  }
}

