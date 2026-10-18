import 'package:flutter/material.dart';

/// Icon keys stored in the database, mapped to Material icons.
const Map<String, IconData> categoryIcons = {
  'cart': Icons.shopping_cart_outlined,
  'food': Icons.restaurant_outlined,
  'bus': Icons.directions_bus_outlined,
  'car': Icons.directions_car_outlined,
  'home': Icons.home_outlined,
  'game': Icons.sports_esports_outlined,
  'health': Icons.favorite_border,
  'school': Icons.school_outlined,
  'gift': Icons.card_giftcard_outlined,
  'pets': Icons.pets_outlined,
  'phone': Icons.phone_iphone_outlined,
  'work': Icons.work_outline,
  'wallet': Icons.account_balance_wallet_outlined,
  'trending': Icons.trending_up,
  'bolt': Icons.flash_on_outlined,
  'other': Icons.category_outlined,
};

const List<String> categoryColors = [
  '#1E88E5',
  '#43A047',
  '#E53935',
  '#FB8C00',
  '#8E24AA',
  '#00897B',
  '#6D4C41',
  '#546E7A',
  '#D81B60',
  '#FDD835',
];

IconData iconFor(String key) => categoryIcons[key] ?? Icons.category_outlined;

Color colorFromHex(String hex) {
  final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  return value == null ? const Color(0xFF94A3B8) : Color(0xFF000000 | value);
}
