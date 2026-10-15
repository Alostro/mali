import 'package:flutter/material.dart';

import '../money.dart';
import '../store.dart';
import '../widgets/charts.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  int _back = 0; // 0 = this month, 1 = last month, ...

  @override
  Widget build(BuildContext context) {
    final s = Store.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        var cycle = s.currentCycle;
        for (var i = 0; i < _back; i++) {
          cycle = cycle.previous(s.payday, s.weekendToFriday);
        }
        final prev = cycle.previous(s.payday, s.weekendToFriday);
        final byCat = s.byCategory(cycle);
        final prevByCat = s.byCategory(prev);
        final total = s.spentIn(cycle);
        final prevTotal = s.spentIn(prev);
        final sorted = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

        // Spending per day across the pay cycle.
        final days = cycle.lengthDays;
        final daily = List<double>.filled(days, 0);
        for (final e in s.expensesIn(cycle)) {
          final i = dateOnly(e.date).difference(cycle.start).inDays;
          if (i >= 0 && i < days) daily[i] += e.cents / 100;
        }
        final labels = [
          for (var i = 0; i < days; i++)
            (i % 7 == 0) ? '${cycle.start.add(Duration(days: i)).day}' : ''
        ];
        final todayIndex = _back == 0 ? dateOnly(DateTime.now()).difference(cycle.start).inDays : null;
        final allowance = s.incomeCents > 0 ? s.incomeCents / 100 / days : null;
        final daysSoFar = _back == 0 ? (todayIndex! + 1).clamp(1, days).toInt() : days;
        final biggestDay = daily.isEmpty ? 0.0 : daily.reduce((a, b) => a > b ? a : b);

        final changes = <MapEntry<String, int>>[
          for (final id in {...byCat.keys, ...prevByCat.keys})
            MapEntry(id, (byCat[id] ?? 0) - (prevByCat[id] ?? 0)),
        ]..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Where it went', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _back++),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${shortDate(cycle.start)} – ${shortDate(cycle.end.subtract(const Duration(days: 1)))}${_back == 0 ? ' (now)' : ''}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  onPressed: _back == 0 ? null : () => setState(() => _back--),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Donut(
                slices: [
                  for (final e in sorted)
                    DonutSlice(e.value.toDouble(), categoryById(e.key).color),
                ],
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(rand(total),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const Text('spent', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (sorted.isEmpty)
              const Text('No spending logged for this month yet.', textAlign: TextAlign.center)
            else
              Card(
                child: Column(
                  children: [
                    for (final e in sorted)
                      ListTile(
                        dense: true,
                        leading: Icon(categoryById(e.key).icon, color: categoryById(e.key).color),
                        title: Text(categoryById(e.key).name),
                        trailing: Text(
                          '${rand(e.value)}  ·  ${(e.value * 100 / (total == 0 ? 1 : total)).round()}%',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Text('Day by day', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              allowance == null
                  ? 'Set your income to see your daily allowance line.'
                  : 'Dashed line = even spread of your pay (${rand((allowance * 100).round())}/day). Red bars went over it.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            DailyBars(
              values: daily,
              labels: labels,
              allowance: allowance,
              highlightIndex: todayIndex,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _Fact('Average a day', rand(total ~/ daysSoFar))),
                Expanded(child: _Fact('Biggest day', rand((biggestDay * 100).round()))),
                Expanded(
                  child: _Fact(
                    'vs month before',
                    prevTotal == 0
                        ? '–'
                        : '${total >= prevTotal ? '+' : '-'}${rand((total - prevTotal).abs())}',
                  ),
                ),
              ],
            ),
            if (prevTotal > 0 && changes.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Biggest changes vs the month before',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    for (final c in changes.take(4))
                      ListTile(
                        dense: true,
                        leading: Icon(
                          c.value > 0 ? Icons.trending_up : Icons.trending_down,
                          color: c.value > 0
                              ? Theme.of(context).colorScheme.error
                              : const Color(0xFF2E7D32),
                        ),
                        title: Text(categoryById(c.key).name),
                        trailing: Text(
                            '${c.value > 0 ? '+' : '-'}${rand(c.value.abs())}'),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
      ],
    );
  }
}
