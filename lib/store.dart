import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'money.dart';

class Expense {
  Expense({
    required this.id,
    required this.cents,
    required this.category,
    required this.date,
    this.note = '',
    this.recurringKey,
  });

  final int id;
  int cents;
  String category;
  DateTime date;
  String note;

  /// Set when added automatically from a debit order, so it isn't added twice.
  final String? recurringKey;

  Map<String, dynamic> toJson() => {
        'id': id,
        'c': cents,
        'cat': category,
        'd': date.toIso8601String(),
        'n': note,
        if (recurringKey != null) 'rk': recurringKey,
      };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'] as int,
        cents: j['c'] as int,
        category: j['cat'] as String? ?? 'other',
        date: DateTime.tryParse(j['d'] as String? ?? '') ?? DateTime.now(),
        note: j['n'] as String? ?? '',
        recurringKey: j['rk'] as String?,
      );
}

/// A monthly debit order or fixed cost that's added automatically.
class Recurring {
  Recurring({
    required this.id,
    required this.name,
    required this.cents,
    required this.category,
    required this.day,
  });

  final int id;
  String name;
  int cents;
  String category;
  int day; // day of the month it goes off

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'c': cents, 'cat': category, 'day': day};

  factory Recurring.fromJson(Map<String, dynamic> j) => Recurring(
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
        cents: j['c'] as int? ?? 0,
        category: j['cat'] as String? ?? 'debt',
        day: j['day'] as int? ?? 1,
      );
}

class Store extends ChangeNotifier {
  Store._();
  static final Store instance = Store._();

  late SharedPreferences _prefs;

  List<Expense> expenses = [];
  List<Recurring> recurring = [];
  Map<String, int> budgets = {}; // category id -> limit in cents per cycle
  int incomeCents = 0;
  int payday = 25;
  bool weekendToFriday = true;
  bool dailyReminder = false;
  int dailyHour = 20;
  int _nextId = 1;

  /// Alerts already sent this cycle, e.g. "2026-10-24|groceries|80".
  Set<String> sentAlerts = {};

  bool get isSetUp => incomeCents > 0;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    try {
      expenses = _list('expenses').map(Expense.fromJson).toList();
      recurring = _list('recurring').map(Recurring.fromJson).toList();
      final b = _prefs.getString('budgets');
      if (b != null) budgets = Map<String, int>.from(jsonDecode(b) as Map);
      sentAlerts = (_prefs.getStringList('sentAlerts') ?? []).toSet();
    } catch (_) {
      // Damaged data shouldn't stop the app from opening.
    }
    incomeCents = _prefs.getInt('income') ?? 0;
    payday = _prefs.getInt('payday') ?? 25;
    weekendToFriday = _prefs.getBool('weekendToFriday') ?? true;
    dailyReminder = _prefs.getBool('dailyReminder') ?? false;
    dailyHour = _prefs.getInt('dailyHour') ?? 20;
    _nextId = _prefs.getInt('nextId') ?? 1;
  }

  List<Map<String, dynamic>> _list(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  int newId() {
    final id = _nextId++;
    _prefs.setInt('nextId', _nextId);
    return id;
  }

  Cycle get currentCycle => cycleFor(DateTime.now(), payday, weekendToFriday);

  List<Expense> expensesIn(Cycle c) =>
      expenses.where((e) => c.contains(e.date)).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  int spentIn(Cycle c, {String? category}) => expenses
      .where((e) => c.contains(e.date) && (category == null || e.category == category))
      .fold(0, (sum, e) => sum + e.cents);

  Map<String, int> byCategory(Cycle c) {
    final m = <String, int>{};
    for (final e in expenses.where((e) => c.contains(e.date))) {
      m[e.category] = (m[e.category] ?? 0) + e.cents;
    }
    return m;
  }

  Future<void> upsertExpense(Expense e) async {
    final i = expenses.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      expenses[i] = e;
    } else {
      expenses.add(e);
    }
    await _saveExpenses();
  }

  Future<void> deleteExpense(int id) async {
    expenses.removeWhere((e) => e.id == id);
    await _saveExpenses();
  }

  Future<void> _saveExpenses() async {
    await _prefs.setString('expenses', jsonEncode(expenses.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  Future<void> setBudget(String category, int cents) async {
    if (cents <= 0) {
      budgets.remove(category);
    } else {
      budgets[category] = cents;
    }
    await _prefs.setString('budgets', jsonEncode(budgets));
    notifyListeners();
  }

  Future<void> saveSettings({
    int? income,
    int? payday,
    bool? weekendToFriday,
    bool? dailyReminder,
    int? dailyHour,
  }) async {
    if (income != null) incomeCents = income;
    if (payday != null) this.payday = payday;
    if (weekendToFriday != null) this.weekendToFriday = weekendToFriday;
    if (dailyReminder != null) this.dailyReminder = dailyReminder;
    if (dailyHour != null) this.dailyHour = dailyHour;
    await _prefs.setInt('income', incomeCents);
    await _prefs.setInt('payday', this.payday);
    await _prefs.setBool('weekendToFriday', this.weekendToFriday);
    await _prefs.setBool('dailyReminder', this.dailyReminder);
    await _prefs.setInt('dailyHour', this.dailyHour);
    notifyListeners();
  }

  Future<void> upsertRecurring(Recurring r) async {
    final i = recurring.indexWhere((x) => x.id == r.id);
    if (i >= 0) {
      recurring[i] = r;
    } else {
      recurring.add(r);
    }
    await _saveRecurring();
  }

  Future<void> deleteRecurring(int id) async {
    recurring.removeWhere((r) => r.id == id);
    await _saveRecurring();
  }

  Future<void> _saveRecurring() async {
    await _prefs.setString('recurring', jsonEncode(recurring.map((r) => r.toJson()).toList()));
    notifyListeners();
  }

  /// Adds any debit orders that have gone off this cycle and aren't logged yet.
  Future<int> applyRecurring() async {
    final cycle = currentCycle;
    final today = dateOnly(DateTime.now());
    var added = 0;
    for (final r in recurring) {
      // The debit order date that falls inside this cycle.
      for (final month in [cycle.start, cycle.end]) {
        final lastDay = DateTime(month.year, month.month + 1, 0).day;
        final due = DateTime(month.year, month.month, r.day > lastDay ? lastDay : r.day);
        if (!cycle.contains(due) || due.isAfter(today)) continue;
        final key = '${r.id}|${due.toIso8601String()}';
        if (expenses.any((e) => e.recurringKey == key)) continue;
        expenses.add(Expense(
          id: newId(),
          cents: r.cents,
          category: r.category,
          date: due,
          note: r.name,
          recurringKey: key,
        ));
        added++;
      }
    }
    if (added > 0) await _saveExpenses();
    return added;
  }

  Future<bool> markAlertSent(String key) async {
    if (!sentAlerts.add(key)) return false;
    await _prefs.setStringList('sentAlerts', sentAlerts.toList());
    return true;
  }
}
