import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/utils/formatters.dart';
import 'package:finance_tracker/logic/finance_view_model.dart';
import 'package:finance_tracker/models/models.dart';
import 'package:finance_tracker/ui/components/budget_progress_bar.dart';
import 'package:finance_tracker/ui/components/common_widgets.dart';

/// Monthly category limits for the current month.
class BudgetsPage extends StatelessWidget {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FinanceViewModel>();
    final now = DateTime.now();
    final statuses = vm.budgetStatusesFor(now);

    return Scaffold(
      appBar: AppBar(title: const Text('Бюджети')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => showBudgetDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Ліміт'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          SectionHeader(title: Fmt.monthYear(now)),
          if (statuses.isEmpty)
            const EmptyNotice('Ліміти на цей місяць ще не задано. Натисніть «Ліміт», щоб додати.')
          else
            for (final s in statuses)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Column(
                      children: [
                        BudgetProgressBar(
                          status: s,
                          onTap: () => showBudgetDialog(context, existing: s.budget),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _delete(context, s.budget),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Видалити'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, Budget budget) async {
    final ok = await confirmAction(
      context,
      title: 'Видалити ліміт?',
      message: 'Ліміт для категорії «${budget.categoryName}» буде видалено.',
    );
    if (ok && budget.id != null && context.mounted) {
      await context.read<FinanceViewModel>().deleteBudget(budget.id!);
    }
  }
}

/// Creates or edits a limit for the current month. The category of an existing limit is fixed.
Future<void> showBudgetDialog(BuildContext context, {Budget? existing}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _BudgetDialog(existing: existing),
  );
}

class _BudgetDialog extends StatefulWidget {
  const _BudgetDialog({this.existing});

  final Budget? existing;

  @override
  State<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<_BudgetDialog> {
  late int? _categoryId = widget.existing?.categoryId;
  late final TextEditingController _limit = TextEditingController(
    text: widget.existing == null
        ? ''
        : widget.existing!.limitAmount.toStringAsFixed(2).replaceAll('.', ','),
  );

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  double? get _parsedLimit =>
      double.tryParse(_limit.text.replaceAll(' ', '').replaceAll(',', '.'));

  Future<void> _save() async {
    final vm = context.read<FinanceViewModel>();
    final limit = _parsedLimit;
    final categoryId = _categoryId;
    if (categoryId == null || limit == null || limit <= 0) return;

    final now = DateTime.now();
    await vm.saveBudget(
      Budget(
        categoryId: categoryId,
        limitAmount: limit,
        month: now.month,
        year: now.year,
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FinanceViewModel>();
    final isEdit = widget.existing != null;
    final expenseCategories = vm.categories.where((c) => !c.isIncome).toList();
    final categoryValue = expenseCategories.any((c) => c.id == _categoryId) ? _categoryId : null;
    final canSave = categoryValue != null && (_parsedLimit ?? 0) > 0;

    return AlertDialog(
      title: Text(isEdit ? 'Редагування ліміту' : 'Новий ліміт'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int>(
            initialValue: categoryValue,
            decoration: const InputDecoration(labelText: 'Категорія витрат'),
            items: [
              for (final c in expenseCategories)
                DropdownMenuItem<int>(value: c.id!, child: Text(c.name)),
            ],
            onChanged: isEdit ? null : (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _limit,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Ліміт на місяць', prefixText: '₴ '),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Скасувати'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: canSave ? _save : null,
          child: const Text('Зберегти'),
        ),
      ],
    );
  }
}
