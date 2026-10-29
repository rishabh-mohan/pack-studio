import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'own_events.dart';
import 'pack_storage.dart';
import 'theme.dart';

/// Make or change one of your own events: when it happens, where, and what is
/// said, asked and given, one step after another. Choices with their replies
/// and rewards are steps too; anything fancier is raw data under Advanced.
class EventEditorScreen extends StatefulWidget {
  const EventEditorScreen({super.key, required this.pack, required this.storage, this.eventId});

  final PackEntry pack;
  final PackStorage storage;

  /// Null makes a new event.
  final int? eventId;

  @override
  State<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends State<EventEditorScreen> {
  static const _file = 'events/events.json';
  static const _newSpeaker = -1;

  Map<String, dynamic> _doc = {};
  OwnEvent? _event;
  final _speakers = <int, String>{};
  final _locations = <int, String>{};
  final _items = <int, String>{};
  final _traits = <int, String>{};
  List<String> _subjects = const [];
  bool _dirty = false;
  bool _isNew = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<Map<String, dynamic>> _read(String file) async {
    try {
      final decoded = jsonDecode(await widget.storage.read(widget.pack, file));
      return decoded is Map<String, dynamic> ? decoded : {};
    } on PathNotFoundException {
      return {};
    }
  }

  Future<void> _load() async {
    final doc = await _read(_file);
    final locations = await _read('locations.json');
    final manifest = await _read('pack.json');
    final items = await _read('items.json');
    final traits = await _read('traits.json');
    if (!mounted) return;
    final stored = widget.eventId == null
        ? null
        : (doc['events'] as List? ?? const []).cast<Map<String, dynamic>>().where((e) => e['id'] == widget.eventId).firstOrNull;
    setState(() {
      _doc = doc;
      _isNew = stored == null;
      _event = stored == null ? OwnEvent(id: nextEventId(doc)) : OwnEvent.fromEvent(stored);
      for (final s in (doc['speakers'] as List? ?? const []).cast<Map<String, dynamic>>()) {
        _speakers[(s['id'] as num).toInt()] = s['name'] as String? ?? '';
      }
      for (final l in (locations['locations'] as List? ?? const []).cast<Map<String, dynamic>>()) {
        _locations[(l['id'] as num).toInt()] = l['name'] as String? ?? 'Location ${l['id']}';
      }
      for (final i in (items['items'] as List? ?? const []).cast<Map<String, dynamic>>()) {
        _items[(i['id'] as num).toInt()] = i['name'] as String? ?? 'Item ${i['id']}';
      }
      for (final t in (traits['traits'] as List? ?? const []).cast<Map<String, dynamic>>()) {
        _traits[(t['id'] as num).toInt()] = t['name'] as String? ?? 'Trait ${t['id']}';
      }
      _subjects = [for (final s in manifest['subjects'] as List? ?? const []) '$s'];
    });
  }

  void _touch() => setState(() {
    _dirty = true;
    _error = null;
  });

  Future<bool> _save() async {
    final event = _event!;
    final problem = problemWith(event);
    if (problem != null) {
      setState(() => _error = problem);
      return false;
    }
    var doc = saveOwnEvent(
      _doc,
      event,
      subjects: _subjects,
      names: EffectNames(items: _items, traits: _traits, locations: _locations),
    );
    doc['speakers'] = [
      for (final e in _speakers.entries) {'id': e.key, 'name': e.value},
    ];
    if ((doc['speakers'] as List).isEmpty) doc.remove('speakers');
    try {
      await widget.storage.write(widget.pack, _file, '${const JsonEncoder.withIndent('  ').convert(doc)}\n');
    } on PackStorageException catch (e) {
      setState(() => _error = e.message);
      return false;
    }
    final loads = await widget.storage.check(widget.pack);
    if (!mounted) return true;
    setState(() {
      _doc = doc;
      _dirty = false;
      _isNew = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loads == null ? 'Saved.' : 'Saved, but the pack does not load yet: $loads')),
    );
    return true;
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this event?'),
        content: Text('"${_event!.name.isEmpty ? 'Untitled event' : _event!.name}" and its scenes will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final doc = deleteEvent(_doc, _event!.id);
    await widget.storage.write(widget.pack, _file, '${const JsonEncoder.withIndent('  ').convert(doc)}\n');
    if (mounted) {
      _dirty = false;
      Navigator.pop(context);
    }
  }

  Future<void> _askToLeave() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save your changes?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'stay'), child: const Text('Keep editing')),
          TextButton(onPressed: () => Navigator.pop(context, 'discard'), child: const Text('Discard')),
          TextButton(onPressed: () => Navigator.pop(context, 'save'), child: const Text('Save')),
        ],
      ),
    );
    if (!mounted || choice == null || choice == 'stay') return;
    if (choice == 'save' && !await _save()) return;
    if (!mounted) return;
    setState(() => _dirty = false);
    Navigator.pop(context);
  }

  Widget _speakerField(int value, ValueChanged<int> onChanged) {
    final ids = {meSpeakerId, ..._speakers.keys};
    return DropdownButtonFormField<int>(
      initialValue: ids.contains(value) ? value : meSpeakerId,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Who speaks', isDense: true, border: OutlineInputBorder()),
      items: [
        const DropdownMenuItem(value: meSpeakerId, child: Text('Me')),
        for (final e in _speakers.entries) DropdownMenuItem(value: e.key, child: Text(e.value.isEmpty ? 'Speaker ${e.key}' : e.value)),
        const DropdownMenuItem(value: _newSpeaker, child: Text('New character…')),
      ],
      onChanged: (id) async {
        if (id == null) return;
        if (id != _newSpeaker) {
          onChanged(id);
          _touch();
          return;
        }
        final name = await _askName();
        if (name == null || name.isEmpty) {
          setState(() {});
          return;
        }
        final newId = nextSpeakerId({
          'speakers': [
            for (final e in _speakers.entries) {'id': e.key},
          ],
        });
        setState(() => _speakers[newId] = name);
        onChanged(newId);
        _touch();
      },
    );
  }

  Future<String?> _askName() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New character'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Add')),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Widget _stepCard(int index, EventStep step) {
    final steps = _event!.steps;
    return Card(
      key: ObjectKey(step),
      color: StudioColors.panel,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: StudioColors.panelBorder, width: 2)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  switch (step) {
                    LineStep() => 'Line',
                    ChoiceStep() => 'Choice',
                    RewardStep() => 'Reward',
                  },
                  style: const TextStyle(fontWeight: FontWeight.w700, color: StudioColors.accentDark),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Move up',
                  icon: const Icon(Icons.arrow_upward, size: 20),
                  onPressed: index == 0
                      ? null
                      : () => setState(() {
                          steps.insert(index - 1, steps.removeAt(index));
                          _dirty = true;
                        }),
                ),
                IconButton(
                  tooltip: 'Move down',
                  icon: const Icon(Icons.arrow_downward, size: 20),
                  onPressed: index == steps.length - 1
                      ? null
                      : () => setState(() {
                          steps.insert(index + 1, steps.removeAt(index));
                          _dirty = true;
                        }),
                ),
                IconButton(
                  tooltip: 'Remove this step',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => setState(() {
                    steps.removeAt(index);
                    _dirty = true;
                  }),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: switch (step) {
                LineStep() => _lineForm(step),
                ChoiceStep() => _choiceForm(step),
                RewardStep() => _rewardForm(step),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _textField(String label, String value, ValueChanged<String> onChanged, {int lines = 3, Key? key}) => TextFormField(
    key: key,
    initialValue: value,
    minLines: 1,
    maxLines: lines,
    decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
    onChanged: (v) {
      onChanged(v);
      _touch();
    },
  );

  Widget _lineForm(LineStep s) => Column(
    children: [
      _speakerField(s.speakerId, (id) => s.speakerId = id),
      const SizedBox(height: 8),
      _textField('What is said', s.text, (v) => s.text = v),
    ],
  );

  Widget _choiceForm(ChoiceStep s) => Column(
    children: [
      _textField('The question', s.question, (v) => s.question = v),
      for (var i = 0; i < s.options.length; i++) ...[
        const SizedBox(height: 10),
        Container(
          key: ObjectKey(s.options[i]),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: StudioColors.paper, borderRadius: BorderRadius.circular(10), border: Border.all(color: StudioColors.panelBorder)),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _textField('Answer ${i + 1}', s.options[i].label, (v) => s.options[i].label = v, lines: 2)),
                  IconButton(
                    tooltip: 'Remove this answer',
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: s.options.length <= 2
                        ? null
                        : () => setState(() {
                            s.options.removeAt(i);
                            _dirty = true;
                          }),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _speakerField(s.options[i].replySpeakerId, (id) => s.options[i].replySpeakerId = id),
              const SizedBox(height: 8),
              _textField('Reply (optional)', s.options[i].reply, (v) => s.options[i].reply = v),
              if (_event!.advanced) _effectsSection(s.options[i]),
            ],
          ),
        ),
      ],
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() {
            s.options.add(ChoiceOption());
            _dirty = true;
          }),
          icon: const Icon(Icons.add),
          label: const Text('Add an answer'),
        ),
      ),
    ],
  );

  /// What picking this answer does, one effect after another (Advanced effects).
  Widget _effectsSection(ChoiceOption o) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 12),
      const Text('Effects of this answer', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: StudioColors.accentDark)),
      for (var i = 0; i < o.effects.length; i++) _effectRow(o, i),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: ValueKey('add-effect:${identityHashCode(o)}'),
          onPressed: () => setState(() {
            o.effects.add(EventEffect());
            _dirty = true;
          }),
          icon: const Icon(Icons.add),
          label: const Text('Add an effect'),
        ),
      ),
    ],
  );

  Map<int, String> _targetsFor(EffectKind kind) => switch (kind) {
    EffectKind.item => _items,
    EffectKind.trait => _traits,
    _ => _locations,
  };

  Widget _effectRow(ChoiceOption o, int index) {
    final f = o.effects[index];
    final targets = _targetsFor(f.kind);
    return Container(
      key: ObjectKey(f),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 10),
      decoration: BoxDecoration(color: StudioColors.panel, borderRadius: BorderRadius.circular(10), border: Border.all(color: StudioColors.panelBorder)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<EffectKind>(
                  initialValue: f.kind,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Effect', isDense: true, border: OutlineInputBorder()),
                  items: [for (final k in EffectKind.values) DropdownMenuItem(value: k, child: Text(k.label))],
                  onChanged: (k) => setState(() {
                    if (k == null) return;
                    f.kind = k;
                    f.targetId = null; // an item number means nothing as a place
                    if (!k.canLose) f.lose = false;
                    _dirty = true;
                  }),
                ),
              ),
              IconButton(
                tooltip: 'Remove this effect',
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => setState(() {
                  o.effects.removeAt(index);
                  _dirty = true;
                }),
              ),
            ],
          ),
          if (f.kind.canLose) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Gain')),
                  ButtonSegment(value: true, label: Text('Lose')),
                ],
                selected: {f.lose},
                onSelectionChanged: (s) => setState(() {
                  f.lose = s.first;
                  _dirty = true;
                }),
              ),
            ),
          ],
          if (f.kind == EffectKind.stat && _subjects.isNotEmpty) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: f.subjectIndex < _subjects.length ? f.subjectIndex : 0,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Subject', isDense: true, border: OutlineInputBorder()),
              items: [for (var i = 0; i < _subjects.length; i++) DropdownMenuItem(value: i, child: Text(_subjects[i]))],
              onChanged: (i) => setState(() {
                f.subjectIndex = i ?? 0;
                _dirty = true;
              }),
            ),
          ],
          if (f.kind.hasTarget) ...[
            const SizedBox(height: 8),
            if (targets.isNotEmpty)
              DropdownButtonFormField<int>(
                initialValue: targets.containsKey(f.targetId) ? f.targetId : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: _targetLabel(f.kind), isDense: true, border: const OutlineInputBorder()),
                items: [for (final e in targets.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (id) => setState(() {
                  f.targetId = id;
                  _dirty = true;
                }),
              )
            else
              TextFormField(
                initialValue: f.targetId?.toString() ?? '',
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '${_targetLabel(f.kind)} number',
                  helperText: 'This pack has none of its own yet; use the number of one from the game.',
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) {
                  f.targetId = int.tryParse(v);
                  _touch();
                },
              ),
          ],
          if (f.kind.hasAmount) ...[
            const SizedBox(height: 8),
            TextFormField(
              initialValue: '${f.amount}',
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: f.kind == EffectKind.item ? 'How many' : 'How much', isDense: true, border: const OutlineInputBorder()),
              onChanged: (v) {
                f.amount = int.tryParse(v) ?? 0;
                _touch();
              },
            ),
          ],
        ],
      ),
    );
  }

  String _targetLabel(EffectKind kind) => switch (kind) {
    EffectKind.item => 'Which item',
    EffectKind.trait => 'Which trait',
    _ => 'Which place',
  };

  /// "Advanced effects": off hides them; turning it off with effects in place
  /// asks first, because it removes them.
  Future<void> _setAdvanced(bool on) async {
    final event = _event!;
    if (!on && event.hasEffects) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove all effects?'),
          content: const Text('Turning this off takes the effects off every answer.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep them')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      for (final s in event.steps) {
        if (s is ChoiceStep) {
          for (final o in s.options) {
            o.effects.clear();
          }
        }
      }
    }
    setState(() {
      event.advanced = on;
      _dirty = true;
    });
  }

  static String _tickLabel(int tick) => switch (tick) {
    0 => 'Any time of day',
    14 => 'Evening',
    _ => 'Time slot $tick',
  };

  Widget _rewardForm(RewardStep s) => Column(
    children: [
      DropdownButtonFormField<RewardKind>(
        initialValue: s.kind,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'What you get', isDense: true, border: OutlineInputBorder()),
        items: [for (final k in RewardKind.values) DropdownMenuItem(value: k, child: Text(k.label))],
        onChanged: (k) => setState(() {
          s.kind = k ?? s.kind;
          _dirty = true;
        }),
      ),
      if (s.kind == RewardKind.stat && _subjects.isNotEmpty) ...[
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: s.subjectIndex < _subjects.length ? s.subjectIndex : 0,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Subject', isDense: true, border: OutlineInputBorder()),
          items: [for (var i = 0; i < _subjects.length; i++) DropdownMenuItem(value: i, child: Text(_subjects[i]))],
          onChanged: (i) => setState(() {
            s.subjectIndex = i ?? 0;
            _dirty = true;
          }),
        ),
      ],
      const SizedBox(height: 8),
      TextFormField(
        initialValue: '${s.amount}',
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'How much', isDense: true, border: OutlineInputBorder()),
        onChanged: (v) {
          s.amount = int.tryParse(v) ?? 0;
          _touch();
        },
      ),
      const SizedBox(height: 8),
      _textField('What it says (optional)', s.text, (v) => s.text = v),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final event = _event;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _askToLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: StudioColors.accent,
          foregroundColor: Colors.white,
          title: Text(event == null ? 'Event' : (_isNew ? 'New event' : 'Edit event')),
          actions: [
            if (event != null && !_isNew) IconButton(tooltip: 'Delete this event', icon: const Icon(Icons.delete_outline), onPressed: _delete),
          ],
        ),
        body: event == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _textField('Event name', event.name, (v) => event.name = v, lines: 1, key: const ValueKey('event-name')),
                  const SizedBox(height: 16),
                  const Text('When', style: TextStyle(fontWeight: FontWeight.w700, color: StudioColors.ink)),
                  const SizedBox(height: 6),
                  SegmentedButton<bool>(
                    key: const ValueKey('event-when'),
                    segments: const [
                      ButtonSegment(value: false, label: Text('Any day')),
                      ButtonSegment(value: true, label: Text('A set day')),
                    ],
                    selected: {event.onSetDay},
                    onSelectionChanged: (s) => setState(() {
                      event.onSetDay = s.first;
                      _dirty = true;
                    }),
                  ),
                  if (event.onSetDay) ...[
                    const SizedBox(height: 8),
                    _textField('Day (YYYY/MM/DD)', event.date, (v) => event.date = v, lines: 1, key: const ValueKey('event-date')),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      key: const ValueKey('event-tick'),
                      initialValue: event.tick,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Time of day', isDense: true, border: OutlineInputBorder()),
                      items: [for (var t = 0; t <= 14; t++) DropdownMenuItem(value: t, child: Text(_tickLabel(t)))],
                      onChanged: (t) => setState(() {
                        event.tick = t ?? 0;
                        _dirty = true;
                      }),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    key: const ValueKey('event-where'),
                    initialValue: _locations.containsKey(event.locationId) ? event.locationId : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Where', isDense: true, border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Anywhere')),
                      for (final e in _locations.entries) DropdownMenuItem<int?>(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (id) => setState(() {
                      event.locationId = id;
                      _dirty = true;
                    }),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: StudioColors.accent,
                    title: const Text('Happens only once'),
                    subtitle: const Text('Off: it can come back again and again.', style: TextStyle(fontSize: 12)),
                    value: event.once,
                    onChanged: (on) => setState(() {
                      event.once = on;
                      _dirty = true;
                    }),
                  ),
                  SwitchListTile(
                    key: const ValueKey('event-advanced'),
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: StudioColors.accent,
                    title: const Text('Advanced effects'),
                    subtitle: const Text(
                      'Let answers give or take gold, stamina, points, items and traits, or move you somewhere.',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: event.advanced,
                    onChanged: _setAdvanced,
                  ),
                  const SizedBox(height: 8),
                  const Text('What happens', style: TextStyle(fontWeight: FontWeight.w700, color: StudioColors.ink)),
                  const SizedBox(height: 8),
                  for (var i = 0; i < event.steps.length; i++) _stepCard(i, event.steps[i]),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const ValueKey('add-line'),
                        onPressed: () => setState(() {
                          event.steps.add(LineStep());
                          _dirty = true;
                        }),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Add a line'),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('add-choice'),
                        onPressed: () => setState(() {
                          event.steps.add(ChoiceStep());
                          _dirty = true;
                        }),
                        icon: const Icon(Icons.call_split),
                        label: const Text('Add a choice'),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('add-reward'),
                        onPressed: () => setState(() {
                          event.steps.add(RewardStep());
                          _dirty = true;
                        }),
                        icon: const Icon(Icons.card_giftcard),
                        label: const Text('Add a reward'),
                      ),
                    ],
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const ValueKey('event-save'),
                    onPressed: _save,
                    style: FilledButton.styleFrom(backgroundColor: StudioColors.accent),
                    child: const Text('Save event'),
                  ),
                ],
              ),
      ),
    );
  }
}
