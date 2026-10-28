import 'package:flutter/material.dart';

/// How one field of a pack record is shown and edited. The forms are generated
/// from these descriptions, so a pack author never sees JSON.
enum FieldKind {
  /// One line of text.
  text,

  /// Several lines of text.
  multiline,

  /// Whole number.
  integer,

  /// Number that may have decimals.
  number,

  /// On / off switch.
  toggle,

  /// Pick one of [FieldSpec.choices] (or type your own when [FieldSpec.allowCustom]).
  choice,

  /// A list of short texts, shown as removable chips with an add box.
  stringList,

  /// A nested object whose [FieldSpec.fields] are shown in a collapsible box.
  group,

  /// A list of sub-records ([FieldSpec.item]), each its own card.
  recordList,

  /// Something too intricate for a form yet: a button that opens the advanced
  /// editor for just this value.
  json,

  /// A picture: chosen with the system picker, copied into the pack's images
  /// folder and shown as a preview ([FieldSpec.imageFolder] says which folder).
  image,
}

class Choice {
  const Choice(this.value, this.label, [this.help]);

  /// What is stored in the pack file.
  final String value;

  /// What the author sees.
  final String label;
  final String? help;
}

/// Converts between what the author types and what the pack file stores.
class TextCodec {
  const TextCodec({
    required this.hint,
    required this.toDisplay,
    required this.validate,
    required this.toStored,
  });

  /// Placeholder shown in the empty field, e.g. "YYYY/MM/DD".
  final String hint;
  final String Function(String stored) toDisplay;

  /// Null when the text is acceptable, else a plain-language problem.
  final String? Function(String display) validate;

  /// [previousStored] lets the codec keep parts the author never sees.
  final String Function(String display, String? previousStored) toStored;
}

/// How much text a spot in the game can show. New input past the limit is
/// refused with [why]; text already past it is kept and flagged, never cut.
class TextLimit {
  const TextLimit({required this.maxChars, required this.why, this.singleLine = true});

  final int maxChars;

  /// Line breaks are refused when true (the game wraps the text itself).
  final bool singleLine;

  /// Where the number comes from, shown to the author.
  final String why;
}

class FieldSpec {
  const FieldSpec(
    this.key,
    this.label,
    this.kind, {
    this.help,
    this.choices = const [],
    this.allowCustom = false,
    this.fields = const [],
    this.item,
    this.addLabel,
    this.required = false,
    this.defaultValue,
    this.codec,
    this.limit,
    this.imageFolder,
  });

  /// For text fields: shows and accepts a friendlier form than the stored one.
  final TextCodec? codec;

  /// For [FieldKind.image]: the folder under the pack's images/ that picked pictures go into.
  final String? imageFolder;

  /// For text fields: the most the game can show here.
  final TextLimit? limit;

  /// The key in the pack file.
  final String key;
  final String label;
  final FieldKind kind;

  /// A short explanation shown under the field.
  final String? help;

  final List<Choice> choices;
  final bool allowCustom;

  /// For [FieldKind.group].
  final List<FieldSpec> fields;

  /// For [FieldKind.recordList].
  final RecordSpec? item;

  /// For [FieldKind.recordList]: the add button's text, e.g. "Add action".
  final String? addLabel;

  /// A cleared optional field removes its key from the file; a required one
  /// keeps an empty value.
  final bool required;

  /// Shown (and written on first edit) when the key is missing.
  final Object? defaultValue;
}

class RecordSpec {
  const RecordSpec({
    required this.noun,
    required this.fields,
    required this.title,
    this.subtitle,
    this.addByChoice,
    this.blank = const {},
  });

  /// "location", "trait"...: used in buttons like "Add location".
  final String noun;
  final List<FieldSpec> fields;

  /// The button / card heading for one record.
  final String Function(Map<String, dynamic> record) title;
  final String? Function(Map<String, dynamic> record)? subtitle;

  /// When set, "add" first asks which [Choice] of this field (e.g. the action
  /// type) the new record should be, then creates `{addByChoice: value, ...blank}`.
  final String? addByChoice;

  /// Values a brand-new record starts with (besides its id).
  final Map<String, dynamic> blank;
}

/// One kind of pack content as the author sees it: a button on the pack screen.
class SectionSpec {
  const SectionSpec({
    required this.label,
    required this.blurb,
    required this.icon,
    required this.file,
    required this.record,
    this.listKey,
    this.idKey = 'id',
  });

  final String label;
  final String blurb;
  final IconData icon;
  final String file;
  final RecordSpec record;

  /// The array's key inside the file (`{"locations": [...]}`); null when the
  /// whole file is one record (pack.json).
  final String? listKey;
  final String idKey;
}

// ---------------------------------------------------------------------------
// The pack's content, described.

const actionTypes = [
  Choice('study', 'Study', 'Spends stamina to raise a subject.'),
  Choice('lesson', 'Class', 'A school lesson.'),
  Choice('exercise', 'Exercise', 'Spends stamina to level up exercise.'),
  Choice('partTimeJob', 'Work', 'Spends stamina to earn money.'),
  Choice('sleep', 'Sleep', 'Restores stamina.'),
  Choice('special', 'Special', 'A custom action: spends stamina and runs its effects.'),
  Choice('none', 'Nothing special', 'Does nothing on its own.'),
];

String _actionLabel(Object? type) => actionTypes
    .firstWhere((c) => c.value == type, orElse: () => Choice('$type', '$type'))
    .label;

const actionRecord = RecordSpec(
  noun: 'action',
  addByChoice: 'locationActionType',
  title: _actionTitle,
  subtitle: _actionSubtitle,
  fields: [
    FieldSpec('locationActionType', 'What it does', FieldKind.choice,
        choices: actionTypes, required: true),
    FieldSpec('text', 'Button label', FieldKind.text,
        help: 'Shown on the action. Leave empty to use the action type\'s name.'),
    FieldSpec('weight', 'How often it is offered', FieldKind.number,
        help: 'Higher means it is drawn more often. Normal is 1.'),
    FieldSpec('hpWeight', 'Stamina weight', FieldKind.number,
        help: 'More weight, more stamina spent. 0 uses the plain cost for the action type.'),
    FieldSpec('blockDuplicated', 'Only once per day', FieldKind.toggle),
    FieldSpec('conditionFuncCode', 'Shown only when (name)', FieldKind.text,
        help: 'Advanced: the name of a condition or switch that must be true.'),
    FieldSpec('conditionSet', 'Extra conditions', FieldKind.json),
    FieldSpec('changer', 'Effects when used', FieldKind.json),
  ],
);

String _actionTitle(Map<String, dynamic> a) {
  final text = a['text'];
  final type = _actionLabel(a['locationActionType']);
  return text is String && text.isNotEmpty ? text : type;
}

String? _actionSubtitle(Map<String, dynamic> a) {
  final text = a['text'];
  return text is String && text.isNotEmpty ? _actionLabel(a['locationActionType']) : null;
}

/// The pack rules that change what the editor tells the author, so its labels
/// stay true when the rules change. Defaults mirror the engine's (see
/// `d30_engine` `rules.dart`: sleep restores 10, +3 at a Rest location).
class PackTuning {
  const PackTuning({this.sleepRestoresHp = 10, this.sleepLocationBonusHp = 3, this.subjects = const []});

  factory PackTuning.fromRules(Map<String, dynamic> rules, {List<String> subjects = const []}) {
    final day = rules['day'];
    num pick(String key, num fallback) => day is Map && day[key] is num ? day[key] as num : fallback;
    return PackTuning(
      sleepRestoresHp: pick('sleepRestoresHp', 10),
      sleepLocationBonusHp: pick('sleepLocationBonusHp', 3),
      subjects: subjects,
    );
  }

  /// The pack's subjects, in order (books are offered per subject).
  final List<String> subjects;

  final num sleepRestoresHp;
  final num sleepLocationBonusHp;
}

String _num(num n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

/// Every kind of place with its real gameplay effect. In the engine only
/// `sleep` has one built in; the other kinds are tags that traits, items and
/// conditions can match.
List<Choice> locationTypeChoices(PackTuning t) {
  const none = 'No additional bonus. Traits, items and conditions can still match this kind of place.';
  final bonus = _num(t.sleepLocationBonusHp);
  return [
    const Choice('none', 'Basic (no additional bonus)', none),
    Choice(
      'sleep',
      'Rest (+$bonus Sleep stamina)',
      'Sleeping here restores $bonus more stamina than sleeping anywhere else: '
          '${_num(t.sleepRestoresHp)} + $bonus = ${_num(t.sleepRestoresHp + t.sleepLocationBonusHp)} with no other modifiers.',
    ),
    const Choice('school', 'School (no additional bonus)', none),
    const Choice('exercise', 'Workout (no additional bonus)', none),
    const Choice('partTimeJob', 'Work (no additional bonus)', none),
    const Choice('study', 'Study (no additional bonus)', none),
  ];
}

// Description limits, from d30mode's layout (checked 2026-10-28). Assumed phone:
// 360 dp wide, system text enlarged to 1.3x, average glyph 0.52 em, and about
// 10% lost to word wrapping. Only spots with a hard line limit get one;
// scrolling areas (character setup card, item pop-ups) have none.
const locationDescriptionLimit = TextLimit(
  maxChars: 38,
  why: 'Location cards show 2 lines of small text (about 21 characters a line on a small phone with larger system text).',
);
const traitDescriptionLimit = TextLimit(
  maxChars: 41,
  why: 'Trait cards show 3 lines of small text (about 15 characters a line on a small phone with larger system text).',
);

RecordSpec locationRecordFor(PackTuning tuning) => RecordSpec(
  noun: 'location',
  title: _nameOrUntitled,
  subtitle: _locationSubtitle,
  blank: const {'name': 'New location', 'actions': []},
  fields: [
    const FieldSpec('name', 'Name', FieldKind.text, required: true),
    const FieldSpec('description', 'Description', FieldKind.text, limit: locationDescriptionLimit),
    FieldSpec('type', 'Kind of place', FieldKind.choice, allowCustom: true, choices: locationTypeChoices(tuning)),
    const FieldSpec('isDefaultLocked', 'Locked at the start', FieldKind.toggle,
        help: 'Players cannot go here until an event unlocks it.'),
    const FieldSpec('image', 'Backdrop picture', FieldKind.image, imageFolder: 'backgrounds',
        help: 'The scene shown behind this place.'),
    const FieldSpec('actions', 'Actions here', FieldKind.recordList,
        item: actionRecord, addLabel: 'Add action'),
  ],
);

final locationRecord = locationRecordFor(const PackTuning());

// ---- Dates: the author types YYYY/MM/DD; the pack stores DATE_YYYYMMDDTT.

String _dateToDisplay(String stored) {
  final m = RegExp(r'^DATE_(\d{4})(\d{2})(\d{2})\d{2}$').firstMatch(stored);
  return m == null ? stored : '${m[1]}/${m[2]}/${m[3]}';
}

String? _validateDate(String text) {
  final m = RegExp(r'^(\d{4})/(\d{1,2})/(\d{1,2})$').firstMatch(text.trim());
  if (m == null) return 'Write the date as YYYY/MM/DD, for example 2026/10/28.';
  final year = int.parse(m[1]!), month = int.parse(m[2]!), day = int.parse(m[3]!);
  if (month < 1 || month > 12) return 'The month must be between 1 and 12.';
  final daysInMonth = DateTime.utc(year, month + 1, 0).day;
  if (day < 1 || day > daysInMonth) return 'That month has $daysInMonth days in $year.';
  return null;
}

String _dateToStored(String text, String? previousStored) {
  final m = RegExp(r'^(\d{4})/(\d{1,2})/(\d{1,2})$').firstMatch(text.trim())!;
  // The last two digits are the time slot; keep whatever the pack already had.
  final slot = RegExp(r'^DATE_\d{8}(\d{2})$').firstMatch(previousStored ?? '')?[1] ?? '00';
  return 'DATE_${m[1]}${m[2]!.padLeft(2, '0')}${m[3]!.padLeft(2, '0')}$slot';
}

const dateCodec = TextCodec(
  hint: 'YYYY/MM/DD',
  toDisplay: _dateToDisplay,
  validate: _validateDate,
  toStored: _dateToStored,
);

String _nameOrUntitled(Map<String, dynamic> r) {
  final name = r['name'];
  return name is String && name.trim().isNotEmpty ? name : 'Untitled';
}

String? _locationSubtitle(Map<String, dynamic> r) {
  final actions = r['actions'];
  final n = actions is List ? actions.length : 0;
  return n == 1 ? '1 action' : '$n actions';
}

const traitRecord = RecordSpec(
  noun: 'trait',
  title: _nameOrUntitled,
  subtitle: _traitSubtitle,
  blank: {'name': 'New trait', 'type': 'good'},
  fields: [
    FieldSpec('name', 'Name', FieldKind.text, required: true),
    FieldSpec('description', 'Description', FieldKind.text, limit: traitDescriptionLimit),
    FieldSpec('type', 'Kind', FieldKind.choice, choices: [
      Choice('good', 'Good'),
      Choice('normal', 'Neutral'),
      Choice('bad', 'Bad', 'Bad traits can be removed or blocked by effects.'),
    ]),
    FieldSpec('rank', 'Rarity', FieldKind.choice, choices: [
      Choice('S', 'S (rarest)'),
      Choice('A', 'A'),
      Choice('B', 'B'),
      Choice('C', 'C (common)'),
      Choice('none', 'No rank'),
    ]),
    FieldSpec('gachable', 'Choosable at setup', FieldKind.toggle,
        help: 'Players can pick it before a run starts.'),
    FieldSpec('initialLifeTime', 'Lasts (days)', FieldKind.integer,
        help: 'Leave empty to keep it forever.'),
    FieldSpec('effectList', 'What it does', FieldKind.json),
  ],
);

String? _traitSubtitle(Map<String, dynamic> r) {
  const kinds = {'good': 'Good', 'normal': 'Neutral', 'bad': 'Bad'};
  final kind = kinds[r['type']];
  final rank = r['rank'];
  return [?kind, if (rank is String && rank != 'none') 'Rank $rank'].join(' · ');
}

const characterRecord = RecordSpec(
  noun: 'character',
  title: _nameOrUntitled,
  subtitle: _characterSubtitle,
  blank: {'name': 'New character', 'gender': 'male'},
  fields: [
    FieldSpec('name', 'Name', FieldKind.text, required: true),
    FieldSpec('gender', 'Gender', FieldKind.choice, choices: [
      Choice('male', 'Male'),
      Choice('female', 'Female'),
    ]),
    FieldSpec('isDefault', 'Selected by default', FieldKind.toggle,
        help: 'A pack needs at least one default character to start a run.'),
    FieldSpec('stars', 'Stars', FieldKind.integer),
    FieldSpec('effectDescription', 'What makes them special', FieldKind.multiline),
    FieldSpec('portrait', 'Portrait picture', FieldKind.image, imageFolder: 'characters',
        help: 'Shown wherever this character appears. Without one the game shows a question mark.'),
    FieldSpec('plusEffect', 'Bonus effect', FieldKind.json),
  ],
);

String? _characterSubtitle(Map<String, dynamic> r) =>
    r['isDefault'] == true ? 'Default character' : null;

const itemRecord = RecordSpec(
  noun: 'item',
  title: _nameOrUntitled,
  subtitle: _itemSubtitle,
  blank: {'name': 'New item', 'kind': 'consume', 'effects': []},
  fields: [
    FieldSpec('name', 'Name', FieldKind.text, required: true),
    FieldSpec('description', 'Description', FieldKind.multiline),
    FieldSpec('effectText', 'Effect text', FieldKind.text,
        help: 'Shown to the player; it does not change what the item does.'),
    FieldSpec('kind', 'How it works', FieldKind.choice, choices: [
      Choice('consume', 'Used up', 'Consumed when used.'),
      Choice('normal', 'Held', 'Its passive effects apply while you own it.'),
    ]),
    FieldSpec('maxCount', 'Carry at most', FieldKind.integer,
        help: 'Leave empty for no limit.'),
    FieldSpec('detailTypes', 'Tags', FieldKind.stringList,
        help: 'Abilities can match items by tag, e.g. "milk".'),
    FieldSpec('effects', 'What it does', FieldKind.json),
  ],
);

String? _itemSubtitle(Map<String, dynamic> r) =>
    r['kind'] == 'normal' ? 'Held' : 'Used up';

const bookTierChoices = [
  Choice('1', 'E (first tier)'),
  Choice('2', 'D'),
  Choice('3', 'C'),
  Choice('4', 'B'),
  Choice('5', 'A'),
  Choice('6', 'S (last tier)'),
];

String? _bookSubtitle(Map<String, dynamic> r) {
  final tier = bookTierChoices.where((c) => c.value == '${r['bookRank']}').map((c) => c.label.split(' ').first);
  return ['${r['subject']}', if (tier.isNotEmpty) 'Tier ${tier.first}'].join(' · ');
}

RecordSpec bookRecordFor(PackTuning tuning) => RecordSpec(
  noun: 'book',
  title: _nameOrUntitled,
  subtitle: _bookSubtitle,
  blank: const {'name': 'New book', 'power': 5, 'doneCount': 8, 'bookRank': '1'},
  fields: [
    const FieldSpec('name', 'Name', FieldKind.text, required: true),
    const FieldSpec('description', 'Description', FieldKind.multiline),
    FieldSpec('subject', 'Subject', FieldKind.choice, allowCustom: true, required: true, choices: [
      for (final s in tuning.subjects) Choice(s, s),
    ]),
    const FieldSpec('bookRank', 'Tier', FieldKind.choice, choices: bookTierChoices,
        help: 'Players unlock the tiers of a subject in order.'),
    const FieldSpec('power', 'Power', FieldKind.number,
        help: 'How much one study block gives, before the pack\'s study weight. '
            'With the standard weight of 3, power 5 gives 15 points.'),
    const FieldSpec('doneCount', 'Reads to finish', FieldKind.integer,
        help: 'How many times a book is studied to finish it and unlock the next tier.'),
  ],
);

const packInfoRecord = RecordSpec(
  noun: 'pack',
  title: _nameOrUntitled,
  fields: [
    FieldSpec('name', 'Pack name', FieldKind.text, required: true),
    FieldSpec('description', 'Description', FieldKind.multiline,
        help: 'Shown when choosing a game mode.'),
    FieldSpec('subjects', 'Subjects', FieldKind.stringList,
        help: 'The things players study. The order matters: keep it stable once '
            'events refer to subjects by position.'),
    FieldSpec('calendar', 'Calendar', FieldKind.group, fields: [
      FieldSpec('startDate', 'First day', FieldKind.text,
          codec: dateCodec, help: 'Write it as YYYY/MM/DD, for example 2023/10/16.', required: true),
      FieldSpec('endDate', 'Last day (exam day)', FieldKind.text,
          codec: dateCodec, help: 'Write it as YYYY/MM/DD.', required: true),
      FieldSpec('ticksPerDay', 'Turns per day', FieldKind.integer),
    ]),
    FieldSpec('start', 'Starting point', FieldKind.group, fields: [
      FieldSpec('locationId', 'Starting location number', FieldKind.integer,
          help: 'The number of a location in the Locations list.'),
      FieldSpec('firstName', 'Player first name', FieldKind.text),
      FieldSpec('lastName', 'Player last name', FieldKind.text),
    ]),
  ],
);

/// The kinds of content shown as buttons. Built per pack because some labels quote its rules.
List<SectionSpec> packSectionsFor(PackTuning tuning) => [
  SectionSpec(
    label: 'Pack info',
    blurb: 'Name, subjects, calendar and where players start',
    icon: Icons.info_outline,
    file: 'pack.json',
    record: packInfoRecord,
  ),
  SectionSpec(
    label: 'Locations',
    blurb: 'Places players visit and what they can do there',
    icon: Icons.place_outlined,
    file: 'locations.json',
    listKey: 'locations',
    record: locationRecordFor(tuning),
  ),
  SectionSpec(
    label: 'Traits',
    blurb: 'Perks and quirks that change how a run plays',
    icon: Icons.auto_awesome_outlined,
    file: 'traits.json',
    listKey: 'traits',
    record: traitRecord,
  ),
  SectionSpec(
    label: 'Characters',
    blurb: 'Who the player can be',
    icon: Icons.person_outline,
    file: 'characters.json',
    listKey: 'characters',
    record: characterRecord,
  ),
  SectionSpec(
    label: 'Books',
    blurb: 'What players study, tier by tier',
    icon: Icons.menu_book_outlined,
    file: 'books.json',
    listKey: 'books',
    record: bookRecordFor(tuning),
  ),
  SectionSpec(
    label: 'Items',
    blurb: 'Things players can collect and use',
    icon: Icons.inventory_2_outlined,
    file: 'items.json',
    listKey: 'items',
    record: itemRecord,
  ),
];

/// Sections for a pack that keeps the engine's default tuning (tests and previews).
final packSections = packSectionsFor(const PackTuning());
