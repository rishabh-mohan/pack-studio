import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'base_events.dart';
import 'base_events_screen.dart';
import 'event_editor_screen.dart';
import 'file_editor_screen.dart';
import 'own_events.dart';
import 'pack_storage.dart';
import 'theme.dart';

/// The Events tab. Its job is making your own events; the base game's are a
/// dropdown further down, to take as starting points.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, required this.pack, required this.storage});

  final PackEntry pack;
  final PackStorage storage;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  static const _file = 'events/events.json';

  late Future<_Loaded> _loaded = _load();

  /// Read apart from the events, so the list never waits on this large file.
  late final Future<BaseEventCatalog?> _catalog = BaseEventCatalog.load();

  Future<_Loaded> _load() async {
    var doc = <String, dynamic>{};
    try {
      final decoded = jsonDecode(await widget.storage.read(widget.pack, _file));
      if (decoded is Map<String, dynamic>) doc = decoded;
    } on PathNotFoundException {
      // No events file yet: nothing made so far.
    }
    return _Loaded(events: [for (final e in (doc['events'] as List? ?? const []).whereType<Map<String, dynamic>>()) e]);
  }

  void _reload() => setState(() {
    _loaded = _load();
  });

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) _reload();
  }

  Future<void> _remove(Map<String, dynamic> event) async {
    final name = '${event['name'] ?? ''}'.isEmpty ? 'Untitled event' : '${event['name']}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this event?'),
        content: Text('"$name" and its scenes will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final doc = jsonDecode(await widget.storage.read(widget.pack, _file)) as Map<String, dynamic>;
    await widget.storage.write(
      widget.pack,
      _file,
      '${const JsonEncoder.withIndent('  ').convert(deleteEvent(doc, (event['id'] as num).toInt()))}\n',
    );
    if (mounted) _reload();
  }

  String _describe(Map<String, dynamic> e) {
    if (!isOwnEvent(e)) return e[baseEventIdKey] != null ? 'From the base game' : 'Raw data';
    final s = e[studioKey] as Map;
    final steps = (s['steps'] as List?)?.length ?? 0;
    final when = s['onSetDay'] == true ? '${s['date']}' : 'Any day';
    return '$when · $steps ${steps == 1 ? 'step' : 'steps'}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: StudioColors.accent, foregroundColor: Colors.white, title: const Text('Events')),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('new-event'),
        backgroundColor: StudioColors.accent,
        foregroundColor: Colors.white,
        onPressed: () => _open(EventEditorScreen(pack: widget.pack, storage: widget.storage)),
        icon: const Icon(Icons.add),
        label: const Text('New event'),
      ),
      body: FutureBuilder<_Loaded>(
        future: _loaded,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('${snapshot.error}')));
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final loaded = snapshot.data!;
          final own = [for (final e in loaded.events) if (isOwnEvent(e)) e];
          final other = [for (final e in loaded.events) if (!isOwnEvent(e)) e];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              const Text('Your events', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: StudioColors.ink)),
              const SizedBox(height: 4),
              const Text(
                'Say when it happens and where, then add lines, choices and rewards one after another.',
                style: TextStyle(fontSize: 13, color: StudioColors.inkSoft),
              ),
              const SizedBox(height: 10),
              if (own.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Nothing here yet. Tap New event to write your first one.', style: TextStyle(color: StudioColors.inkSoft)),
                ),
              for (final e in own)
                _EventTile(
                  key: ValueKey('event:${e['id']}'),
                  title: '${e['name'] ?? ''}'.isEmpty ? 'Untitled event' : '${e['name']}',
                  subtitle: _describe(e),
                  icon: Icons.edit_note,
                  onTap: () => _open(EventEditorScreen(pack: widget.pack, storage: widget.storage, eventId: (e['id'] as num).toInt())),
                  onDelete: () => _remove(e),
                ),
              if (other.isNotEmpty) ...[
                const SizedBox(height: 16),
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    key: const ValueKey('other-events'),
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      '${other.length} other ${other.length == 1 ? 'event' : 'events'}',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: StudioColors.ink),
                    ),
                    subtitle: const Text('From the base game or written as raw data', style: TextStyle(fontSize: 12, color: StudioColors.inkSoft)),
                    children: [
                      for (final e in other)
                        _EventTile(
                          key: ValueKey('event:${e['id']}'),
                          title: '${e['name'] ?? ''}'.isEmpty ? 'Event ${e['id']}' : '${e['name']}',
                          subtitle: _describe(e),
                          icon: Icons.data_object,
                          onTap: () => _open(FileEditorScreen(pack: widget.pack, storage: widget.storage, relative: _file)),
                          onDelete: () => _remove(e),
                        ),
                    ],
                  ),
                ),
              ],
              FutureBuilder<BaseEventCatalog?>(
                future: _catalog,
                builder: (context, catalog) {
                  final data = catalog.data;
                  if (data == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        key: const ValueKey('base-game-events'),
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.auto_stories_outlined, color: StudioColors.accent),
                        title: const Text('Base-game events', style: TextStyle(fontWeight: FontWeight.w600, color: StudioColors.ink)),
                        subtitle: const Text('Tick events to copy in as starting points', style: TextStyle(fontSize: 12, color: StudioColors.inkSoft)),
                        children: [
                          BaseEventsPicker(pack: widget.pack, storage: widget.storage, catalog: data, onAdded: _reload),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Loaded {
  const _Loaded({required this.events});

  final List<Map<String, dynamic>> events;
}

class _EventTile extends StatelessWidget {
  const _EventTile({super.key, required this.title, required this.subtitle, required this.icon, required this.onTap, required this.onDelete});

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: StudioColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: StudioColors.panelBorder, width: 2)),
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon, color: StudioColors.accent),
          title: Text(title, style: const TextStyle(color: StudioColors.ink, fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: StudioColors.inkSoft)),
          trailing: IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: onDelete),
        ),
      ),
    );
  }
}
