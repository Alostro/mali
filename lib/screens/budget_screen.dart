import 'package:flutter/material.dart';

import '../money.dart';
import '../notify.dart';
import '../store.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  Future<void> _changed() async {
    await Notify.instance.requestPermission();
    await Store.instance.applyRecurring();
    await Notify.instance.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final s = Store.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final allocated = s.budgets.values.fold<int>(0, (a, b) => a + b);
        final unallocated = s.incomeCents - allocated;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Budget', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: const Text('Money in each month'),
                    subtitle: const Text('Salary, stipend, allowance, side hustle'),
                    trailing: Text(s.incomeCents == 0 ? 'Set' : rand(s.incomeCents),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () async {
                      final v = await askAmount(context, 'Money in each month', s.incomeCents);
                      if (v != null) {
                        await s.saveSettings(income: v);
                        await _changed();
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.event_available_outlined),
                    title: const Text('Payday'),
                    subtitle: Text('Next: ${dayLabel(s.currentCycle.end)}'),
                    trailing: DropdownButton<int>(
                      value: s.payday,
                      underline: const SizedBox.shrink(),
                      items: [
                        for (var d = 1; d <= 31; d++)
                          DropdownMenuItem(
                              value: d, child: Text(d == 31 ? 'Last day' : '${_ordinal(d)}')),
                      ],
                      onChanged: (d) async {
                        if (d == null) return;
                        await s.saveSettings(payday: d);
                        await _changed();
                      },
                    ),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.weekend_outlined),
                    title: const Text('Paid on Friday if payday is a weekend'),
                    value: s.weekendToFriday,
                    onChanged: (v) async {
                      await s.saveSettings(weekendToFriday: v);
                      await _changed();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text('Limits per category',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                TextButton.icon(
                  onPressed: () => _suggest(context),
                  icon: const Icon(Icons.auto_fix_high, size: 18),
                  label: const Text('Use last month'),
                ),
              ],
            ),
            if (s.incomeCents > 0)
              Text(
                unallocated >= 0
                    ? '${rand(unallocated)} not given a job yet. Tip: put it in savings or a stokvel.'
                    : 'Your limits add up to ${rand(-unallocated)} more than you earn.',
                style: TextStyle(
                  color: unallocated < 0 ? Theme.of(context).colorScheme.error : null,
                  fontSize: 13,
                ),
              ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final c in categories)
                    ListTile(
                      dense: true,
                      leading: Icon(c.icon, color: c.color),
                      title: Text(c.name),
                      subtitle: Text(c.hint, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Text(
                        s.budgets[c.id] == null ? 'No limit' : rand(s.budgets[c.id]!),
                        style: TextStyle(
                          fontWeight: s.budgets[c.id] == null ? null : FontWeight.w600,
                          color: s.budgets[c.id] == null
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : null,
                        ),
                      ),
                      onTap: () async {
                        final v = await askAmount(context, '${c.name} limit', s.budgets[c.id] ?? 0,
                            allowZero: true);
                        if (v != null) {
                          await s.setBudget(c.id, v);
                          await _changed();
                        }
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text('Debit orders & fixed costs',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                TextButton.icon(
                  onPressed: () => _editRecurring(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            const Text(
              'Phone contract, insurance, rent, stokvel. Mali logs them for you on the day they go off.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            for (final r in s.recurring)
              Card(
                child: ListTile(
                  leading: Icon(categoryById(r.category).icon, color: categoryById(r.category).color),
                  title: Text(r.name),
                  subtitle: Text('Every ${_ordinal(r.day)}'),
                  trailing: Text(rand(r.cents), style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => _editRecurring(context, existing: r),
                ),
              ),
            const SizedBox(height: 20),
            Text('Reminders', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_outlined),
                    title: const Text('Daily "log your spending" nudge'),
                    subtitle: Text('Every day at ${s.dailyHour.toString().padLeft(2, '0')}:00'),
                    value: s.dailyReminder,
                    onChanged: (v) async {
                      await s.saveSettings(dailyReminder: v);
                      await _changed();
                    },
                  ),
                  ListTile(
                    enabled: s.dailyReminder,
                    leading: const SizedBox(width: 24),
                    title: const Text('Change time'),
                    trailing: const Icon(Icons.schedule),
                    onTap: () async {
                      final t = await showTimePicker(
                          context: context, initialTime: TimeOfDay(hour: s.dailyHour, minute: 0));
                      if (t != null) {
                        await s.saveSettings(dailyHour: t.hour);
                        await _changed();
                      }
                    },
                  ),
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text(
                      'You also get a heads-up at 80% and 100% of each limit, 3 days before payday, and on payday morning.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Fills limits from last month's real spending, rounded up to the next R50.
  Future<void> _suggest(BuildContext context) async {
    final s = Store.instance;
    final last = s.byCategory(s.currentCycle.previous(s.payday, s.weekendToFriday));
    if (last.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Log a month of spending first, then Mali can suggest limits from it.')));
      return;
    }
    for (final e in last.entries) {
      final rounded = ((e.value + 4999) ~/ 5000) * 5000;
      await s.setBudget(e.key, rounded);
    }
    await _changed();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Limits set from last month. Tweak any that felt too high.')));
    }
  }

  Future<void> _editRecurring(BuildContext context, {Recurring? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final amount = TextEditingController(
        text: existing == null ? '' : (existing.cents / 100).toStringAsFixed(0));
    var category = existing?.category ?? 'debt';
    var day = existing?.day ?? 1;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Add debit order' : 'Edit debit order'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Vodacom contract'),
                ),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount', prefixText: 'R '),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final c in categories)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) => setLocal(() => category = v ?? category),
                ),
                DropdownButtonFormField<int>(
                  value: day,
                  decoration: const InputDecoration(labelText: 'Goes off on the'),
                  items: [
                    for (var d = 1; d <= 31; d++)
                      DropdownMenuItem(value: d, child: Text(_ordinal(d))),
                  ],
                  onChanged: (v) => setLocal(() => day = v ?? day),
                ),
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(onPressed: () => Navigator.pop(ctx, 'delete'), child: const Text('Delete')),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Save')),
          ],
        ),
      ),
    );

    final s = Store.instance;
    if (result == 'delete' && existing != null) {
      await s.deleteRecurring(existing.id);
    } else if (result == 'save') {
      final cents = parseRand(amount.text);
      if (name.text.trim().isEmpty || cents == null || cents == 0) return;
      await s.upsertRecurring(Recurring(
        id: existing?.id ?? s.newId(),
        name: name.text.trim(),
        cents: cents,
        category: category,
        day: day,
      ));
      await _changed();
    }
  }
}

String _ordinal(int d) {
  if (d >= 11 && d <= 13) return '${d}th';
  return switch (d % 10) { 1 => '${d}st', 2 => '${d}nd', 3 => '${d}rd', _ => '${d}th' };
}

/// Simple amount dialog. Returns cents, or null if cancelled.
Future<int?> askAmount(BuildContext context, String title, int current,
    {bool allowZero = false}) async {
  final c = TextEditingController(text: current == 0 ? '' : (current / 100).toStringAsFixed(0));
  final result = await showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          prefixText: 'R ',
          helperText: allowZero ? 'Leave empty for no limit' : null,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final v = parseRand(c.text) ?? (allowZero ? 0 : null);
            if (v == null) return;
            Navigator.pop(ctx, v);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  return result;
}
