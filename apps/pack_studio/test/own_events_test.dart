import 'dart:convert';
import 'dart:io';

import 'package:d30_engine/d30_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_studio/own_events.dart';

OwnEvent sample({int id = 1}) => OwnEvent(
  id: id,
  name: 'The lost wallet',
  steps: [
    LineStep(speakerId: 2, text: 'Is this yours?'),
    ChoiceStep(
      question: 'Keep it?',
      options: [
        ChoiceOption(label: 'Hand it in', replySpeakerId: 0, reply: 'Honesty first.'),
        ChoiceOption(label: 'Keep it'),
      ],
    ),
    RewardStep(kind: RewardKind.money, amount: 200),
  ],
);

Map<int, Map<String, dynamic>> byId(Map<String, dynamic> doc) => {
  for (final n in (doc['nodes'] as List).cast<Map<String, dynamic>>()) (n['id'] as int): n,
};

Set<int> reach(Map<String, dynamic> doc, int root) {
  final nodes = byId(doc);
  final seen = <int>{};
  final todo = [root];
  while (todo.isNotEmpty) {
    final id = todo.removeLast();
    final n = nodes[id];
    if (n == null || !seen.add(id)) continue;
    for (final key in ['nextNodeId', 'nextNodeIdIfTrue', 'nextNodeIdIfFalse']) {
      if (n[key] is int) todo.add(n[key] as int);
    }
    for (final o in (n['options'] as List? ?? const []).cast<Map>()) {
      if (o['nextNodeId'] is int) todo.add(o['nextNodeId'] as int);
    }
  }
  return seen;
}

void main() {
  test('steps become linked scenes ending in a closing one', () {
    final doc = saveOwnEvent({}, sample());
    final event = (doc['events'] as List).single as Map<String, dynamic>;
    final nodes = byId(doc);
    expect(nodes.keys.toList(), [1001, 1002, 1003, 1004, 1005]);
    expect(event['rootNodeId'], 1001);
    // Every scene is reachable from the first, and every link lands.
    expect(reach(doc, 1001), nodes.keys.toSet());
    expect(nodes[1001]!['text'], 'Is this yours?');
    expect(nodes[1001]!['speakerId'], 2);
    expect(nodes[1001]!['nextNodeId'], 1002);
    final choice = nodes[1002]!;
    expect(choice['type'], 'option');
    final options = (choice['options'] as List).cast<Map>();
    expect(options[0]['nextNodeId'], 1003); // answer with a reply
    expect(nodes[1003]!['text'], 'Honesty first.');
    expect(nodes[1003]!['nextNodeId'], 1004); // rejoins at the reward
    expect(options[1]['nextNodeId'], 1004); // answer with no reply goes straight on
    final reward = nodes[1004]!;
    expect(reward['changer'], {'funcCode': 'INCREASE_MONEY', 'args': [200], 'changes': <Object>[]});
    expect(reward['text'], 'You got 200 Gold.');
    expect(reward['nextNodeId'], 1005);
    expect(nodes[1005]!['type'], 'last');
  });

  test('rewards write the verbs d30mode runs', () {
    RewardStep r(RewardKind k) => RewardStep(kind: k, amount: 5, subjectIndex: 1);
    final e = OwnEvent(id: 3, name: 'x', steps: [r(RewardKind.stamina), r(RewardKind.stat), r(RewardKind.allStats)]);
    final scenes = buildScenes(e, taken: {}, subjects: ['korean', 'maths']);
    expect(scenes[0]['changer']['funcCode'], 'INCREASE_HP');
    expect(scenes[1]['changer'], {'funcCode': 'INCREASE_STAT', 'args': [1, 5], 'changes': <Object>[]});
    expect(scenes[1]['text'], 'Your maths went up by 5.');
    expect(scenes[2]['changer']['funcCode'], 'INCREASE_STAT_ALL');
  });

  test('the gate is once-only, here and on that day, as the data writes it', () {
    final e = sample(id: 7)
      ..locationId = 1000
      ..onSetDay = true
      ..date = '2023/10/16';
    final doc = saveOwnEvent({}, e);
    final event = (doc['events'] as List).single as Map<String, dynamic>;
    expect(event['isRandomDate'], isFalse);
    final conditions = (event['conditionSet']['right']['conditions'] as List).cast<Map>();
    expect(conditions.map((c) => '${c['targetType']} ${c['target']} ${c['value']}'), [
      'event EVENT_7 0',
      'location LOCATION_1000 1',
      'date DATE_2023101600 1',
    ]);
    expect(event['conditionSet']['operator'], 'and');
    // A chosen time of day is the last two digits of the date, as the data writes it.
    e.tick = 4;
    var tick = (saveOwnEvent(doc, e)['events'] as List).single['conditionSet']['right']['conditions'] as List;
    expect(tick.last['target'], 'DATE_2023101604');
    e.tick = 14; // the evening
    tick = (saveOwnEvent(doc, e)['events'] as List).single['conditionSet']['right']['conditions'] as List;
    expect(tick.last['target'], 'DATE_2023101614');
    expect(problemWith(e), isNull);
    expect(problemWith(e..tick = 15), 'Pick a time of day.');
    expect(OwnEvent.fromEvent((saveOwnEvent(doc, e..tick = 9)['events'] as List).single as Map<String, dynamic>).tick, 9);
    e.tick = 0;
    e
      ..once = false
      ..locationId = null
      ..onSetDay = false;
    final random = (saveOwnEvent(doc, e)['events'] as List).single as Map;
    expect(random['isRandomDate'], isTrue);
    expect(random['conditionSet']['right']['conditions'], isEmpty);
  });

  test('editing replaces the event\'s scenes, keeps other things, and round-trips', () {
    var doc = <String, dynamic>{
      'note': 'mine',
      'speakers': [
        {'id': 2, 'name': 'Mara'},
      ],
      'events': [
        {'id': 50, 'name': 'Other', 'rootNodeId': 50001, 'extra': 1},
      ],
      'nodes': [
        {'id': 50001, 'type': 'last'},
      ],
    };
    doc = saveOwnEvent(doc, sample(id: 51));
    expect(doc['note'], 'mine');
    final stored = (doc['events'] as List).last as Map<String, dynamic>;
    final again = OwnEvent.fromEvent(stored);
    expect(again.name, 'The lost wallet');
    expect(again.steps.length, 3);
    again.steps.removeAt(0); // drop the first line
    final shorter = saveOwnEvent(doc, again);
    final nodes = byId(shorter);
    expect(nodes.containsKey(50001), isTrue); // the other event's scene stays
    expect(nodes.length, 1 + 4); // 3 -> 2 steps, so 4 scenes with the reply and close
    expect((shorter['events'] as List).length, 2);
    final root = (shorter['events'] as List).last['rootNodeId'] as int;
    expect(reach(shorter, root).length, 4);
  });

  test('a scene id another event already has is skipped, not overwritten', () {
    final doc = {
      'events': <Object>[],
      'nodes': [
        {'id': 4001, 'type': 'last', 'text': 'not mine'},
        {'id': 4003, 'type': 'last', 'text': 'not mine either'},
      ],
    };
    final out = saveOwnEvent(doc, sample(id: 4));
    final nodes = byId(out);
    expect(nodes[4001]!['text'], 'not mine');
    expect(nodes[4003]!['text'], 'not mine either');
    final root = (out['events'] as List).single['rootNodeId'] as int;
    expect(root, 4002);
    expect(reach(out, root).length, 5);
    expect(reach(out, root).intersection({4001, 4003}), isEmpty);
  });

  test('deleting removes only that event\'s scenes', () {
    var doc = saveOwnEvent({}, sample(id: 1));
    doc = saveOwnEvent(doc, sample(id: 2));
    expect(byId(doc).length, 10);
    final out = deleteEvent(doc, 1);
    expect((out['events'] as List).single['id'], 2);
    expect(byId(out).keys, everyElement(greaterThan(2000)));
    expect(byId(out).length, 5);
  });

  test('ids for new events and speakers come after the highest', () {
    expect(nextEventId({}), 1);
    expect(
      nextEventId({
        'events': [
          {'id': 14},
          {'id': 10020128},
        ],
      }),
      10020129,
    );
    expect(
      nextSpeakerId({
        'speakers': [
          {'id': 1},
          {'id': 9},
        ],
      }),
      10,
    );
    expect(isOwnEvent({'studio': {}}), isTrue);
    expect(isOwnEvent({'baseEventId': 3}), isFalse);
  });

  test('an answer chains its reply, then each effect, then rejoins the story', () {
    final e = OwnEvent(
      id: 6,
      name: 'The shady guy',
      advanced: true,
      steps: [
        ChoiceStep(
          question: 'Follow him?',
          options: [
            ChoiceOption(
              label: 'Follow',
              replySpeakerId: 2,
              reply: 'This way.',
              effects: [
                EventEffect(kind: EffectKind.money, lose: true, amount: 50),
                EventEffect(kind: EffectKind.moveTo, targetId: 1004),
              ],
            ),
            ChoiceOption(
              label: 'Refuse',
              effects: [
                EventEffect(kind: EffectKind.item, amount: 2, targetId: 9),
                EventEffect(kind: EffectKind.trait, targetId: 33),
                EventEffect(kind: EffectKind.stat, subjectIndex: 1, amount: 3, lose: true),
                EventEffect(kind: EffectKind.stamina, amount: 10),
                EventEffect(kind: EffectKind.allStats, amount: 1),
                EventEffect(kind: EffectKind.unlock, targetId: 1005),
              ],
            ),
          ],
        ),
        LineStep(text: 'Back to the street.'),
      ],
    );
    final names = EffectNames(items: {9: 'Lucky coin'}, traits: {33: 'Street smart'}, locations: {1004: 'Back Alley', 1005: 'Arcade'});
    final doc = saveOwnEvent({}, e, subjects: ['korean', 'maths'], names: names);
    final nodes = byId(doc);
    expect(reach(doc, 6001), nodes.keys.toSet()); // nothing stranded
    final options = (nodes[6001]!['options'] as List).cast<Map>();
    // "Follow": reply, then lose gold, then move, then the line after the choice.
    var at = options[0]['nextNodeId'] as int;
    final follow = <String>[];
    while (nodes[at]!['type'] == 'text' && at != nodes[6001]!['nextNodeId']) {
      final scene = nodes[at]!;
      follow.add(scene['changer'] == null ? 'reply:${scene['text']}' : '${scene['changer']['funcCode']}${scene['changer']['args']}');
      at = scene['nextNodeId'] as int;
    }
    expect(follow, ['reply:This way.', 'DECREASE_MONEY[50]', 'MOVE_LOCATION[1004]']);
    expect(nodes[at]!['text'], 'Back to the street.');
    // "Refuse": no reply, straight into its effects.
    final refuse = <String>[];
    at = options[1]['nextNodeId'] as int;
    while (nodes[at]!['changer'] != null) {
      refuse.add('${nodes[at]!['changer']['funcCode']}${nodes[at]!['changer']['args']}');
      at = nodes[at]!['nextNodeId'] as int;
    }
    expect(refuse, [
      'ACQUIRE_ITEM[9, 2]',
      'ACQUIRE_TRAIT[33]',
      'DECREASE_STAT[1, 3]',
      'INCREASE_HP[10]',
      'INCREASE_STAT_ALL[1]',
      'UNLOCK_LOCATION[1005]',
    ]);
    expect(nodes[at]!['text'], 'Back to the street.');
    // The scenes say what happened, with the names given.
    final texts = [for (final n in nodes.values) '${n['text']}'];
    expect(texts, containsAll(['You lost 50 Gold.', 'You head to Back Alley.', 'You got 2 × Lucky coin.', 'You gained the trait Street smart.']));
    expect(texts, containsAll(['Your maths went down by 3.', 'Arcade is now open to you.']));

    // It reopens with every effect, and saving again changes nothing.
    final stored = (doc['events'] as List).single as Map<String, dynamic>;
    final again = OwnEvent.fromEvent(stored);
    expect(again.advanced, isTrue);
    expect(again.hasEffects, isTrue);
    final choice = again.steps.first as ChoiceStep;
    expect(choice.options.map((o) => o.effects.length), [2, 6]);
    expect(choice.options[1].effects.first.targetId, 9);
    expect(jsonEncode(saveOwnEvent(doc, again, subjects: ['korean', 'maths'], names: names)), jsonEncode(doc));
  });

  test('an effect missing its amount or its target is a problem', () {
    OwnEvent withEffect(EventEffect f) =>
        OwnEvent(id: 1, name: 'x', steps: [ChoiceStep(question: 'q', options: [ChoiceOption(label: 'a', effects: [f]), ChoiceOption(label: 'b')])]);
    expect(problemWith(withEffect(EventEffect(amount: 0))), 'An effect needs an amount above zero.');
    expect(problemWith(withEffect(EventEffect(kind: EffectKind.item))), 'An effect needs its item chosen.');
    expect(problemWith(withEffect(EventEffect(kind: EffectKind.moveTo))), 'An effect needs its move to a place chosen.');
    expect(problemWith(withEffect(EventEffect(kind: EffectKind.item, targetId: 3, amount: 1))), isNull);
    expect(problemWith(withEffect(EventEffect(kind: EffectKind.trait, targetId: 3))), isNull); // no amount needed
    expect(problemWith(withEffect(EventEffect(kind: EffectKind.moveTo, targetId: 3))), isNull);
  });

  test('a set day must be a day that exists', () {
    for (final ok in ['2023/10/16', '2024/02/29', '2023/12/31']) {
      expect(isRealDate(ok), isTrue, reason: ok);
    }
    for (final bad in ['2023/99/99', '2023/02/31', '2023/02/29', '2023/13/01', '2023/00/10', '2023-10-16', '23/10/16', '']) {
      expect(isRealDate(bad), isFalse, reason: bad);
    }
    expect(problemWith(sample()..onSetDay = true..date = '2023/02/31'), contains('YYYY/MM/DD'));
    expect(problemWith(sample()..onSetDay = true..date = '2023/10/16'), isNull);
  });

  test('a stat effect with a bad subject position still saves, with a plain sentence', () {
    final e = OwnEvent(id: 2, name: 'x', steps: [
      RewardStep(kind: RewardKind.stat, subjectIndex: -1, amount: 3),
      ChoiceStep(question: 'q', options: [
        ChoiceOption(label: 'a', effects: [EventEffect(kind: EffectKind.stat, subjectIndex: -1, amount: 2)]),
        ChoiceOption(label: 'b'),
      ]),
    ]);
    final texts = [for (final n in byId(saveOwnEvent({}, e, subjects: ['maths'])).values) '${n['text']}'];
    expect(texts, containsAll(['Your subject went up by 3.', 'Your subject went up by 2.']));
  });

  test('deleting also removes the scenes the form recorded, even with a lost link', () {
    var doc = saveOwnEvent({}, sample(id: 8));
    // Cut the link from the first scene, stranding the rest from the root.
    final nodes = (doc['nodes'] as List).cast<Map<String, dynamic>>();
    nodes.firstWhere((n) => n['id'] == 8001).remove('nextNodeId');
    final out = deleteEvent(doc, 8);
    expect(out['nodes'], isEmpty);
  });

  test('an incomplete event says what is missing', () {
    expect(problemWith(OwnEvent(id: 1)), 'Give the event a name.');
    expect(problemWith(OwnEvent(id: 1, name: 'x')), 'A line is empty.');
    expect(problemWith(sample()), isNull);
    expect(problemWith(sample()..onSetDay = true), contains('YYYY/MM/DD'));
    expect(problemWith(sample()..steps.add(ChoiceStep(question: 'q'))), 'A choice has an empty answer.');
    expect(problemWith(sample()..steps.add(RewardStep(amount: 0))), 'A reward must be more than zero.');
  });

  test('the result is a pack the engine loads, with the event eligible to run', () {
    final dir = Directory('assets/workshop');
    final files = {
      for (final f in dir.listSync(recursive: true).whereType<File>())
        f.path.substring(dir.path.length + 1).replaceAll(r'\', '/'): f.readAsStringSync(),
    };
    final doc = saveOwnEvent({
      'speakers': [
        {'id': 2, 'name': 'Mara'},
      ],
    }, sample());
    files['events/events.json'] = jsonEncode(doc);
    final pack = ContentPack.fromFiles(files);
    expect(pack.events[1]!.name, 'The lost wallet');
    expect(pack.nodes.length, 5);
    expect(pack.speakers[2], 'Mara');
    final choice = pack.nodes[1002]!;
    expect(choice.options.map((o) => o.text), ['Hand it in', 'Keep it']);
  });
}
