import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/events.dart';
import '../../models/listing.dart';
import '../../providers.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

/// Port of `LandlordSchedule.swift`.
class LandlordSchedule extends ConsumerStatefulWidget {
  const LandlordSchedule({super.key});

  @override
  ConsumerState<LandlordSchedule> createState() => _LandlordScheduleState();
}

class _LandlordScheduleState extends ConsumerState<LandlordSchedule> {
  DateTime _selected = DateTime.now();

  void _openForm([ScheduleEvent? existing]) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => ScheduleEventSheet(existing: existing),
      );

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(landlordEventsProvider);
    final listings = ref.watch(landlordListingsProvider).value ?? [];
    final onDay = (events.value ?? [])
        .where((e) => isSameDay(e.startAt, _selected))
        .toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: QColors.blue,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        onPressed: _openForm,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
          children: [
            const Text('Scheduler',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            const Text('Select a date',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.black54)),
            const SizedBox(height: 10),
            QCard(
              padding: EdgeInsets.zero,
              child: CalendarDatePicker(
                initialDate: _selected,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                onDateChanged: (d) => setState(() => _selected = d),
              ),
            ),
            const SizedBox(height: 14),
            QCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle('Appointments'),
                    if (events.hasError)
                      Text('${events.error}',
                          style: const TextStyle(color: Colors.red))
                    else if (onDay.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('No events on this day',
                            style: TextStyle(color: Colors.black54)),
                      ),
                    for (final e in onDay)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                              color: QColors.blue.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.calendar_today,
                              color: QColors.blue),
                        ),
                        title: Text(e.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_addressFor(e, listings),
                                  style: const TextStyle(
                                      fontSize: 12, color: QColors.blue)),
                              Text(formatEventTime(e),
                                  style: const TextStyle(fontSize: 11)),
                            ]),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                              icon: const Icon(Icons.edit, color: QColors.blue),
                              onPressed: () => _openForm(e)),
                          IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => ref
                                  .read(scheduleRepoProvider)
                                  .deleteEvent(e.id)),
                        ]),
                      ),
                  ]),
            ),
          ],
        ),
      ),
    );
  }

  String _addressFor(ScheduleEvent e, List<Listing> listings) {
    if (e.scopeAll) return 'All Properties';
    if (e.listingIds.isEmpty) return 'No linked property';
    final matched =
        listings.where((l) => e.listingIds.contains(l.listingId)).toList();
    if (matched.isEmpty) return 'Multiple Properties';
    if (matched.length == 1) return matched.first.address;
    return '${matched.first.address} + ${matched.length - 1} more';
  }
}

/// Lets the landlord pick "All my properties" or specific listings.
class ListingScopePicker extends StatelessWidget {
  const ListingScopePicker({
    super.key,
    required this.listings,
    required this.scopeAll,
    required this.selected,
    required this.onScopeChanged,
    required this.onToggle,
  });

  final List<Listing> listings;
  final bool scopeAll;
  final Set<String> selected;
  final ValueChanged<bool> onScopeChanged;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      RadioGroup<bool>(
        groupValue: scopeAll,
        onChanged: (v) => onScopeChanged(v ?? true),
        child: const Column(children: [
          RadioListTile(
              value: true,
              contentPadding: EdgeInsets.zero,
              title: Text('All my properties')),
          RadioListTile(
              value: false,
              contentPadding: EdgeInsets.zero,
              title: Text('Specific properties')),
        ]),
      ),
      if (!scopeAll) ...[
        for (final l in listings)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: selected.contains(l.listingId),
            onChanged: (_) => onToggle(l.listingId),
            title: Text(l.address.isEmpty ? 'Untitled' : l.address),
            subtitle: l.listingName.isEmpty ? null : Text(l.listingName),
          ),
        if (listings.isEmpty)
          const Text('No listings yet. Add listings in the Listings tab.',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    ]);
  }
}

/// Port of `NewScheduleEventView.swift`.
class ScheduleEventSheet extends ConsumerStatefulWidget {
  const ScheduleEventSheet({super.key, this.existing});
  final ScheduleEvent? existing;

  @override
  ConsumerState<ScheduleEventSheet> createState() => _ScheduleEventSheetState();
}

class _ScheduleEventSheetState extends ConsumerState<ScheduleEventSheet> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _notes = TextEditingController(text: widget.existing?.notes);
  late DateTime _start = widget.existing?.startAt ?? DateTime.now();
  late DateTime _end =
      widget.existing?.endAt ?? DateTime.now().add(const Duration(hours: 1));
  late bool _allDay = widget.existing?.allDay ?? false;
  late bool _scopeAll = widget.existing?.scopeAll ?? true;
  late final Set<String> _selected = {...?widget.existing?.listingIds};
  String? _error;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime initial, {required bool withTime}) async {
    final d = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100));
    if (d == null || !withTime || !mounted) return d;
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _save() async {
    var start = _start, end = _end;
    if (_allDay) {
      start = DateTime(_start.year, _start.month, _start.day);
      end = start.add(const Duration(seconds: 86400 - 1));
    }
    if (!end.isAfter(start)) {
      setState(() => _error = 'End must be after start.');
      return;
    }
    if (!_scopeAll && _selected.isEmpty) {
      setState(() => _error =
          "Select at least one property, or choose 'All my properties'.");
      return;
    }
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final listings = ref.read(landlordListingsProvider).value ?? [];
    await ref.read(scheduleRepoProvider).saveEvent(
          id: widget.existing?.id,
          landlordId: uid,
          title: _title.text,
          notes: _notes.text,
          startAt: start,
          endAt: end,
          allDay: _allDay,
          scopeAll: _scopeAll,
          listingIds: _scopeAll
              ? listings.map((l) => l.listingId).toList()
              : _selected.toList(),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final listings = ref.watch(landlordListingsProvider).value ?? [];
    final fmt = _allDay ? DateFormat.yMMMd() : DateFormat.yMMMd().add_jm();

    return SheetScaffold(
      title: widget.existing == null ? 'New Schedule' : 'Edit Schedule',
      actionLabel: widget.existing == null ? 'Save' : 'Update',
      onAction: _title.text.trim().isEmpty ? null : _save,
      children: [
        const SheetHeader('Event'),
        TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title')),
        TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Notes (optional)')),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('All day'),
          value: _allDay,
          onChanged: (v) => setState(() => _allDay = v),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_allDay ? 'Date' : 'Start'),
          trailing: Text(fmt.format(_start)),
          onTap: () async {
            final d = await _pick(_start, withTime: !_allDay);
            if (d != null) setState(() => _start = d);
          },
        ),
        if (!_allDay)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('End'),
            trailing: Text(fmt.format(_end)),
            onTap: () async {
              final d = await _pick(_end, withTime: true);
              if (d != null) setState(() => _end = d);
            },
          ),
        const SheetHeader('Visible to'),
        ListingScopePicker(
          listings: listings,
          scopeAll: _scopeAll,
          selected: _selected,
          onScopeChanged: (v) => setState(() {
            _scopeAll = v;
            if (v) _selected.clear();
          }),
          onToggle: (id) => setState(
              () => _selected.contains(id) ? _selected.remove(id) : _selected.add(id)),
        ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
      ],
    );
  }
}

class SheetHeader extends StatelessWidget {
  const SheetHeader(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Text(text.toUpperCase(),
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
      );
}

/// Bottom-sheet form chrome: Cancel / title / action, like the SwiftUI
/// sheets with `.cancellationAction` and `.confirmationAction`.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.onAction,
    required this.children,
  });

  final String title;
  final String actionLabel;
  final VoidCallback? onAction;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            Expanded(
              child: Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            TextButton(onPressed: onAction, child: Text(actionLabel)),
          ]),
          const Divider(height: 1),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: children,
            ),
          ),
        ]),
      );
}
