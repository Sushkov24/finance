import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/constants/palette.dart';
import 'package:finance_tracker/logic/finance_view_model.dart';
import 'package:finance_tracker/models/models.dart';
import 'package:finance_tracker/ui/components/common_widgets.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<FinanceViewModel>().categories;
    final expense = categories.where((c) => !c.isIncome).toList();
    final income = categories.where((c) => c.isIncome).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Категорії')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => showCategorySheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Категорія'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          const SectionHeader(title: 'Витрати'),
          _CategoryCard(categories: expense),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Доходи'),
          _CategoryCard(categories: income),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.categories});

  final List<FinanceCategory> categories;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const EmptyNotice('Категорій немає.');
    }
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < categories.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: colorFromHex(categories[i].color).withValues(alpha: 0.15),
                child: Icon(iconFor(categories[i].icon), color: colorFromHex(categories[i].color), size: 20),
              ),
              title: Text(categories[i].name),
              trailing: const Icon(Icons.edit_outlined, size: 18),
              onTap: () => showCategorySheet(context, existing: categories[i]),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bottom sheet for creating or editing a category: name, icon and colour.
/// The type of an existing category is fixed, because balances depend on it.
Future<void> showCategorySheet(BuildContext context, {FinanceCategory? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _CategorySheet(existing: existing),
  );
}

class _CategorySheet extends StatefulWidget {
  const _CategorySheet({this.existing});

  final FinanceCategory? existing;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late String _type = widget.existing?.type ?? 'EXPENSE';
  late String _icon = widget.existing?.icon ?? 'other';
  late String _color = widget.existing?.color ?? categoryColors.first;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;

    final vm = context.read<FinanceViewModel>();
    final existing = widget.existing;
    if (existing == null) {
      await vm.addCategory(
        FinanceCategory(name: name, type: _type, icon: _icon, color: _color),
      );
    } else {
      await vm.updateCategory(
        FinanceCategory(
          id: existing.id,
          name: name,
          type: existing.type,
          icon: _icon,
          color: _color,
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.existing != null;
    final canSave = _name.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEdit ? 'Редагування категорії' : 'Нова категорія',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Назва'),
            ),
            if (!isEdit) ...[
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'EXPENSE', label: Text('Витрата')),
                  ButtonSegment(value: 'INCOME', label: Text('Дохід')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
            ],
            const SizedBox(height: 20),
            Text('Іконка', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in categoryIcons.entries)
                  _Choice(
                    selected: _icon == entry.key,
                    onTap: () => setState(() => _icon = entry.key),
                    child: Icon(entry.value, size: 22),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Колір', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final hex in categoryColors)
                  GestureDetector(
                    onTap: () => setState(() => _color = hex),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colorFromHex(hex),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == hex ? theme.colorScheme.onSurface : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: canSave ? _save : null,
              child: Text(isEdit ? 'Зберегти зміни' : 'Додати категорію'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.selected, required this.onTap, required this.child});

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        ),
        child: IconTheme.merge(
          data: IconThemeData(color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
          child: child,
        ),
      ),
    );
  }
}
