import 'package:flutter/material.dart';

import '../money.dart';
import '../notify.dart';
import '../store.dart';

/// Quick add: amount, tap a category, done. Also used to edit an expense.
Future<void> showAddSheet(BuildContext context, {Expense? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AddSheet(existing: existing),
  );
}

class _AddSheet extends StatefulWidget {
  const _AddSheet({this.existing});
  final Expense? existing;

  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  late final _amount = TextEditingController(
      text: widget.existing == null ? '' : (widget.existing!.cents / 100).toStringAsFixed(2).replaceAll('.00', ''));
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late String? _category = widget.existing?.category;
  late DateTime _date = widget.existing?.date ?? DateTime.now();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save([String? tapped]) async {
    final category = tapped ?? _category;
    final cents = parseRand(_amount.text);
    if (cents == null || cents == 0) {
      setState(() => _error = 'Type how much you spent first');
      return;
    }
    if (category == null) {
      setState(() => _error = 'Tap a category');
      return;
    }
    final store = Store.instance;
    final e = widget.existing ??
        Expense(id: store.newId(), cents: cents, category: category, date: _date);
    e
      ..cents = cents
      ..category = category
      ..date = _date
      ..note = _note.text.trim();
    await store.upsertExpense(e);
    await Notify.instance.refresh();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (d != null && mounted) setState(() => _date = DateTime(d.year, d.month, d.day, 12));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final editing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _amount,
              autofocus: !editing,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                prefixText: 'R ',
                hintText: '0',
                border: InputBorder.none,
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _note,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Note (optional): e.g. taxi to work',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.event, size: 18),
                  label: Text(dayLabel(_date)),
                  onPressed: _pickDate,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(editing ? 'Category' : 'Tap a category to save',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.95,
              children: [
                for (final c in categories)
                  _CategoryButton(
                    category: c,
                    selected: _category == c.id,
                    onTap: () {
                      setState(() => _category = c.id);
                      if (!editing) _save(c.id);
                    },
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: scheme.error), textAlign: TextAlign.center),
            ],
            if (editing) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: () => _save(), child: const Text('Save')),
              TextButton.icon(
                onPressed: () async {
                  await Store.instance.deleteExpense(widget.existing!.id);
                  await Notify.instance.refresh();
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({required this.category, required this.selected, required this.onTap});
  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = category.color;
    return Material(
      color: selected ? c.withValues(alpha: 0.28) : c.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(category.icon, color: c),
              const SizedBox(height: 4),
              Text(
                category.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, height: 1.1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
