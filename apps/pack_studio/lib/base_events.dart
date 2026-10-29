import 'dart:convert';

import 'package:flutter/services.dart';

/// kss16's events, offered as starting points (owner OK'd 2026-10-29).
///
/// The catalog is a local, gitignored asset made by
/// `d30mode-kss/tools/build_studio_events.py`; without it nothing here is
/// offered. Events come in groups an author would take together: one event
/// set (the Beggar's four events) plus events tied by an `EVENT_<id>` gate.
const baseEventsAsset = 'assets/kss16_events/catalog.json';

/// Written on each copied event: the id it has in the base game. Lets the
/// editor tell what is already in a pack even after its ids changed.
const baseEventIdKey = 'baseEventId';

class BaseEventGroup {
  const BaseEventGroup({
    required this.id,
    required this.name,
    required this.names,
    required this.eventIds,
  });

  final String id;
  final String name;

  /// Distinct event names in the group, first one being [name].
  final List<String> names;
  final List<int> eventIds;

  factory BaseEventGroup.fromJson(Map<String, dynamic> j) => BaseEventGroup(
    id: j['id'] as String,
    name: j['name'] as String,
    names: [for (final n in j['names'] as List) '$n'],
    eventIds: [for (final i in j['eventIds'] as List) (i as num).toInt()],
  );
}

class BaseEventCatalog {
  BaseEventCatalog({
    required this.groups,
    required this.events,
    required this.nodes,
    required this.switches,
    required this.speakers,
    required this.sets,
  });

  final List<BaseEventGroup> groups;
  final Map<int, Map<String, dynamic>> events;
  final Map<int, Map<String, dynamic>> nodes;
  final List<Map<String, dynamic>> switches;
  final List<Map<String, dynamic>> speakers;
  final Map<int, Map<String, dynamic>> sets;

  factory BaseEventCatalog.fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> list(String key) =>
        (j[key] as List? ?? const []).cast<Map<String, dynamic>>();
    Map<int, Map<String, dynamic>> byId(String key) => {
      for (final m in list(key)) (m['id'] as num).toInt(): m,
    };
    return BaseEventCatalog(
      groups: [for (final g in list('groups')) BaseEventGroup.fromJson(g)],
      events: byId('events'),
      nodes: byId('nodes'),
      switches: list('switches'),
      speakers: list('speakers'),
      sets: byId('sets'),
    );
  }

  /// The bundled catalog, or null when this build does not carry one.
  static Future<BaseEventCatalog?> load([AssetBundle? bundle]) async {
    try {
      // Decoded here rather than by loadString, which hands a file this big to
      // another isolate for no gain.
      final bytes = await (bundle ?? rootBundle).load(baseEventsAsset);
      final text = utf8.decode(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
      return BaseEventCatalog.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  /// Every scene [eventId] can reach from its first one.
  Set<int> sceneIds(int eventId) {
    final seen = <int>{};
    final todo = [(events[eventId]?['rootNodeId'] as num?)?.toInt() ?? -1];
    while (todo.isNotEmpty) {
      final id = todo.removeLast();
      final node = nodes[id];
      if (node == null || !seen.add(id)) continue;
      for (final key in const ['nextNodeId', 'nextNodeIdIfTrue', 'nextNodeIdIfFalse']) {
        final next = node[key];
        if (next is num) todo.add(next.toInt());
      }
      for (final o in (node['options'] as List? ?? const [])) {
        final next = o is Map ? o['nextNodeId'] : null;
        if (next is num) todo.add(next.toInt());
      }
    }
    return seen;
  }
}

/// What [addBaseEvents] produced: the three documents to write back, and what
/// happened.
class BaseEventsResult {
  BaseEventsResult({
    required this.events,
    required this.switches,
    required this.sets,
    required this.groupsAdded,
    required this.eventsAdded,
    required this.renumbered,
  });

  /// `events/events.json`, `events/switches.json`, `events/sets.json`.
  final Map<String, dynamic> events;
  final Map<String, dynamic> switches;
  final Map<String, dynamic> sets;
  final int groupsAdded;
  final int eventsAdded;

  /// Groups that had to take new ids because the pack already used theirs.
  final int renumbered;
}

/// Base-game event ids already copied into a pack's `events.json`.
Set<int> baseEventsIn(Map<String, dynamic> eventsDoc) => {
  for (final e in eventsDoc['events'] as List? ?? const [])
    if (e is Map && e[baseEventIdKey] is num) (e[baseEventIdKey] as num).toInt(),
};

/// Whether every event of [group] is already in the pack.
bool groupIsIn(BaseEventGroup group, Set<int> have) =>
    group.eventIds.every(have.contains);

final _eventRef = RegExp(r'^EVENT_(\d+)$');

/// Copies the chosen groups into a pack's event documents and returns the
/// updated documents; the inputs are not changed. Anything the pack already
/// has wins: a group whose event or scene ids are taken is renumbered whole
/// (events, scenes, event sets, and the `EVENT_<id>` names that gates and
/// effects use), a speaker or switch the pack already declares is left as is,
/// and a group already copied is skipped.
BaseEventsResult addBaseEvents({
  required Map<String, dynamic> eventsDoc,
  required Map<String, dynamic> switchesDoc,
  required Map<String, dynamic> setsDoc,
  required BaseEventCatalog catalog,
  required Iterable<String> groupIds,
}) {
  Map<String, dynamic> copy(Map<String, dynamic> m) =>
      jsonDecode(jsonEncode(m)) as Map<String, dynamic>;
  final events = copy(eventsDoc);
  final switches = copy(switchesDoc);
  final sets = copy(setsDoc);
  final eventList = [...(events['events'] as List? ?? const [])];
  final nodeList = [...(events['nodes'] as List? ?? const [])];
  final speakerList = [...(events['speakers'] as List? ?? const [])];
  final switchList = [...(switches['switches'] as List? ?? const [])];
  final setList = [...(sets['eventSets'] as List? ?? const [])];

  int idOf(Object? m) => m is Map && m['id'] is num ? (m['id'] as num).toInt() : 0;
  final usedEvents = {for (final e in eventList) idOf(e)};
  final usedNodes = {for (final n in nodeList) idOf(n)};
  final usedSets = {for (final s in setList) idOf(s)};
  final usedSpeakers = {for (final s in speakerList) idOf(s)};
  final usedSwitches = {
    for (final s in switchList)
      if (s is Map) s['name'],
  };
  final have = baseEventsIn(events);
  final switchNames = {for (final s in catalog.switches) s['name'] as String};

  int next(Set<int> used) =>
      used.isEmpty ? 1 : used.reduce((a, b) => a > b ? a : b) + 1;

  var groupsAdded = 0, eventsAdded = 0, renumbered = 0;
  final wanted = groupIds.toSet();
  for (final group in catalog.groups) {
    if (!wanted.contains(group.id) || group.eventIds.any(have.contains)) continue;

    final sceneIds = <int>{for (final id in group.eventIds) ...catalog.sceneIds(id)};
    final eventClash = group.eventIds.any(usedEvents.contains);
    final sceneClash = sceneIds.any(usedNodes.contains);

    final eventMap = <int, int>{for (final id in group.eventIds) id: id};
    final sceneMap = <int, int>{for (final id in sceneIds) id: id};
    if (eventClash) {
      for (final id in group.eventIds) {
        eventMap[id] = next(usedEvents);
        usedEvents.add(eventMap[id]!);
      }
    }
    if (sceneClash) {
      for (final id in sceneIds.toList()..sort()) {
        sceneMap[id] = next(usedNodes);
        usedNodes.add(sceneMap[id]!);
      }
    }
    if (eventClash || sceneClash) renumbered++;

    // Event sets: reuse an identical one, otherwise add it, renumbered if its
    // id is taken by a different set.
    final setMap = <int, int>{};
    for (final id in group.eventIds) {
      final setId = (catalog.events[id]!['eventSetId'] as num?)?.toInt();
      if (setId == null || setMap.containsKey(setId)) continue;
      final source = catalog.sets[setId];
      final existing = setList.cast<Map?>().firstWhere(
        (s) => s != null && idOf(s) == setId && s['name'] == source?['name'],
        orElse: () => null,
      );
      if (existing != null || source == null) {
        setMap[setId] = setId;
      } else {
        final newId = usedSets.contains(setId) ? next(usedSets) : setId;
        setMap[setId] = newId;
        usedSets.add(newId);
        setList.add({...source, 'id': newId});
      }
    }

    Object? remap(Object? v) {
      if (v is Map) {
        return <String, dynamic>{
          for (final e in v.entries) '${e.key}': remap(e.value),
        };
      }
      if (v is List) return [for (final x in v) remap(x)];
      if (v is String) {
        final m = _eventRef.firstMatch(v);
        final to = m == null ? null : eventMap[int.parse(m[1]!)];
        return to == null ? v : 'EVENT_$to';
      }
      return v;
    }

    void collect(Object? v, Set<String> out) {
      if (v is Map) {
        for (final x in v.values) {
          collect(x, out);
        }
      } else if (v is List) {
        for (final x in v) {
          collect(x, out);
        }
      } else if (v is String && switchNames.contains(v) && !_eventRef.hasMatch(v)) {
        out.add(v);
      }
    }

    int? mapped(Object? v, Map<int, int> by) =>
        v is num ? (by[v.toInt()] ?? v.toInt()) : null;

    final switchesUsed = <String>{};
    final speakersUsed = <int>{};
    for (final sceneId in sceneIds.toList()..sort()) {
      final node = remap(catalog.nodes[sceneId]) as Map<String, dynamic>;
      collect(node, switchesUsed);
      if (node['speakerId'] is num) speakersUsed.add((node['speakerId'] as num).toInt());
      node['id'] = sceneMap[sceneId];
      for (final key in const ['nextNodeId', 'nextNodeIdIfTrue', 'nextNodeIdIfFalse']) {
        if (node[key] != null) node[key] = mapped(node[key], sceneMap);
      }
      for (final o in (node['options'] as List? ?? const [])) {
        if (o is Map && o['nextNodeId'] != null) {
          o['nextNodeId'] = mapped(o['nextNodeId'], sceneMap);
        }
      }
      nodeList.add(node);
      usedNodes.add(sceneMap[sceneId]!);
    }
    for (final id in group.eventIds) {
      final event = remap(catalog.events[id]) as Map<String, dynamic>;
      collect(event, switchesUsed);
      event['id'] = eventMap[id];
      event['rootNodeId'] = mapped(event['rootNodeId'], sceneMap);
      if (event['eventSetId'] != null) {
        event['eventSetId'] = mapped(event['eventSetId'], setMap);
      }
      event[baseEventIdKey] = id;
      eventList.add(event);
      usedEvents.add(eventMap[id]!);
    }

    for (final name in switchesUsed) {
      if (usedSwitches.add(name)) {
        switchList.add(
          Map<String, dynamic>.of(
            catalog.switches.firstWhere((s) => s['name'] == name),
          ),
        );
      }
    }
    for (final speaker in catalog.speakers) {
      final id = idOf(speaker);
      if (speakersUsed.contains(id) && usedSpeakers.add(id)) {
        speakerList.add(Map<String, dynamic>.of(speaker));
      }
    }
    groupsAdded++;
    eventsAdded += group.eventIds.length;
  }

  events['events'] = eventList;
  events['nodes'] = nodeList;
  if (speakerList.isNotEmpty) events['speakers'] = speakerList;
  if (switchList.isNotEmpty) switches['switches'] = switchList;
  if (setList.isNotEmpty) sets['eventSets'] = setList;
  return BaseEventsResult(
    events: events,
    switches: switches,
    sets: sets,
    groupsAdded: groupsAdded,
    eventsAdded: eventsAdded,
    renumbered: renumbered,
  );
}
