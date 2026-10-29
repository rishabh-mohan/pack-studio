import 'dart:convert';

/// A hand-made event as the editor holds it: a few settings and a list of
/// steps. It is stored on the event itself (`studio`), so the form can reopen
/// it exactly, and the scenes (`nodes`) are generated from it on every save.
/// Events without that record (copied from the base game, or written as raw
/// data) are left alone by the form.
const studioKey = 'studio';

/// Speaker id 0 is the player ("Me") in d30mode.
const meSpeakerId = 0;

enum RewardKind {
  money('Gold'),
  stamina('Stamina'),
  stat('One subject'),
  allStats('Every subject');

  const RewardKind(this.label);
  final String label;
}

/// What an answer can do. One effect is one scene, because d30mode runs a
/// single verb per scene.
enum EffectKind {
  money('Gold'),
  stamina('Stamina'),
  stat('One subject'),
  allStats('Every subject'),
  item('Item'),
  trait('Trait'),
  moveTo('Move to a place'),
  unlock('Unlock a place');

  const EffectKind(this.label);
  final String label;

  /// Whether it can be taken away as well as given.
  bool get canLose => this != moveTo && this != unlock;

  /// Whether it carries an amount (stamina, gold, points, how many items).
  bool get hasAmount => this != trait && this != moveTo && this != unlock;

  /// Whether it names an item, trait or place by number.
  bool get hasTarget => this == item || this == trait || this == moveTo || this == unlock;
}

class EventEffect {
  EventEffect({this.kind = EffectKind.money, this.lose = false, this.amount = 100, this.subjectIndex = 0, this.targetId});

  EffectKind kind;
  bool lose;
  int amount;

  /// For [EffectKind.stat]: position in the pack's `subjects`.
  int subjectIndex;

  /// The item, trait or place's number, for the kinds that name one.
  int? targetId;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'lose': lose,
    'amount': amount,
    'subjectIndex': subjectIndex,
    'targetId': targetId,
  };

  static EventEffect fromJson(Map<String, dynamic> j) => EventEffect(
    kind: EffectKind.values.firstWhere((k) => k.name == j['kind'], orElse: () => EffectKind.money),
    lose: j['lose'] == true,
    amount: (j['amount'] as num?)?.toInt() ?? 0,
    subjectIndex: (j['subjectIndex'] as num?)?.toInt() ?? 0,
    targetId: (j['targetId'] as num?)?.toInt(),
  );
}

sealed class EventStep {
  const EventStep();

  Map<String, dynamic> toJson();

  static EventStep fromJson(Map<String, dynamic> j) => switch (j['type']) {
    'choice' => ChoiceStep(
      question: j['question'] as String? ?? '',
      options: [
        for (final o in (j['options'] as List? ?? const []).cast<Map<String, dynamic>>())
          ChoiceOption(
            label: o['label'] as String? ?? '',
            replySpeakerId: (o['speakerId'] as num?)?.toInt() ?? meSpeakerId,
            reply: o['reply'] as String? ?? '',
            effects: [for (final e in (o['effects'] as List? ?? const []).cast<Map<String, dynamic>>()) EventEffect.fromJson(e)],
          ),
      ],
    ),
    'reward' => RewardStep(
      kind: RewardKind.values.firstWhere((k) => k.name == j['kind'], orElse: () => RewardKind.money),
      amount: (j['amount'] as num?)?.toInt() ?? 0,
      subjectIndex: (j['subjectIndex'] as num?)?.toInt() ?? 0,
      text: j['text'] as String? ?? '',
    ),
    _ => LineStep(speakerId: (j['speakerId'] as num?)?.toInt() ?? meSpeakerId, text: j['text'] as String? ?? ''),
  };
}

class LineStep extends EventStep {
  LineStep({this.speakerId = meSpeakerId, this.text = ''});

  int speakerId;
  String text;

  @override
  Map<String, dynamic> toJson() => {'type': 'line', 'speakerId': speakerId, 'text': text};
}

class ChoiceOption {
  ChoiceOption({this.label = '', this.replySpeakerId = meSpeakerId, this.reply = '', List<EventEffect>? effects})
    : effects = effects ?? [];

  String label;
  int replySpeakerId;

  /// What is said after this answer; blank goes straight on.
  String reply;

  /// What happens to the player after the reply, one effect after another.
  final List<EventEffect> effects;
}

class ChoiceStep extends EventStep {
  ChoiceStep({this.question = '', List<ChoiceOption>? options})
    : options = options ?? [ChoiceOption(), ChoiceOption()];

  String question;
  final List<ChoiceOption> options;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'choice',
    'question': question,
    'options': [
      for (final o in options)
        {
          'label': o.label,
          'speakerId': o.replySpeakerId,
          'reply': o.reply,
          'effects': [for (final e in o.effects) e.toJson()],
        },
    ],
  };
}

class RewardStep extends EventStep {
  RewardStep({this.kind = RewardKind.money, this.amount = 100, this.subjectIndex = 0, this.text = ''});

  RewardKind kind;
  int amount;

  /// For [RewardKind.stat]: position in the pack's `subjects`.
  int subjectIndex;

  /// Shown when the reward is given; blank writes a plain sentence.
  String text;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'reward',
    'kind': kind.name,
    'amount': amount,
    'subjectIndex': subjectIndex,
    'text': text,
  };
}

class OwnEvent {
  OwnEvent({
    required this.id,
    this.name = '',
    this.onSetDay = false,
    this.date = '',
    this.tick = 0,
    this.locationId,
    this.once = true,
    this.advanced = false,
    List<EventStep>? steps,
  }) : steps = steps ?? [LineStep()];

  final int id;
  String name;

  /// False: a random event. True: happens on [date] (YYYY/MM/DD).
  bool onSetDay;
  String date;

  /// The slot of that day it waits for: 0 is any time, 1 to 14 the slots in
  /// order, 14 being the evening (the data's `DATE_YYYYMMDDTT`).
  int tick;

  /// Only while the player is at this location; null is anywhere.
  int? locationId;

  /// Happens once per run (the data's own `EVENT_<id> == 0` gate).
  bool once;

  /// Shows the effects an answer can have (the form's "Advanced effects").
  bool advanced;
  final List<EventStep> steps;

  /// Whether any answer carries an effect.
  bool get hasEffects => steps.any((s) => s is ChoiceStep && s.options.any((o) => o.effects.isNotEmpty));

  Map<String, dynamic> toJson() => {
    'onSetDay': onSetDay,
    'date': date,
    'tick': tick,
    'locationId': locationId,
    'once': once,
    'advanced': advanced,
    'steps': [for (final s in steps) s.toJson()],
  };

  static OwnEvent fromEvent(Map<String, dynamic> event) {
    final j = event[studioKey] as Map<String, dynamic>;
    return OwnEvent(
      id: (event['id'] as num).toInt(),
      name: event['name'] as String? ?? '',
      onSetDay: j['onSetDay'] == true,
      date: j['date'] as String? ?? '',
      tick: (j['tick'] as num?)?.toInt() ?? 0,
      locationId: (j['locationId'] as num?)?.toInt(),
      once: j['once'] != false,
      advanced: j['advanced'] == true,
      steps: [for (final s in (j['steps'] as List? ?? const []).cast<Map<String, dynamic>>()) EventStep.fromJson(s)],
    );
  }
}

/// Why an event cannot be saved yet, or null.
String? problemWith(OwnEvent e) {
  if (e.name.trim().isEmpty) return 'Give the event a name.';
  if (e.onSetDay && !RegExp(r'^\d{4}/\d{2}/\d{2}$').hasMatch(e.date)) {
    return 'Write the day as YYYY/MM/DD, for example 2023/10/16.';
  }
  if (e.tick < 0 || e.tick > 14) return 'Pick a time of day.';
  if (e.steps.isEmpty) return 'Add at least one step.';
  for (final s in e.steps) {
    if (s is LineStep && s.text.trim().isEmpty) return 'A line is empty.';
    if (s is ChoiceStep) {
      if (s.question.trim().isEmpty) return 'A choice needs a question.';
      if (s.options.length < 2) return 'A choice needs at least two answers.';
      if (s.options.any((o) => o.label.trim().isEmpty)) return 'A choice has an empty answer.';
      for (final o in s.options) {
        for (final effect in o.effects) {
          if (effect.kind.hasAmount && effect.amount <= 0) return 'An effect needs an amount above zero.';
          if (effect.kind.hasTarget && effect.targetId == null) return 'An effect needs its ${effect.kind.label.toLowerCase()} chosen.';
        }
      }
    }
    if (s is RewardStep && s.amount <= 0) return 'A reward must be more than zero.';
  }
  return null;
}

/// The gate the event carries: once-only, here, on this day.
Map<String, dynamic> conditionSetFor(OwnEvent e) {
  Map<String, dynamic> condition(String target, String targetType, int value) => {
    'type': 'defaults',
    'target': target,
    'targetType': targetType,
    'compareType': 'equal',
    'value': value,
  };
  return {
    'operator': 'and',
    'left': {'conditions': <Map<String, dynamic>>[]},
    'right': {
      'conditions': [
        if (e.once) condition('EVENT_${e.id}', 'event', 0),
        if (e.locationId != null) condition('LOCATION_${e.locationId}', 'location', 1),
        if (e.onSetDay) condition('DATE_${e.date.replaceAll('/', '')}${e.tick.toString().padLeft(2, '0')}', 'date', 1),
      ],
    },
  };
}

String _rewardText(RewardStep s, List<String> subjects) {
  if (s.text.trim().isNotEmpty) return s.text.trim();
  return switch (s.kind) {
    RewardKind.money => 'You got ${s.amount} Gold.',
    RewardKind.stamina => 'You feel rested (+${s.amount} stamina).',
    RewardKind.stat =>
      'Your ${s.subjectIndex < subjects.length ? subjects[s.subjectIndex] : 'subject'} went up by ${s.amount}.',
    RewardKind.allStats => 'Every subject went up by ${s.amount}.',
  };
}

Map<String, dynamic> _rewardChanger(RewardStep s) {
  final (code, args) = switch (s.kind) {
    RewardKind.money => ('INCREASE_MONEY', [s.amount]),
    RewardKind.stamina => ('INCREASE_HP', [s.amount]),
    RewardKind.stat => ('INCREASE_STAT', [s.subjectIndex, s.amount]),
    RewardKind.allStats => ('INCREASE_STAT_ALL', [s.amount]),
  };
  return {'funcCode': code, 'args': args, 'changes': <Object>[]};
}

/// Names for the items, traits and places an effect points at, so the text it
/// shows can say them. Anything missing reads as a plain "an item".
class EffectNames {
  const EffectNames({this.items = const {}, this.traits = const {}, this.locations = const {}});

  final Map<int, String> items;
  final Map<int, String> traits;
  final Map<int, String> locations;
}

String _effectText(EventEffect f, List<String> subjects, EffectNames names) {
  final verb = f.lose ? 'lost' : 'got';
  final subject = f.subjectIndex < subjects.length ? subjects[f.subjectIndex] : 'subject';
  return switch (f.kind) {
    EffectKind.money => 'You $verb ${f.amount} Gold.',
    EffectKind.stamina => f.lose ? 'You lost ${f.amount} stamina.' : 'You feel rested (+${f.amount} stamina).',
    EffectKind.stat => 'Your $subject went ${f.lose ? 'down' : 'up'} by ${f.amount}.',
    EffectKind.allStats => 'Every subject went ${f.lose ? 'down' : 'up'} by ${f.amount}.',
    EffectKind.item => 'You $verb ${f.amount > 1 ? '${f.amount} × ' : ''}${names.items[f.targetId] ?? 'an item'}.',
    EffectKind.trait =>
      names.traits[f.targetId] == null
          ? 'You ${f.lose ? 'lost' : 'gained'} a trait.'
          : 'You ${f.lose ? 'lost' : 'gained'} the trait ${names.traits[f.targetId]}.',
    EffectKind.moveTo => 'You head to ${names.locations[f.targetId] ?? 'another place'}.',
    EffectKind.unlock => '${names.locations[f.targetId] ?? 'A new place'} is now open to you.',
  };
}

/// The one verb d30mode runs for an effect.
Map<String, dynamic> _effectChanger(EventEffect f) {
  final (code, args) = switch (f.kind) {
    EffectKind.money => (f.lose ? 'DECREASE_MONEY' : 'INCREASE_MONEY', [f.amount]),
    EffectKind.stamina => (f.lose ? 'DECREASE_HP' : 'INCREASE_HP', [f.amount]),
    EffectKind.stat => (f.lose ? 'DECREASE_STAT' : 'INCREASE_STAT', [f.subjectIndex, f.amount]),
    EffectKind.allStats => (f.lose ? 'DECREASE_STAT_ALL' : 'INCREASE_STAT_ALL', [f.amount]),
    EffectKind.item => (f.lose ? 'REMOVE_ITEM' : 'ACQUIRE_ITEM', [f.targetId, f.amount]),
    EffectKind.trait => (f.lose ? 'REMOVE_TRAIT' : 'ACQUIRE_TRAIT', [f.targetId]),
    EffectKind.moveTo => ('MOVE_LOCATION', [f.targetId]),
    EffectKind.unlock => ('UNLOCK_LOCATION', [f.targetId]),
  };
  return {'funcCode': code, 'args': args, 'changes': <Object>[]};
}

/// The scenes for [e]: one per line, reward and answer, one per choice, and a
/// closing one. Ids are `eventId * 1000 + n` (the convention d30mode's tests
/// assume), moving on to the next free number when another scene has one.
List<Map<String, dynamic>> buildScenes(
  OwnEvent e, {
  required Set<int> taken,
  List<String> subjects = const [],
  EffectNames names = const EffectNames(),
}) {
  var n = 0;
  int allocate() {
    int id;
    do {
      n++;
      id = e.id * 1000 + n;
    } while (taken.contains(id));
    return id;
  }

  // Ids first, so every scene knows where it goes next.
  final firstOf = <int>[];
  // Per answer: its reply (if any), then one scene per effect.
  final chains = <int, List<List<int>>>{};
  for (var i = 0; i < e.steps.length; i++) {
    final step = e.steps[i];
    firstOf.add(allocate());
    if (step is ChoiceStep) {
      chains[i] = [
        for (final o in step.options) [if (o.reply.trim().isNotEmpty) allocate(), for (final _ in o.effects) allocate()],
      ];
    }
  }
  final lastId = allocate();

  final scenes = <Map<String, dynamic>>[];
  for (var i = 0; i < e.steps.length; i++) {
    final step = e.steps[i];
    final next = i + 1 < e.steps.length ? firstOf[i + 1] : lastId;
    switch (step) {
      case LineStep():
        scenes.add({'id': firstOf[i], 'type': 'text', 'speakerId': step.speakerId, 'text': step.text.trim(), 'nextNodeId': next});
      case RewardStep():
        scenes.add({
          'id': firstOf[i],
          'type': 'text',
          'speakerId': meSpeakerId,
          'text': _rewardText(step, subjects),
          'changer': _rewardChanger(step),
          'nextNodeId': next,
        });
      case ChoiceStep():
        scenes.add({
          'id': firstOf[i],
          'type': 'option',
          'text': step.question.trim(),
          'nextNodeId': next,
          'options': [
            for (var k = 0; k < step.options.length; k++)
              {'text': step.options[k].label.trim(), 'nextNodeId': chains[i]![k].firstOrNull ?? next},
          ],
        });
        for (var k = 0; k < step.options.length; k++) {
          final option = step.options[k];
          final chain = chains[i]![k];
          var at = 0;
          if (option.reply.trim().isNotEmpty) {
            scenes.add({
              'id': chain[at],
              'type': 'text',
              'speakerId': option.replySpeakerId,
              'text': option.reply.trim(),
              'nextNodeId': at + 1 < chain.length ? chain[at + 1] : next,
            });
            at++;
          }
          for (final effect in option.effects) {
            scenes.add({
              'id': chain[at],
              'type': 'text',
              'speakerId': meSpeakerId,
              'text': _effectText(effect, subjects, names),
              'changer': _effectChanger(effect),
              'nextNodeId': at + 1 < chain.length ? chain[at + 1] : next,
            });
            at++;
          }
        }
    }
  }
  scenes.add({'id': lastId, 'type': 'last'});
  return scenes;
}

/// Events made with the form: those carrying a [studioKey] record.
bool isOwnEvent(Object? event) => event is Map && event[studioKey] is Map;

/// Next unused event id.
int nextEventId(Map<String, dynamic> eventsDoc) {
  var highest = 0;
  for (final e in eventsDoc['events'] as List? ?? const []) {
    final id = e is Map && e['id'] is num ? (e['id'] as num).toInt() : 0;
    if (id > highest) highest = id;
  }
  return highest + 1;
}

/// A new speaker's id.
int nextSpeakerId(Map<String, dynamic> eventsDoc) {
  var highest = 0;
  for (final s in eventsDoc['speakers'] as List? ?? const []) {
    final id = s is Map && s['id'] is num ? (s['id'] as num).toInt() : 0;
    if (id > highest) highest = id;
  }
  return highest + 1;
}

/// Writes [e] into a copy of the events document: replaces its own event and
/// scenes if it is already there, adds them if not. Everything else, including
/// fields the form does not know, stays as it was.
Map<String, dynamic> saveOwnEvent(
  Map<String, dynamic> eventsDoc,
  OwnEvent e, {
  List<String> subjects = const [],
  EffectNames names = const EffectNames(),
}) {
  final doc = jsonDecode(jsonEncode(eventsDoc)) as Map<String, dynamic>;
  final events = [...(doc['events'] as List? ?? const [])];
  var nodes = [...(doc['nodes'] as List? ?? const [])];

  final at = events.indexWhere((x) => x is Map && x['id'] == e.id);
  final old = at < 0 ? null : events[at] as Map<String, dynamic>;
  final oldScenes = {for (final id in (old?[studioKey] as Map?)?['sceneIds'] as List? ?? const []) (id as num).toInt()};
  nodes = [for (final n in nodes) if (!(n is Map && oldScenes.contains((n['id'] as num?)?.toInt()))) n];

  final taken = {for (final n in nodes) if (n is Map && n['id'] is num) (n['id'] as num).toInt()};
  final scenes = buildScenes(e, taken: taken, subjects: subjects, names: names);
  nodes.addAll(scenes);

  final record = <String, dynamic>{
    ...?old,
    'id': e.id,
    'name': e.name.trim(),
    'rootNodeId': scenes.first['id'],
    'isRandomDate': !e.onSetDay,
    'priority': old?['priority'] ?? 'middle',
    'rank': old?['rank'] ?? 'C',
    'section': old?['section'] ?? 'none',
    'conditionSet': conditionSetFor(e),
    studioKey: {...e.toJson(), 'sceneIds': [for (final s in scenes) s['id']]},
  };
  if (at < 0) {
    events.add(record);
  } else {
    events[at] = record;
  }
  doc['events'] = events;
  doc['nodes'] = nodes;
  return doc;
}

/// Removes an event and its scenes (all it can reach, for events not made by
/// the form).
Map<String, dynamic> deleteEvent(Map<String, dynamic> eventsDoc, int eventId) {
  final doc = jsonDecode(jsonEncode(eventsDoc)) as Map<String, dynamic>;
  final events = [...(doc['events'] as List? ?? const [])];
  final nodes = [...(doc['nodes'] as List? ?? const [])];
  final at = events.indexWhere((x) => x is Map && x['id'] == eventId);
  if (at < 0) return doc;
  final event = events.removeAt(at) as Map<String, dynamic>;

  final byId = {for (final n in nodes) if (n is Map && n['id'] is num) (n['id'] as num).toInt(): n};
  final drop = <int>{};
  final todo = <int>[(event['rootNodeId'] as num?)?.toInt() ?? -1];
  while (todo.isNotEmpty) {
    final id = todo.removeLast();
    final node = byId[id];
    if (node == null || !drop.add(id)) continue;
    for (final key in const ['nextNodeId', 'nextNodeIdIfTrue', 'nextNodeIdIfFalse']) {
      if (node[key] is num) todo.add((node[key] as num).toInt());
    }
    for (final o in node['options'] as List? ?? const []) {
      if (o is Map && o['nextNodeId'] is num) todo.add((o['nextNodeId'] as num).toInt());
    }
  }
  // Scenes another event also reaches stay.
  for (final other in events) {
    if (other is! Map) continue;
    final keep = <int>[(other['rootNodeId'] as num?)?.toInt() ?? -1];
    final seen = <int>{};
    while (keep.isNotEmpty) {
      final id = keep.removeLast();
      final node = byId[id];
      if (node == null || !seen.add(id)) continue;
      drop.remove(id);
      for (final key in const ['nextNodeId', 'nextNodeIdIfTrue', 'nextNodeIdIfFalse']) {
        if (node[key] is num) keep.add((node[key] as num).toInt());
      }
      for (final o in node['options'] as List? ?? const []) {
        if (o is Map && o['nextNodeId'] is num) keep.add((o['nextNodeId'] as num).toInt());
      }
    }
  }
  doc['events'] = events;
  doc['nodes'] = [for (final n in nodes) if (!(n is Map && drop.contains((n['id'] as num?)?.toInt()))) n];
  return doc;
}
