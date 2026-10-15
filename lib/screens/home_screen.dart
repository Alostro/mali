import 'package:flutter/material.dart';

import '../money.dart';
import '../store.dart';
import 'add_sheet.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onSetUp});
  final VoidCallback onSetUp;

  @override
  Widget build(BuildContext context) {
    final s = Store.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final cycle = s.currentCycle;
        final spent = s.spentIn(cycle);
        final items = s.expensesIn(cycle);
        final byCat = s.byCategory(cycle);
        final catIds = <String>{...s.budgets.keys, ...byCat.keys}.toList()
          ..sort((a, b) => (byCat[b] ?? 0).compareTo(byCat[a] ?? 0));

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Text('Mali', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            if (!s.isSetUp)
              _SetUpCard(onSetUp: onSetUp)
            else
              _SummaryCard(cycle: cycle, spent: spent, income: s.incomeCents),
            if (catIds.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Categories', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      for (final id in catIds)
                        _CategoryRow(
                          category: categoryById(id),
                          spent: byCat[id] ?? 0,
                          limit: s.budgets[id],
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text('This month', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Nothing logged yet. Tap "Add" each time you spend: taxi, lunch, data. It takes 5 seconds.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              for (final e in items.take(40)) _ExpenseTile(expense: e),
          ],
        );
      },
    );
  }
}

class _SetUpCard extends StatelessWidget {
  const _SetUpCard({required this.onSetUp});
  final VoidCallback onSetUp;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sawubona 👋', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text(
                'Tell Mali what comes in each month and when payday is. Then it can tell you what\'s safe to spend each day until the next one.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onSetUp, child: const Text('Set up (1 minute)')),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.cycle, required this.spent, required this.income});
  final Cycle cycle;
  final int spent;
  final int income;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final left = income - spent;
    final daysLeft = cycle.daysLeft(DateTime.now());
    final perDay = left > 0 ? left ~/ daysLeft : 0;
    final used = income == 0 ? 0.0 : (spent / income).clamp(0.0, 1.0).toDouble();
    final over = left < 0;
    final fg = over ? scheme.onErrorContainer : scheme.onPrimaryContainer;

    return Card(
      color: over ? scheme.errorContainer : scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: fg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(over ? 'Over budget by' : 'Left until payday'),
              const SizedBox(height: 2),
              Text(
                rand(over ? -left : left),
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(color: fg, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: used,
                  minHeight: 10,
                  color: over ? scheme.error : null,
                  backgroundColor: fg.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      label: 'Safe to spend',
                      value: over ? 'R0' : '${rand(perDay)}/day',
                    ),
                  ),
                  Expanded(
                    child: _Stat(
                      label: 'Payday',
                      value: '${dayLabel(cycle.end)} · $daysLeft day${daysLeft == 1 ? '' : 's'}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Spent ${rand(spent)} of ${rand(income)}',
                  style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category, required this.spent, this.limit});
  final Category category;
  final int spent;
  final int? limit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = limit == null || limit == 0 ? null : spent / limit!;
    final color = pct == null
        ? category.color
        : pct >= 1
            ? scheme.error
            : pct >= 0.8
                ? const Color(0xFFEF6C00)
                : category.color;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: category.color.withValues(alpha: 0.15),
            child: Icon(category.icon, size: 18, color: category.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(category.name)),
                    Text(
                      limit == null ? rand(spent) : '${rand(spent)} / ${rand(limit!)}',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: pct != null && pct >= 1 ? scheme.error : null),
                    ),
                  ],
                ),
                if (pct != null) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0.0, 1.0).toDouble(),
                      minHeight: 6,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense});
  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final c = categoryById(expense.category);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(
        backgroundColor: c.color.withValues(alpha: 0.15),
        child: Icon(c.icon, color: c.color, size: 20),
      ),
      title: Text(expense.note.isEmpty ? c.name : expense.note),
      subtitle: Text(
          '${dayLabel(expense.date)}${expense.note.isEmpty ? '' : ' · ${c.name}'}${expense.recurringKey != null ? ' · debit order' : ''}'),
      trailing: Text(rand(expense.cents),
          style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: () => showAddSheet(context, existing: expense),
    );
  }
}
