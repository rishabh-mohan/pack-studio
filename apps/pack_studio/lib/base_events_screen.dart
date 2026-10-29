import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'base_events.dart';
import 'pack_storage.dart';
import 'theme.dart';

/// The base-game events as a list of tick boxes, for the Events tab's
/// dropdown. Events that belong together (the Beggar's four, or one that waits
/// for another to finish) are one tick box and are copied whole.
class BaseEventsPicker extends StatefulWidget {
  const BaseEventsPicker({
    super.key,
    required this.pack,
    required this.storage,
    required this.catalog,
    this.onAdded,
  });

  final PackEntry pack;
  final PackStorage storage;
  final BaseEventCatalog catalog;

  /// Runs after events were copied in, so the list around it can refresh.
  final VoidCallback? onAdded;

  @override
  State<BaseEventsPicker> createState() => _BaseEventsPickerState();
}

class _BaseEventsPickerState extends State<BaseEventsPicker> {
  final _selected = <String>{};
  final _search = TextEditingController();
  Set<int> _have = {};
  bool _loading = true;
  bool _adding = false;

  static const _eventsFile = 'events/events.json';
  static const _switchesFile = 'events/switches.json';
  static const _setsFile = 'events/sets.json';

  @override
  void initState() {
    super.initState();
    _refreshHave();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _read(String file, Map<String, dynamic> empty) async {
    try {
      final decoded = jsonDecode(await widget.storage.read(widget.pack, file));
      return decoded is Map<String, dynamic> ? decoded : empty;
    } on PathNotFoundException {
      return empty;
    }
  }

  Future<void> _refreshHave() async {
    final events = await _read(_eventsFile, {});
    if (!mounted) return;
    setState(() {
      _have = baseEventsIn(events);
      _loading = false;
    });
  }

  void _say(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 6)));

  Future<void> _add() async {
    setState(() => _adding = true);
    try {
      final result = addBaseEvents(
        eventsDoc: await _read(_eventsFile, {}),
        switchesDoc: await _read(_switchesFile, {}),
        setsDoc: await _read(_setsFile, {}),
        catalog: widget.catalog,
        groupIds: _selected,
      );
      const encoder = JsonEncoder.withIndent('  ');
      await widget.storage.write(widget.pack, _eventsFile, '${encoder.convert(result.events)}\n');
      if ((result.switches['switches'] as List?)?.isNotEmpty ?? false) {
        await widget.storage.write(widget.pack, _switchesFile, '${encoder.convert(result.switches)}\n');
      }
      if ((result.sets['eventSets'] as List?)?.isNotEmpty ?? false) {
        await widget.storage.write(widget.pack, _setsFile, '${encoder.convert(result.sets)}\n');
      }
      final problem = await widget.storage.check(widget.pack);
      _selected.clear();
      await _refreshHave();
      widget.onAdded?.call();
      if (!mounted) return;
      final renumbered = result.renumbered == 0
          ? ''
          : ' ${result.renumbered} got new ids because yours were taken.';
      _say(
        problem == null
            ? 'Added ${result.eventsAdded} events.$renumbered'
            : 'Added ${result.eventsAdded} events, but the pack does not load: $problem',
      );
    } on PackStorageException catch (e) {
      if (mounted) _say(e.message);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
    }
    final query = _search.text.trim().toLowerCase();
    final groups = [
      for (final g in widget.catalog.groups)
        if (query.isEmpty || g.names.any((n) => n.toLowerCase().contains(query))) g,
    ];
    final chosenEvents = [
      for (final g in widget.catalog.groups)
        if (_selected.contains(g.id)) ...g.eventIds,
    ].length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Events that belong together are one choice and are copied whole. '
            'Edit them afterwards like your own.',
            style: TextStyle(fontSize: 12, color: StudioColors.inkSoft),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            key: const ValueKey('base-events-search'),
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search base-game events',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('base-events-add'),
              onPressed: _selected.isEmpty || _adding ? null : _add,
              style: FilledButton.styleFrom(backgroundColor: StudioColors.accent),
              child: Text(
                _selected.isEmpty
                    ? 'Tick events to add'
                    : 'Add ${_selected.length} ${_selected.length == 1 ? 'choice' : 'choices'} ($chosenEvents events)',
              ),
            ),
          ),
        ),
        for (final g in groups)
          CheckboxListTile(
            key: ValueKey('base-event-group:${g.id}'),
            dense: true,
            activeColor: StudioColors.accent,
            value: groupIsIn(g, _have) || _selected.contains(g.id),
            onChanged: groupIsIn(g, _have)
                ? null
                : (on) => setState(() => on == true ? _selected.add(g.id) : _selected.remove(g.id)),
            title: Text(g.name, style: const TextStyle(color: StudioColors.ink, fontWeight: FontWeight.w600)),
            subtitle: Text(
              groupIsIn(g, _have)
                  ? 'Already in this pack'
                  : '${g.eventIds.length == 1 ? '1 event' : '${g.eventIds.length} events'}'
                        '${g.names.length > 1 ? ': ${g.names.take(4).join(', ')}${g.names.length > 4 ? '…' : ''}' : ''}',
              style: const TextStyle(fontSize: 12, color: StudioColors.inkSoft),
            ),
          ),
      ],
    );
  }
}
