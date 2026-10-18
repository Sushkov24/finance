import 'package:flutter/material.dart';

import 'package:finance_tracker/core/theme/app_theme.dart';

/// Section title used on screens.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.subtitle, this.action});

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          if (subtitle != null)
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ?action,
        ],
      ),
    );
  }
}

/// Placeholder shown when a list has no data.
class EmptyNotice extends StatelessWidget {
  const EmptyNotice(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// Destructive / confirmation dialog. Returns true when the user confirms.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Видалити',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Скасувати'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
