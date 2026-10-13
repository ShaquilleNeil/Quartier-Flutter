import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import 'landlord_schedule.dart';

/// Port of `NewNoticeView.swift`: send a notice to all, or selected,
/// properties.
class NewNoticeSheet extends ConsumerStatefulWidget {
  const NewNoticeSheet({super.key});

  @override
  ConsumerState<NewNoticeSheet> createState() => _NewNoticeSheetState();
}

class _NewNoticeSheetState extends ConsumerState<NewNoticeSheet> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _scopeAll = true;
  final Set<String> _selected = {};
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_scopeAll && _selected.isEmpty) {
      setState(() => _error =
          "Select at least one property, or use 'All my properties'.");
      return;
    }
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final listings = ref.read(landlordListingsProvider).value ?? [];
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(scheduleRepoProvider).sendNotice(
            landlordId: uid,
            title: _title.text.trim(),
            body: _body.text.trim(),
            scopeAll: _scopeAll,
            listingIds: _scopeAll
                ? listings.map((l) => l.listingId).toList()
                : _selected.toList(),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = '$e';
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final listings = ref.watch(landlordListingsProvider).value ?? [];
    return SheetScaffold(
      title: 'Send Notice',
      actionLabel: 'Send',
      onAction: _sending || _title.text.trim().isEmpty ? null : _send,
      children: [
        const SheetHeader('Notice'),
        TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title')),
        TextField(
            controller: _body,
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(labelText: 'Message')),
        const SheetHeader('Send to'),
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
