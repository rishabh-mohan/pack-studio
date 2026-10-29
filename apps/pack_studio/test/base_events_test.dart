import 'dart:convert';
import 'dart:io';

import 'package:d30_engine/d30_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_studio/base_events.dart';

/// A made-up catalog: group gA is two events of one set (the second waits for
/// the first to finish and uses a switch and a speaker), gB is a lone event.
BaseEventCatalog catalog() => BaseEventCatalog.fromJson({
  'groups': [
    {'id': 'gA', 'name': 'Alpha', 'names': ['Alpha', 'Alpha Two'], 'eventIds': [1, 2]},
    {'id': 'gB', 'name': 'Bravo', 'names': ['Bravo'], 'eventIds': [3]},
  ],
  'events': [
    {'id': 1, 'name': 'Alpha', 'rootNodeId': 100, 'eventSetId': 5, 'note': 'extra field'},
    {
      'id': 2,
      'name': 'Alpha Two',
      'rootNodeId': 200,
      'eventSetId': 5,
      'conditionSet': {
        'conditions': [
          {'target': 'EVENT_1', 'compareType': 'equal', 'value': 2, 'targetType': 'event'},
        ],
      },
    },
    {'id': 3, 'name': 'Bravo', 'rootNodeId': 300},
  ],
  'nodes': [
    {'id': 100, 'type': 'text', 'text': 'one', 'nextNodeId': 101},
    {'id': 101, 'type': 'last', 'changer': {'target': 'EVENT_1', 'value': 2}},
    {
      'id': 200,
      'type': 'choice',
      'text': 'two',
      'speakerId': 7,
      'options': [
        {'text': 'yes', 'nextNodeId': 201},
        {'text': 'no', 'nextNodeId': 202},
      ],
    },
    {'id': 201, 'type': 'last', 'changer': {'target': 'GIVE_POOR', 'value': 1}},
    {'id': 202, 'type': 'last'},
    {'id': 300, 'type': 'last'},
  ],
  'switches': [
    {'name': 'GIVE_POOR', 'value': 0},
    {'name': 'UNUSED', 'value': 0},
  ],
  'speakers': [
    {'id': 7, 'name': 'Beggar'},
    {'id': 8, 'name': 'Nobody'},
  ],
  'sets': [
    {'id': 5, 'name': 'begging', 'rank': 'C', 'weight': 1},
  ],
});

Map<String, dynamic> add(
  Iterable<String> ids, {
  Map<String, dynamic> events = const {},
  Map<String, dynamic> sets = const {},
  Map<String, dynamic> switches = const {},
}) {
  final r = addBaseEvents(
    eventsDoc: events,
    switchesDoc: switches,
    setsDoc: sets,
    catalog: catalog(),
    groupIds: ids,
  );
  return {'result': r};
}

List<Map<String, dynamic>> listOf(Map<String, dynamic> doc, String key) =>
    [for (final e in doc[key] as List) e as Map<String, dynamic>];

void main() {
  test('a group is copied whole into an empty pack, with what it needs', () {
    final r = add(['gA'])['result'] as BaseEventsResult;
    expect(r.groupsAdded, 1);
    expect(r.eventsAdded, 2);
    expect(r.renumbered, 0);
    final events = listOf(r.events, 'events');
    expect(events.map((e) => e['id']), [1, 2]);
    expect(events.map((e) => e[baseEventIdKey]), [1, 2]);
    expect(events.first['note'], 'extra field'); // unknown fields travel along
    expect(listOf(r.events, 'nodes').map((n) => n['id']), [100, 101, 200, 201, 202]);
    expect(listOf(r.events, 'speakers').map((s) => s['id']), [7]); // 8 is not used
    expect(listOf(r.switches, 'switches').map((s) => s['name']), ['GIVE_POOR']);
    expect(listOf(r.sets, 'eventSets').map((s) => s['id']), [5]);
  });

  test('inputs are not changed and a group already in the pack is skipped', () {
    final first = add(['gA'])['result'] as BaseEventsResult;
    final before = jsonEncode(first.events);
    final again = addBaseEvents(
      eventsDoc: first.events,
      switchesDoc: first.switches,
      setsDoc: first.sets,
      catalog: catalog(),
      groupIds: ['gA', 'gB'],
    );
    expect(jsonEncode(first.events), before);
    expect(again.groupsAdded, 1); // only gB
    expect(listOf(again.events, 'events').map((e) => e['id']), [1, 2, 3]);
    final have = baseEventsIn(again.events);
    expect(groupIsIn(catalog().groups[0], have), isTrue);
    expect(groupIsIn(catalog().groups[1], have), isTrue);
    expect(groupIsIn(catalog().groups[1], baseEventsIn(first.events)), isFalse);
  });

  test('taken ids renumber the whole group and keep every reference consistent', () {
    final own = {
      'events': [
        {'id': 1, 'name': 'Mine', 'rootNodeId': 100},
        {'id': 2, 'name': 'Mine too', 'rootNodeId': 101},
      ],
      'nodes': [
        {'id': 100, 'type': 'last', 'text': 'my one'},
        {'id': 101, 'type': 'last', 'text': 'my two'},
      ],
      'speakers': [
        {'id': 7, 'name': 'My own seven'},
      ],
    };
    final ownSets = {
      'eventSets': [
        {'id': 5, 'name': 'mine', 'rank': 'C', 'weight': 1},
      ],
    };
    final r = add(['gA'], events: own, sets: ownSets)['result'] as BaseEventsResult;
    expect(r.renumbered, 1);
    final events = listOf(r.events, 'events');
    final nodes = {for (final n in listOf(r.events, 'nodes')) n['id']: n};

    // The pack's own content is untouched.
    expect(events.take(2).map((e) => e['name']), ['Mine', 'Mine too']);
    expect(nodes[100]!['text'], 'my one');
    expect(nodes[101]!['text'], 'my two');
    expect(listOf(r.events, 'speakers').single['name'], 'My own seven'); // pack wins

    final alpha = events[2], alphaTwo = events[3];
    expect({alpha['id'], alphaTwo['id']}, {3, 4});
    expect(alpha[baseEventIdKey], 1);
    expect(alphaTwo[baseEventIdKey], 2);
    // The second event's gate now names the first event's new id.
    final gate = (alphaTwo['conditionSet'] as Map)['conditions'][0] as Map;
    expect(gate['target'], 'EVENT_${alpha['id']}');
    // Scenes link to the renumbered scenes.
    final root = nodes[alpha['rootNodeId']]!;
    expect(nodes.containsKey(root['nextNodeId']), isTrue);
    expect(root['nextNodeId'], isNot(101));
    expect((nodes[root['nextNodeId']]!['changer'] as Map)['target'], 'EVENT_${alpha['id']}');
    final choice = nodes[alphaTwo['rootNodeId']]!;
    for (final o in choice['options'] as List) {
      expect(nodes.containsKey((o as Map)['nextNodeId']), isTrue);
    }
    // The set had a different owner of id 5, so it was added under a new id.
    final sets = listOf(r.sets, 'eventSets');
    expect(sets.length, 2);
    expect(sets.last['name'], 'begging');
    expect(sets.last['id'], isNot(5));
    expect(alpha['eventSetId'], sets.last['id']);
    expect(alphaTwo['eventSetId'], sets.last['id']);
  });

  test('a pack that already declares a switch keeps its own', () {
    final r = add(
      ['gA'],
      switches: {
        'switches': [
          {'name': 'GIVE_POOR', 'value': 1},
        ],
      },
    )['result'] as BaseEventsResult;
    final switches = listOf(r.switches, 'switches');
    expect(switches.length, 1);
    expect(switches.single['value'], 1);
  });

  test('the result is a pack the engine loads', () {
    final dir = Directory('assets/workshop');
    final files = {
      for (final f in dir.listSync(recursive: true).whereType<File>())
        f.path.substring(dir.path.length + 1).replaceAll(r'\', '/'): f.readAsStringSync(),
    };
    final r = add(['gA', 'gB'])['result'] as BaseEventsResult;
    files['events/events.json'] = jsonEncode(r.events);
    files['events/switches.json'] = jsonEncode(r.switches);
    files['events/sets.json'] = jsonEncode(r.sets);
    final pack = ContentPack.fromFiles(files);
    expect(pack.events.keys, containsAll([1, 2, 3]));
    expect(pack.nodes.length, 6);
    expect(pack.eventSets.length, 1);
    expect(pack.switchDefaults.keys, contains('GIVE_POOR'));
  });
}
