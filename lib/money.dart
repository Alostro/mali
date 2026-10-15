import 'package:flutter/material.dart';

/// Amounts are stored in cents so totals never pick up rounding errors.
String rand(int cents, {bool showCents = false}) {
  final negative = cents < 0;
  final abs = cents.abs();
  final whole = abs ~/ 100;
  final digits = whole.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
    buf.write(digits[i]);
  }
  final c = abs % 100;
  final tail = showCents || c != 0 ? '.${c.toString().padLeft(2, '0')}' : '';
  return '${negative ? '-' : ''}R$buf$tail';
}

/// Parses what someone types: "150", "R1 250,50", "1250.5".
int? parseRand(String input) {
  var s = input.trim().replaceAll(RegExp(r'[Rr\s]'), '');
  if (s.isEmpty) return null;
  // Treat a comma as the decimal mark when there is no dot (SA style).
  if (!s.contains('.') && s.contains(',')) {
    s = s.replaceAll(',', '.');
  } else {
    s = s.replaceAll(',', '');
  }
  final v = double.tryParse(s);
  if (v == null || v < 0) return null;
  return (v * 100).round();
}

class Category {
  const Category(this.id, this.name, this.icon, this.color, this.hint);
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final String hint;
}

const categories = <Category>[
  Category('groceries', 'Groceries', Icons.shopping_cart_outlined, Color(0xFF2E7D32), 'Checkers, Shoprite, Pick n Pay, spaza'),
  Category('transport', 'Transport', Icons.local_taxi_outlined, Color(0xFFF9A825), 'Taxi fare, Uber, Bolt, petrol'),
  Category('data', 'Airtime & data', Icons.phone_android, Color(0xFF1565C0), 'Data bundles, airtime, WiFi'),
  Category('utilities', 'Electricity & water', Icons.bolt_outlined, Color(0xFFEF6C00), 'Prepaid units, water, gas'),
  Category('rent', 'Rent & home', Icons.home_outlined, Color(0xFF6D4C41), 'Rent, res, levies'),
  Category('eating', 'Eating out', Icons.lunch_dining_outlined, Color(0xFFD81B60), 'Kota, KFC, takeaways, restaurants'),
  Category('family', 'Family support', Icons.family_restroom, Color(0xFF8E24AA), 'Money home, siblings, parents'),
  Category('savings', 'Stokvel & savings', Icons.savings_outlined, Color(0xFF00897B), 'Stokvel, savings pocket, TFSA'),
  Category('debt', 'Debit orders & debt', Icons.account_balance_outlined, Color(0xFF455A64), 'Phone contract, store card, loans, insurance'),
  Category('clothing', 'Clothing', Icons.checkroom_outlined, Color(0xFF5E35B1), 'Clothes, shoes, hair'),
  Category('fun', 'Fun & going out', Icons.celebration_outlined, Color(0xFFE53935), 'Weekends, events, streaming'),
  Category('personal', 'Toiletries & personal', Icons.spa_outlined, Color(0xFF00ACC1), 'Toiletries, cleaning, meds'),
  Category('other', 'Other', Icons.more_horiz, Color(0xFF757575), 'Anything else'),
];

Category categoryById(String id) =>
    categories.firstWhere((c) => c.id == id, orElse: () => categories.last);

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The actual pay date in a month: the chosen day (clamped to the month's
/// length), moved to the Friday before if it falls on a weekend.
DateTime payDateIn(int year, int month, int payday, bool weekendToFriday) {
  final lastDay = DateTime(year, month + 1, 0).day;
  var d = DateTime(year, month, payday > lastDay ? lastDay : payday);
  if (weekendToFriday) {
    if (d.weekday == DateTime.saturday) d = d.subtract(const Duration(days: 1));
    if (d.weekday == DateTime.sunday) d = d.subtract(const Duration(days: 2));
  }
  return d;
}

/// A budget period: from one payday (inclusive) to the next (exclusive).
class Cycle {
  const Cycle(this.start, this.end);
  final DateTime start;
  final DateTime end;

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);
  int get lengthDays => end.difference(start).inDays;

  /// Days left including today.
  int daysLeft(DateTime now) {
    final left = end.difference(dateOnly(now)).inDays;
    return left < 1 ? 1 : left;
  }

  Cycle previous(int payday, bool weekendToFriday) =>
      cycleFor(start.subtract(const Duration(days: 1)), payday, weekendToFriday);
}

Cycle cycleFor(DateTime when, int payday, bool weekendToFriday) {
  final day = dateOnly(when);
  final thisMonth = payDateIn(day.year, day.month, payday, weekendToFriday);
  if (!day.isBefore(thisMonth)) {
    return Cycle(thisMonth, payDateIn(day.year, day.month + 1, payday, weekendToFriday));
  }
  return Cycle(payDateIn(day.year, day.month - 1, payday, weekendToFriday), thisMonth);
}

const _monthsShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _daysShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String shortDate(DateTime d) => '${d.day} ${_monthsShort[d.month - 1]}';
String dayLabel(DateTime d) {
  final today = dateOnly(DateTime.now());
  final diff = today.difference(dateOnly(d)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '${_daysShort[d.weekday - 1]} ${shortDate(d)}';
}
