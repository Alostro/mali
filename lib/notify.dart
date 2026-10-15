import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'money.dart';
import 'store.dart';

/// Budget heads-ups and reminders, shown even when the app is closed.
class Notify {
  Notify._();
  static final Notify instance = Notify._();

  static const _paydaySoonId = 1;
  static const _dailyId = 2;
  static const _paydayId = 3;

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'mali_alerts',
      'Budget alerts',
      channelDescription: 'Heads-ups when you get close to a limit, and payday reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  Future<void> init() async {
    tzdata.initializeTimeZones();
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
  }

  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  int _alertId = 100;

  Future<void> _show(String title, String body) =>
      _plugin.show(_alertId++ % 50 + 100, title, body, _details);

  Future<void> _at(int id, DateTime when, String title, String body,
      {DateTimeComponents? repeat}) async {
    await _plugin.cancel(id);
    if (!when.isAfter(DateTime.now()) && repeat == null) return;
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.UTC),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: repeat,
    );
  }

  /// Call after every change: sends limit alerts once each and refreshes
  /// the payday reminders with up-to-date numbers.
  Future<void> refresh() async {
    final s = Store.instance;
    if (!s.isSetUp) return;
    final cycle = s.currentCycle;
    final now = DateTime.now();
    final daysLeft = cycle.daysLeft(now);
    final cycleKey = cycle.start.toIso8601String().substring(0, 10);

    // Category limits: one alert at 80%, one when it's gone over.
    for (final entry in s.budgets.entries) {
      final spent = s.spentIn(cycle, category: entry.key);
      final pct = spent * 100 ~/ entry.value;
      final name = categoryById(entry.key).name;
      if (pct >= 100 && await s.markAlertSent('$cycleKey|${entry.key}|100')) {
        await _show('$name is over budget',
            'Spent ${rand(spent)} of ${rand(entry.value)}, with $daysLeft day(s) to payday.');
      } else if (pct >= 80 && pct < 100 && await s.markAlertSent('$cycleKey|${entry.key}|80')) {
        await _show('$name is at $pct%',
            '${rand(entry.value - spent)} left for $daysLeft day(s). Go easy until payday.');
      }
    }

    // Whole pay: alert at 80%.
    final spentAll = s.spentIn(cycle);
    final leftAll = s.incomeCents - spentAll;
    if (spentAll * 100 >= s.incomeCents * 80 &&
        await s.markAlertSent('$cycleKey|total|80')) {
      await _show('Heads-up: ${rand(leftAll < 0 ? 0 : leftAll)} left',
          "You've used ${spentAll * 100 ~/ s.incomeCents}% of this month's money, and payday is $daysLeft day(s) away.");
    }

    // 3 days before payday at 18:00, with the current numbers.
    final soon = DateTime(cycle.end.year, cycle.end.month, cycle.end.day - 3, 18);
    await _at(_paydaySoonId, soon, 'Payday in 3 days 🙌',
        leftAll >= 0
            ? 'You have ${rand(leftAll)} left. Hold on, almost there.'
            : "You're ${rand(-leftAll)} over this month. Plan next month's budget before it lands.");

    // Payday morning: a fresh start.
    await _at(_paydayId, DateTime(cycle.end.year, cycle.end.month, cycle.end.day, 8),
        "It's payday 💸", 'New month, fresh budget. Pay yourself first: stokvel and savings before spending.');

    // Daily "log your spending" nudge.
    if (s.dailyReminder) {
      var t = DateTime(now.year, now.month, now.day, s.dailyHour);
      if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
      await _at(_dailyId, t, 'Log today\'s spending',
          'Taxi, lunch, data? 10 seconds now saves a month-end surprise.',
          repeat: DateTimeComponents.time);
    } else {
      await _plugin.cancel(_dailyId);
    }
  }
}
