import 'package:finance_tracker/models/models.dart';

/// Search and filter criteria for the transactions list.
class TransactionFilter {
  const TransactionFilter({
    this.query = '',
    this.type,
    this.categoryId,
    this.from,
    this.to,
    this.minAmount,
    this.maxAmount,
  });

  final String query;

  /// `INCOME`, `EXPENSE` or null for all.
  final String? type;
  final int? categoryId;
  final DateTime? from;
  final DateTime? to;
  final double? minAmount;
  final double? maxAmount;

  bool get isActive =>
      type != null ||
      categoryId != null ||
      from != null ||
      to != null ||
      minAmount != null ||
      maxAmount != null;

  TransactionFilter withQuery(String value) => TransactionFilter(
        query: value,
        type: type,
        categoryId: categoryId,
        from: from,
        to: to,
        minAmount: minAmount,
        maxAmount: maxAmount,
      );

  List<FinanceTransaction> apply(List<FinanceTransaction> items) {
    final q = query.trim().toLowerCase();
    return items.where((t) {
      if (q.isNotEmpty) {
        final haystack = '${t.categoryName} ${t.accountName} ${t.note ?? ''}'.toLowerCase();
        if (!haystack.contains(q)) return false;
      }
      if (type != null && t.categoryType != type) return false;
      if (categoryId != null && t.categoryId != categoryId) return false;
      if (from != null && t.date.isBefore(DateTime(from!.year, from!.month, from!.day))) {
        return false;
      }
      if (to != null &&
          t.date.isAfter(DateTime(to!.year, to!.month, to!.day, 23, 59, 59))) {
        return false;
      }
      if (minAmount != null && t.amount < minAmount!) return false;
      if (maxAmount != null && t.amount > maxAmount!) return false;
      return true;
    }).toList();
  }
}
