import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/theme/app_theme.dart';
import 'package:finance_tracker/core/utils/formatters.dart';
import 'package:finance_tracker/logic/finance_view_model.dart';
import 'package:finance_tracker/logic/transaction_filter.dart';
import 'package:finance_tracker/models/models.dart';
import 'package:finance_tracker/ui/components/common_widgets.dart';
import 'package:finance_tracker/ui/components/transaction_tile.dart';
import 'package:finance_tracker/ui/pages/transaction_form_sheet.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  TransactionFilter _filter = const TransactionFilter();

  Future<void> _openFilter() async {
    final result = await showModalBottomSheet<TransactionFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FilterSheet(initial: _filter, categories: context.read<FinanceViewModel>().categories),
    );
    if (result != null) setState(() => _filter = result);
  }

  Future<void> _delete(FinanceTransaction t) async {
    final vm = context.read<FinanceViewModel>();
    final ok = await confirmAction(
      context,
      title: 'Видалити операцію?',
      message: '${t.categoryName} · ${Fmt.money(t.amount, currency: t.currency)}. Баланс рахунку буде скориговано.',
    );
    if (ok && t.id != null) await vm.deleteTransaction(t.id!);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FinanceViewModel>();
    final items = _filter.apply(vm.transactions);
    final groups = _groupByDay(items);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Операції'),
        actions: [
          IconButton(
            tooltip: 'Фільтр',
            onPressed: _openFilter,
            icon: Badge(
              isLabelVisible: _filter.isActive,
              child: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        tooltip: 'Нова операція',
        onPressed: () => showTransactionForm(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _filter = _filter.withQuery(v)),
              decoration: const InputDecoration(
                hintText: 'Пошук за категорією, рахунком або приміткою',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: EmptyNotice('Операцій не знайдено.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    itemCount: groups.length,
                    itemBuilder: (context, i) {
                      final group = groups[i];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                            child: Text(
                              Fmt.day(group.day),
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                          Card(
                            child: Column(
                              children: [
                                for (final t in group.items)
                                  Dismissible(
                                    key: ValueKey('tx-${t.id}'),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      decoration: BoxDecoration(
                                        color: AppColors.expense,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(Icons.delete_outline, color: Colors.white),
                                    ),
                                    confirmDismiss: (_) async {
                                      await _delete(t);
                                      return false;
                                    },
                                    child: TransactionTile(
                                      transaction: t,
                                      onTap: () => showTransactionForm(context, existing: t),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static List<_DayGroup> _groupByDay(List<FinanceTransaction> items) {
    final groups = <_DayGroup>[];
    for (final t in items) {
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      if (groups.isEmpty || groups.last.day != day) {
        groups.add(_DayGroup(day));
      }
      groups.last.items.add(t);
    }
    return groups;
  }
}

class _DayGroup {
  _DayGroup(this.day);

  final DateTime day;
  final List<FinanceTransaction> items = [];
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial, required this.categories});

  final TransactionFilter initial;
  final List<FinanceCategory> categories;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _type = widget.initial.type;
  late int? _categoryId = widget.initial.categoryId;
  late DateTime? _from = widget.initial.from;
  late DateTime? _to = widget.initial.to;
  late final TextEditingController _minAmount = TextEditingController(
    text: _formatAmount(widget.initial.minAmount),
  );
  late final TextEditingController _maxAmount = TextEditingController(
    text: _formatAmount(widget.initial.maxAmount),
  );

  static String _formatAmount(double? value) => value == null
      ? ''
      : value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);

  static double? _parseAmount(TextEditingController controller) =>
      double.tryParse(controller.text.replaceAll(' ', '').replaceAll(',', '.'));

  @override
  void dispose() {
    _minAmount.dispose();
    _maxAmount.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('uk'),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.categories
        .where((c) => _type == null || c.type == _type)
        .toList();
    final categoryValue =
        categories.any((c) => c.id == _categoryId) ? _categoryId : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Фільтр операцій', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          SegmentedButton<String?>(
            segments: const [
              ButtonSegment(value: null, label: Text('Усі')),
              ButtonSegment(value: 'EXPENSE', label: Text('Витрати')),
              ButtonSegment(value: 'INCOME', label: Text('Доходи')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              _categoryId = null;
            }),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int?>(
            key: ValueKey('filter-category-$_type'),
            initialValue: categoryValue,
            decoration: const InputDecoration(labelText: 'Категорія'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Усі категорії')),
              for (final c in categories) DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
            ],
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(isFrom: true),
                  child: Text(_from == null ? 'З дати' : Fmt.dayShort(_from!)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(isFrom: false),
                  child: Text(_to == null ? 'По дату' : Fmt.dayShort(_to!)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minAmount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Сума від', prefixText: '₴ '),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _maxAmount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Сума до', prefixText: '₴ '),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, const TransactionFilter()),
                  child: const Text('Скинути'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    TransactionFilter(
                      query: widget.initial.query,
                      type: _type,
                      categoryId: _categoryId,
                      from: _from,
                      to: _to,
                      minAmount: _parseAmount(_minAmount),
                      maxAmount: _parseAmount(_maxAmount),
                    ),
                  ),
                  child: const Text('Застосувати'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
