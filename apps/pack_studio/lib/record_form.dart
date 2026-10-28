import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'image_field.dart';
import 'schema.dart';
import 'theme.dart';

const String _kOtherSentinel = '__studio_custom_other__';

dynamic _deepCopy(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.fromEntries(
      value.entries.map((e) => MapEntry(e.key.toString(), _deepCopy(e.value))),
    );
  }
  if (value is List) {
    return value.map(_deepCopy).toList();
  }
  return value;
}

Map<String, dynamic> _setFieldKey(
  Map<String, dynamic> original,
  String targetKey,
  Object? newValue,
) {
  final result = <String, dynamic>{};
  bool found = false;
  for (final entry in original.entries) {
    if (entry.key == targetKey) {
      result[entry.key] = newValue;
      found = true;
    } else {
      result[entry.key] = entry.value;
    }
  }
  if (!found) {
    result[targetKey] = newValue;
  }
  return result;
}

Map<String, dynamic> _removeFieldKey(
  Map<String, dynamic> original,
  String targetKey,
) {
  final result = <String, dynamic>{};
  for (final entry in original.entries) {
    if (entry.key != targetKey) {
      result[entry.key] = entry.value;
    }
  }
  return result;
}

InputDecoration _studioInputDecoration({
  String? hintText,
  String? errorText,
}) {
  return InputDecoration(
    filled: true,
    fillColor: StudioColors.panel,
    hintText: hintText,
    hintStyle: const TextStyle(color: StudioColors.inkSoft),
    errorText: errorText,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: StudioColors.panelBorder, width: 2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: StudioColors.accent, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.redAccent, width: 2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.redAccent, width: 2),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: StudioColors.panelBorder, width: 2),
    ),
  );
}

class RecordForm extends StatefulWidget {
  const RecordForm({
    super.key,
    required this.spec,
    required this.value,
    required this.onChanged,
    required this.openJson,
  });

  final RecordSpec spec;
  final Map<String, dynamic> value;
  final ValueChanged<Map<String, dynamic>> onChanged;

  /// Opens an advanced editor for one raw value. Completes with the edited value, or null when cancelled.
  final Future<dynamic> Function(String title, dynamic value) openJson;

  @override
  State<RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends State<RecordForm> {
  Future<void> _editAdvancedRecord() async {
    final res = await widget.openJson(
      'This ${widget.spec.noun}',
      _deepCopy(widget.value),
    );
    if (!mounted || res == null) return;
    if (res is Map) {
      final converted = Map<String, dynamic>.fromEntries(
        res.entries.map((e) => MapEntry(e.key.toString(), e.value)),
      );
      widget.onChanged(converted);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _FieldListBuilder(
          fields: widget.spec.fields,
          record: widget.value,
          onChanged: widget.onChanged,
          openJson: widget.openJson,
          keyPrefix: null,
        ),
        const SizedBox(height: 28),
        const Divider(color: StudioColors.rule, thickness: 1.5),
        const SizedBox(height: 8),
        const Text(
          'Advanced',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: StudioColors.inkSoft,
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: TextButton.icon(
              key: const ValueKey('advanced-record'),
              style: TextButton.styleFrom(
                foregroundColor: StudioColors.inkSoft,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onPressed: _editAdvancedRecord,
              icon: const Icon(Icons.code, size: 18),
              label: Text(
                'Edit every field of this ${widget.spec.noun} (advanced)',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldListBuilder extends StatelessWidget {
  const _FieldListBuilder({
    required this.fields,
    required this.record,
    required this.onChanged,
    required this.openJson,
    required this.keyPrefix,
  });

  final List<FieldSpec> fields;
  final Map<String, dynamic> record;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final Future<dynamic> Function(String title, dynamic value) openJson;
  final String? keyPrefix;

  String _fieldKeyName(String fieldKey) {
    if (keyPrefix == null) {
      return 'field:$fieldKey';
    }
    return '$keyPrefix/$fieldKey';
  }

  String _addKeyName(String fieldKey) {
    if (keyPrefix == null) {
      return 'add:$fieldKey';
    }
    return '$keyPrefix/add:$fieldKey';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < fields.length; i++) ...[
          if (i > 0) const SizedBox(height: 20),
          _buildField(context, fields[i]),
        ],
      ],
    );
  }

  Widget _buildField(BuildContext context, FieldSpec field) {
    final fullFieldKey = _fieldKeyName(field.key);
    switch (field.kind) {
      case FieldKind.text:
      case FieldKind.multiline:
        return _TextFieldWidget(
          field: field,
          record: record,
          onChanged: onChanged,
          fieldKeyStr: fullFieldKey,
        );
      case FieldKind.integer:
      case FieldKind.number:
        return _NumberFieldWidget(
          field: field,
          record: record,
          onChanged: onChanged,
          fieldKeyStr: fullFieldKey,
        );
      case FieldKind.toggle:
        return _ToggleFieldWidget(
          field: field,
          record: record,
          onChanged: onChanged,
          fieldKeyStr: fullFieldKey,
        );
      case FieldKind.choice:
        return _ChoiceFieldWidget(
          field: field,
          record: record,
          onChanged: onChanged,
          fieldKeyStr: fullFieldKey,
        );
      case FieldKind.stringList:
        return _StringListFieldWidget(
          field: field,
          record: record,
          onChanged: onChanged,
          fieldKeyStr: fullFieldKey,
        );
      case FieldKind.group:
        return _GroupFieldWidget(
          field: field,
          record: record,
          onChanged: onChanged,
          openJson: openJson,
          keyPrefix: keyPrefix,
        );
      case FieldKind.recordList:
        return _RecordListFieldWidget(
          field: field,
          record: record,
          onChanged: onChanged,
          openJson: openJson,
          fieldKeyStr: fullFieldKey,
          addKeyStr: _addKeyName(field.key),
        );
      case FieldKind.image:
        return ImageFieldWidget(
          key: ValueKey(fullFieldKey),
          field: field,
          record: record,
          onChanged: onChanged,
        );
      case FieldKind.json:
        return _JsonFieldWidget(
          field: field,
          record: record,
          onChanged: onChanged,
          openJson: openJson,
          fieldKeyStr: fullFieldKey,
        );
    }
  }
}

class _FieldHeader extends StatelessWidget {
  const _FieldHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          color: StudioColors.ink,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FieldHelp extends StatelessWidget {
  const _FieldHelp({required this.help});

  final String? help;

  @override
  Widget build(BuildContext context) {
    if (help == null || help!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        help!,
        style: const TextStyle(
          color: StudioColors.inkSoft,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _TextFieldWidget extends StatefulWidget {
  const _TextFieldWidget({
    required this.field,
    required this.record,
    required this.onChanged,
    required this.fieldKeyStr,
  });

  final FieldSpec field;
  final Map<String, dynamic> record;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final String fieldKeyStr;

  @override
  State<_TextFieldWidget> createState() => _TextFieldWidgetState();
}

/// Refuses typing or pasting that would push the text past the game's limit.
/// Text that is already too long may still be shortened or edited down.
class _LimitFormatter extends TextInputFormatter {
  _LimitFormatter(this.limit, this.onRefused);

  final TextLimit limit;
  final VoidCallback onRefused;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final tooLong = newValue.text.runes.length > limit.maxChars;
    final grew = newValue.text.runes.length > oldValue.text.runes.length;
    final newBreak = limit.singleLine && newValue.text.contains('\n') && !oldValue.text.contains('\n');
    if ((tooLong && grew) || newBreak) {
      onRefused();
      return oldValue;
    }
    return newValue;
  }
}

class _TextFieldWidgetState extends State<_TextFieldWidget> {
  late final TextEditingController _controller;
  String? _problem; // what is wrong with the typed value (e.g. not a real date)
  String? _refused; // why the last keystroke was refused

  TextCodec? get _codec => widget.field.codec;
  TextLimit? get _limit => widget.field.limit;

  String _stored(Map<String, dynamic> rec) {
    if (rec.containsKey(widget.field.key)) return rec[widget.field.key]?.toString() ?? '';
    return widget.field.defaultValue?.toString() ?? '';
  }

  String _extractText(Map<String, dynamic> rec) {
    final stored = _stored(rec);
    return _codec?.toDisplay(stored) ?? stored;
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _extractText(widget.record));
  }

  @override
  void didUpdateWidget(covariant _TextFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(widget.record, oldWidget.record)) return;
    final codec = _codec;
    // Typing "2026/1/5" stores DATE_2026010500; do not rewrite the box to
    // "2026/01/05" under the author's cursor when it already means the same.
    if (codec != null &&
        codec.validate(_controller.text) == null &&
        codec.toStored(_controller.text, _stored(widget.record)) == _stored(widget.record)) {
      return;
    }
    final newText = _extractText(widget.record);
    if (_controller.text != newText) {
      _controller.text = newText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String text) {
    final codec = _codec;
    if (codec != null && text.isNotEmpty) {
      final problem = codec.validate(text);
      setState(() {
        _problem = problem;
        _refused = null;
      });
      if (problem != null) return; // keep the last good value in the pack
      widget.onChanged(_setFieldKey(widget.record, widget.field.key, codec.toStored(text, _stored(widget.record))));
      return;
    }
    setState(() {
      _problem = codec != null && widget.field.required ? 'This is needed.' : null;
      _refused = null;
    });
    if (text.isEmpty) {
      if (codec != null && widget.field.required) return;
      if (widget.field.required) {
        widget.onChanged(_setFieldKey(widget.record, widget.field.key, ''));
      } else {
        widget.onChanged(_removeFieldKey(widget.record, widget.field.key));
      }
    } else {
      widget.onChanged(_setFieldKey(widget.record, widget.field.key, text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMultiline = widget.field.kind == FieldKind.multiline;
    final limit = _limit;
    final length = _controller.text.runes.length;
    final over = limit != null && length > limit.maxChars;
    final errorText = _problem ??
        (over ? 'Longer than the game can show ($length of ${limit.maxChars}). Shorten it.' : null) ??
        _refused;
    final decoration = _studioInputDecoration(hintText: _codec?.hint, errorText: errorText).copyWith(
      counterText: limit == null ? null : '$length / ${limit.maxChars}',
      counterStyle: TextStyle(color: over ? Colors.redAccent : StudioColors.inkSoft, fontSize: 12),
    );
    final help = [
      if (widget.field.help != null) widget.field.help!,
      if (limit != null) 'Limit: ${limit.maxChars} characters. ${limit.why}',
    ].join('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _FieldHeader(label: widget.field.label),
        Semantics(
          label: widget.field.label,
          textField: true,
          child: TextField(
            key: ValueKey(widget.fieldKeyStr),
            controller: _controller,
            minLines: isMultiline ? 3 : 1,
            maxLines: isMultiline ? 8 : 1,
            style: const TextStyle(color: StudioColors.ink, fontSize: 15),
            decoration: decoration,
            inputFormatters: limit == null
                ? null
                : [
                    _LimitFormatter(limit, () {
                      setState(
                        () => _refused = 'That would be past the limit of ${limit.maxChars} characters, '
                            'so it was not added. ${limit.why}',
                      );
                    }),
                  ],
            onChanged: _handleChanged,
          ),
        ),
        _FieldHelp(help: help.isEmpty ? null : help),
      ],
    );
  }
}

class _NumberFieldWidget extends StatefulWidget {
  const _NumberFieldWidget({
    required this.field,
    required this.record,
    required this.onChanged,
    required this.fieldKeyStr,
  });

  final FieldSpec field;
  final Map<String, dynamic> record;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final String fieldKeyStr;

  @override
  State<_NumberFieldWidget> createState() => _NumberFieldWidgetState();
}

class _NumberFieldWidgetState extends State<_NumberFieldWidget> {
  late final TextEditingController _controller;
  String? _errorText;
  num? _lastEmittedValue;
  bool _lastEmittedRemoval = false;

  String _extractText(Map<String, dynamic> rec) {
    if (rec.containsKey(widget.field.key) && rec[widget.field.key] != null) {
      return rec[widget.field.key].toString();
    }
    if (widget.field.defaultValue != null) {
      return widget.field.defaultValue.toString();
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _extractText(widget.record));
  }

  @override
  void didUpdateWidget(covariant _NumberFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.record, oldWidget.record)) {
      final hasKey = widget.record.containsKey(widget.field.key);
      final rawVal = widget.record[widget.field.key];
      if (_errorText == null) {
        if (!hasKey && _lastEmittedRemoval) {
          return;
        }
        if (hasKey && rawVal is num && _lastEmittedValue == rawVal) {
          return;
        }
      }
      final newText = _extractText(widget.record);
      if (_controller.text != newText) {
        _controller.text = newText;
        _errorText = null;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _errorText = null;
      });
      _lastEmittedRemoval = true;
      _lastEmittedValue = null;
      widget.onChanged(_removeFieldKey(widget.record, widget.field.key));
      return;
    }

    if (widget.field.kind == FieldKind.integer) {
      final parsed = int.tryParse(trimmed);
      if (parsed == null) {
        setState(() {
          _errorText = 'Enter a whole number';
        });
      } else {
        setState(() {
          _errorText = null;
        });
        _lastEmittedRemoval = false;
        _lastEmittedValue = parsed;
        widget.onChanged(_setFieldKey(widget.record, widget.field.key, parsed));
      }
    } else {
      if (!trimmed.contains('.')) {
        final parsedInt = int.tryParse(trimmed);
        if (parsedInt != null) {
          setState(() {
            _errorText = null;
          });
          _lastEmittedRemoval = false;
          _lastEmittedValue = parsedInt;
          widget.onChanged(
            _setFieldKey(widget.record, widget.field.key, parsedInt),
          );
          return;
        }
      }
      final parsedNum = num.tryParse(trimmed);
      if (parsedNum == null) {
        setState(() {
          _errorText = 'Enter a number';
        });
      } else {
        setState(() {
          _errorText = null;
        });
        _lastEmittedRemoval = false;
        _lastEmittedValue = parsedNum;
        widget.onChanged(
          _setFieldKey(widget.record, widget.field.key, parsedNum),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDecimal = widget.field.kind == FieldKind.number;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _FieldHeader(label: widget.field.label),
        Semantics(
          label: widget.field.label,
          textField: true,
          child: TextField(
            key: ValueKey(widget.fieldKeyStr),
            controller: _controller,
            keyboardType: TextInputType.numberWithOptions(
              decimal: isDecimal,
              signed: true,
            ),
            style: const TextStyle(color: StudioColors.ink, fontSize: 15),
            decoration: _studioInputDecoration(errorText: _errorText),
            onChanged: _handleChanged,
          ),
        ),
        _FieldHelp(help: widget.field.help),
      ],
    );
  }
}

class _ToggleFieldWidget extends StatelessWidget {
  const _ToggleFieldWidget({
    required this.field,
    required this.record,
    required this.onChanged,
    required this.fieldKeyStr,
  });

  final FieldSpec field;
  final Map<String, dynamic> record;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final String fieldKeyStr;

  bool _currentValue() {
    final stored = record[field.key];
    if (stored is bool) return stored;
    final def = field.defaultValue;
    if (def is bool) return def;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final val = _currentValue();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  field.label,
                  style: const TextStyle(
                    color: StudioColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Semantics(
                label: field.label,
                toggled: val,
                child: Switch(
                  key: ValueKey(fieldKeyStr),
                  value: val,
                  activeThumbColor: StudioColors.accentDark,
                  activeTrackColor: StudioColors.accent,
                  onChanged: (next) {
                    onChanged(_setFieldKey(record, field.key, next));
                  },
                ),
              ),
            ],
          ),
        ),
        _FieldHelp(help: field.help),
      ],
    );
  }
}

class _ChoiceFieldWidget extends StatefulWidget {
  const _ChoiceFieldWidget({
    required this.field,
    required this.record,
    required this.onChanged,
    required this.fieldKeyStr,
  });

  final FieldSpec field;
  final Map<String, dynamic> record;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final String fieldKeyStr;

  @override
  State<_ChoiceFieldWidget> createState() => _ChoiceFieldWidgetState();
}

class _ChoiceFieldWidgetState extends State<_ChoiceFieldWidget> {
  late final TextEditingController _customController;
  bool _otherSelectedManual = false;

  bool _isStandardChoice(String? val) {
    if (val == null) return false;
    return widget.field.choices.any((c) => c.value == val);
  }

  String? _storedString(Map<String, dynamic> rec) {
    if (!rec.containsKey(widget.field.key)) return null;
    final raw = rec[widget.field.key];
    return raw?.toString();
  }

  @override
  void initState() {
    super.initState();
    final stored = _storedString(widget.record);
    final isCustom = stored != null && !_isStandardChoice(stored);
    _otherSelectedManual = widget.field.allowCustom && isCustom;
    _customController = TextEditingController(
      text: isCustom ? stored : '',
    );
  }

  @override
  void didUpdateWidget(covariant _ChoiceFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.record, oldWidget.record)) {
      final stored = _storedString(widget.record);
      final isCustom = stored != null && !_isStandardChoice(stored);
      if (stored == null) {
        if (!_otherSelectedManual) {
          _customController.text = '';
        }
      } else if (isCustom) {
        _otherSelectedManual = widget.field.allowCustom;
        if (_customController.text != stored) {
          _customController.text = stored;
        }
      } else {
        _otherSelectedManual = false;
        _customController.text = '';
      }
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stored = _storedString(widget.record);
    final isStoredCustom = stored != null && !_isStandardChoice(stored);
    final showCustomBox =
        widget.field.allowCustom && (_otherSelectedManual || isStoredCustom);

    String? dropdownValue;
    if (showCustomBox) {
      dropdownValue = _kOtherSentinel;
    } else if (stored != null) {
      dropdownValue = stored;
    } else {
      dropdownValue = null;
    }

    final items = <DropdownMenuItem<String>>[
      for (final choice in widget.field.choices)
        DropdownMenuItem<String>(
          value: choice.value,
          child: Text(
            choice.label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: StudioColors.ink, fontSize: 15),
          ),
        ),
    ];

    if (!widget.field.allowCustom && isStoredCustom) {
      items.add(
        DropdownMenuItem<String>(
          value: stored,
          child: Text(
            '$stored (custom)',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: StudioColors.ink, fontSize: 15),
          ),
        ),
      );
    }

    if (widget.field.allowCustom) {
      items.add(
        const DropdownMenuItem<String>(
          value: _kOtherSentinel,
          child: Text(
            'Other.',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: StudioColors.ink, fontSize: 15),
          ),
        ),
      );
    }

    Choice? selectedChoice;
    if (dropdownValue != null && dropdownValue != _kOtherSentinel) {
      for (final c in widget.field.choices) {
        if (c.value == dropdownValue) {
          selectedChoice = c;
          break;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _FieldHeader(label: widget.field.label),
        Semantics(
          label: widget.field.label,
          child: DropdownButtonFormField<String>(
            key: ValueKey(widget.fieldKeyStr),
            // initialValue would not follow outside changes to the stored value.
            // ignore: deprecated_member_use
            value: dropdownValue,
            isExpanded: true,
            dropdownColor: StudioColors.paper,
            decoration: _studioInputDecoration(),
            hint: const Text(
              'Choose.',
              style: TextStyle(color: StudioColors.inkSoft, fontSize: 15),
            ),
            items: items,
            onChanged: (val) {
              if (val == null) return;
              if (val == _kOtherSentinel) {
                setState(() {
                  _otherSelectedManual = true;
                  _customController.text = '';
                });
              } else {
                setState(() {
                  _otherSelectedManual = false;
                  _customController.text = '';
                });
                widget.onChanged(
                  _setFieldKey(widget.record, widget.field.key, val),
                );
              }
            },
          ),
        ),
        if (selectedChoice?.help != null && selectedChoice!.help!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              selectedChoice.help!,
              style: const TextStyle(
                color: StudioColors.inkSoft,
                fontSize: 13,
              ),
            ),
          ),
        if (showCustomBox) ...[
          const SizedBox(height: 8),
          Semantics(
            label: '${widget.field.label} custom value',
            textField: true,
            child: TextField(
              key: ValueKey('${widget.fieldKeyStr}:custom'),
              controller: _customController,
              style: const TextStyle(color: StudioColors.ink, fontSize: 15),
              decoration: _studioInputDecoration(hintText: 'Custom value'),
              onChanged: (customText) {
                widget.onChanged(
                  _setFieldKey(widget.record, widget.field.key, customText),
                );
              },
            ),
          ),
        ],
        _FieldHelp(help: widget.field.help),
      ],
    );
  }
}

class _StringListFieldWidget extends StatefulWidget {
  const _StringListFieldWidget({
    required this.field,
    required this.record,
    required this.onChanged,
    required this.fieldKeyStr,
  });

  final FieldSpec field;
  final Map<String, dynamic> record;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final String fieldKeyStr;

  @override
  State<_StringListFieldWidget> createState() => _StringListFieldWidgetState();
}

class _StringListFieldWidgetState extends State<_StringListFieldWidget> {
  late final TextEditingController _addController;

  List<String> _currentItems() {
    final raw = widget.record[widget.field.key];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    final def = widget.field.defaultValue;
    if (def is List) {
      return def.map((e) => e.toString()).toList();
    }
    return const [];
  }

  @override
  void initState() {
    super.initState();
    _addController = TextEditingController();
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  void _addEntry() {
    final text = _addController.text.trim();
    if (text.isEmpty) return;
    final current = List<String>.from(_currentItems());
    if (current.contains(text)) {
      _addController.clear();
      return;
    }
    current.add(text);
    _addController.clear();
    widget.onChanged(_setFieldKey(widget.record, widget.field.key, current));
  }

  void _removeAt(int index) {
    final current = List<String>.from(_currentItems());
    if (index < 0 || index >= current.length) return;
    current.removeAt(index);
    widget.onChanged(_setFieldKey(widget.record, widget.field.key, current));
  }

  // onReorderItem already compensates for the removed item, unlike the old onReorder.
  void _reorder(int oldIndex, int newIndex) {
    final current = List<String>.from(_currentItems());
    final item = current.removeAt(oldIndex);
    current.insert(newIndex, item);
    widget.onChanged(_setFieldKey(widget.record, widget.field.key, current));
  }

  @override
  Widget build(BuildContext context) {
    final items = _currentItems();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _FieldHeader(label: widget.field.label),
        if (items.isNotEmpty)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: items.length,
            onReorderItem: _reorder,
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                key: ValueKey('${widget.fieldKeyStr}:$index:$item'),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: StudioColors.panel,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: StudioColors.panelBorder, width: 1.5),
                ),
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(
                          Icons.drag_handle,
                          color: StudioColors.inkSoft,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          item,
                          style: const TextStyle(
                            color: StudioColors.ink,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      tooltip: 'Remove $item',
                      icon: const Icon(
                        Icons.close,
                        color: StudioColors.inkSoft,
                      ),
                      onPressed: () => _removeAt(index),
                    ),
                  ],
                ),
              );
            },
          ),
        Row(
          children: [
            Expanded(
              child: Semantics(
                label: 'Add to ${widget.field.label}',
                textField: true,
                child: TextField(
                  key: ValueKey(widget.fieldKeyStr),
                  controller: _addController,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(color: StudioColors.ink, fontSize: 15),
                  decoration: _studioInputDecoration(hintText: 'Add.'),
                  onSubmitted: (_) => _addEntry(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: StudioColors.panel,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: StudioColors.panelBorder, width: 2),
              ),
              child: IconButton(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                tooltip: 'Add',
                icon: const Icon(Icons.add, color: StudioColors.accentDark),
                onPressed: _addEntry,
              ),
            ),
          ],
        ),
        _FieldHelp(help: widget.field.help),
      ],
    );
  }
}

class _GroupFieldWidget extends StatelessWidget {
  const _GroupFieldWidget({
    required this.field,
    required this.record,
    required this.onChanged,
    required this.openJson,
    required this.keyPrefix,
  });

  final FieldSpec field;
  final Map<String, dynamic> record;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final Future<dynamic> Function(String title, dynamic value) openJson;
  final String? keyPrefix;

  Map<String, dynamic> _nestedMap() {
    final raw = record[field.key];
    if (raw is Map) {
      return Map<String, dynamic>.fromEntries(
        raw.entries.map((e) => MapEntry(e.key.toString(), e.value)),
      );
    }
    return const <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    final nested = _nestedMap();
    return Card(
      margin: EdgeInsets.zero,
      color: StudioColors.panel,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: StudioColors.panelBorder, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              field.label,
              style: const TextStyle(
                color: StudioColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (field.help != null && field.help!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                field.help!,
                style: const TextStyle(
                  color: StudioColors.inkSoft,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _FieldListBuilder(
              fields: field.fields,
              record: nested,
              onChanged: (newNested) {
                onChanged(_setFieldKey(record, field.key, newNested));
              },
              openJson: openJson,
              keyPrefix: keyPrefix,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordElementSlot {
  _RecordElementSlot({this.initiallyExpanded = false}) : id = _nextId++;
  static int _nextId = 1;
  final int id;
  final bool initiallyExpanded;
}

class _RecordListFieldWidget extends StatefulWidget {
  const _RecordListFieldWidget({
    required this.field,
    required this.record,
    required this.onChanged,
    required this.openJson,
    required this.fieldKeyStr,
    required this.addKeyStr,
  });

  final FieldSpec field;
  final Map<String, dynamic> record;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final Future<dynamic> Function(String title, dynamic value) openJson;
  final String fieldKeyStr;
  final String addKeyStr;

  @override
  State<_RecordListFieldWidget> createState() => _RecordListFieldWidgetState();
}

class _RecordListFieldWidgetState extends State<_RecordListFieldWidget> {
  final List<_RecordElementSlot> _slots = [];
  bool _internalListMutation = false;

  List<Map<String, dynamic>> _extractElements(Map<String, dynamic> rec) {
    final raw = rec[widget.field.key];
    if (raw is List) {
      return raw.map((item) {
        if (item is Map<String, dynamic>) return item;
        if (item is Map) {
          return Map<String, dynamic>.fromEntries(
            item.entries.map((e) => MapEntry(e.key.toString(), e.value)),
          );
        }
        return <String, dynamic>{};
      }).toList();
    }
    return const [];
  }

  @override
  void initState() {
    super.initState();
    final elements = _extractElements(widget.record);
    for (int i = 0; i < elements.length; i++) {
      _slots.add(_RecordElementSlot(initiallyExpanded: false));
    }
  }

  @override
  void didUpdateWidget(covariant _RecordListFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final elements = _extractElements(widget.record);
    if (_internalListMutation && _slots.length == elements.length) {
      _internalListMutation = false;
      return;
    }
    _internalListMutation = false;
    if (_slots.length != elements.length) {
      _slots
        ..clear()
        ..addAll(
          List.generate(
            elements.length,
            (_) => _RecordElementSlot(initiallyExpanded: false),
          ),
        );
    }
  }

  void _updateElement(int index, Map<String, dynamic> newElement) {
    final elements = List<Map<String, dynamic>>.from(
      _extractElements(widget.record),
    );
    if (index < 0 || index >= elements.length) return;
    elements[index] = newElement;
    _internalListMutation = true;
    widget.onChanged(_setFieldKey(widget.record, widget.field.key, elements));
  }

  void _moveUp(int index) {
    final elements = List<Map<String, dynamic>>.from(
      _extractElements(widget.record),
    );
    if (index <= 0 || index >= elements.length) return;
    final item = elements.removeAt(index);
    elements.insert(index - 1, item);
    final slot = _slots.removeAt(index);
    _slots.insert(index - 1, slot);
    _internalListMutation = true;
    widget.onChanged(_setFieldKey(widget.record, widget.field.key, elements));
  }

  void _moveDown(int index) {
    final elements = List<Map<String, dynamic>>.from(
      _extractElements(widget.record),
    );
    if (index < 0 || index >= elements.length - 1) return;
    final item = elements.removeAt(index);
    elements.insert(index + 1, item);
    final slot = _slots.removeAt(index);
    _slots.insert(index + 1, slot);
    _internalListMutation = true;
    widget.onChanged(_setFieldKey(widget.record, widget.field.key, elements));
  }

  Future<void> _confirmAndDelete(int index, RecordSpec itemSpec) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: StudioColors.paper,
        title: Text(
          'Delete this ${itemSpec.noun}?',
          style: const TextStyle(color: StudioColors.ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: StudioColors.inkSoft),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: StudioColors.accentDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final elements = List<Map<String, dynamic>>.from(
      _extractElements(widget.record),
    );
    if (index < 0 || index >= elements.length) return;
    elements.removeAt(index);
    if (index < _slots.length) {
      _slots.removeAt(index);
    }
    _internalListMutation = true;
    widget.onChanged(_setFieldKey(widget.record, widget.field.key, elements));
  }

  Future<void> _handleAdd(RecordSpec itemSpec) async {
    Map<String, dynamic> newElement;
    final choiceKey = itemSpec.addByChoice;
    if (choiceKey != null) {
      FieldSpec? choiceField;
      for (final f in itemSpec.fields) {
        if (f.key == choiceKey) {
          choiceField = f;
          break;
        }
      }
      final choices = choiceField?.choices ?? const <Choice>[];
      final picked = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: StudioColors.paper,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: choices.length,
              itemBuilder: (ctx, i) {
                final c = choices[i];
                return ListTile(
                  title: Text(
                    c.label,
                    style: const TextStyle(
                      color: StudioColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: c.help != null
                      ? Text(
                          c.help!,
                          style: const TextStyle(color: StudioColors.inkSoft),
                        )
                      : null,
                  onTap: () => Navigator.of(ctx).pop(c.value),
                );
              },
            ),
          );
        },
      );
      if (!mounted || picked == null) return;
      final copiedBlank = _deepCopy(itemSpec.blank) as Map<String, dynamic>;
      newElement = <String, dynamic>{
        choiceKey: picked,
        ...copiedBlank,
      };
    } else {
      newElement = _deepCopy(itemSpec.blank) as Map<String, dynamic>;
    }

    final elements = List<Map<String, dynamic>>.from(
      _extractElements(widget.record),
    );
    elements.add(newElement);
    _slots.add(_RecordElementSlot(initiallyExpanded: true));
    _internalListMutation = true;
    widget.onChanged(_setFieldKey(widget.record, widget.field.key, elements));
  }

  @override
  Widget build(BuildContext context) {
    final itemSpec = widget.field.item;
    if (itemSpec == null) return const SizedBox.shrink();

    final elements = _extractElements(widget.record);
    while (_slots.length < elements.length) {
      _slots.add(_RecordElementSlot(initiallyExpanded: false));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.field.label,
                style: const TextStyle(
                  color: StudioColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: StudioColors.rule,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: StudioColors.panelBorder),
              ),
              child: Text(
                '${elements.length}',
                style: const TextStyle(
                  color: StudioColors.inkSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (widget.field.help != null && widget.field.help!.isNotEmpty)
          _FieldHelp(help: widget.field.help),
        const SizedBox(height: 8),
        for (int i = 0; i < elements.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _buildElementCard(context, i, elements[i], elements.length, itemSpec),
        ],
        if (elements.isNotEmpty) const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: OutlinedButton.icon(
            key: ValueKey(widget.addKeyStr),
            style: OutlinedButton.styleFrom(
              foregroundColor: StudioColors.accentDark,
              backgroundColor: StudioColors.panel,
              side: const BorderSide(color: StudioColors.panelBorder, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: () => _handleAdd(itemSpec),
            icon: const Icon(Icons.add),
            label: Text(
              widget.field.addLabel ?? 'Add ${itemSpec.noun}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildElementCard(
    BuildContext context,
    int index,
    Map<String, dynamic> element,
    int totalCount,
    RecordSpec itemSpec,
  ) {
    final slot = _slots[index];
    final elementKeyPrefix = '${widget.fieldKeyStr}:$index';
    final heading = itemSpec.title(element);
    final sub = itemSpec.subtitle?.call(element);

    return Card(
      key: ValueKey('slot:${widget.fieldKeyStr}:${slot.id}'),
      margin: EdgeInsets.zero,
      color: StudioColors.panel,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: StudioColors.panelBorder, width: 2),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey(elementKeyPrefix),
          initiallyExpanded: slot.initiallyExpanded,
          tilePadding: const EdgeInsets.only(left: 16, right: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          title: Text(
            heading,
            style: const TextStyle(
              color: StudioColors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: sub != null && sub.isNotEmpty
              ? Text(
                  sub,
                  style: const TextStyle(
                    color: StudioColors.inkSoft,
                    fontSize: 13,
                  ),
                )
              : null,
          trailing: PopupMenuButton<String>(
            tooltip: 'Actions for $heading',
            icon: const Icon(Icons.more_vert, color: StudioColors.ink),
            color: StudioColors.paper,
            onSelected: (action) {
              if (action == 'up') {
                _moveUp(index);
              } else if (action == 'down') {
                _moveDown(index);
              } else if (action == 'delete') {
                _confirmAndDelete(index, itemSpec);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem<String>(
                value: 'up',
                enabled: index > 0,
                child: const Text('Move up'),
              ),
              PopupMenuItem<String>(
                value: 'down',
                enabled: index < totalCount - 1,
                child: const Text('Move down'),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Text('Delete'),
              ),
            ],
          ),
          children: [
            _FieldListBuilder(
              fields: itemSpec.fields,
              record: element,
              onChanged: (updatedElement) =>
                  _updateElement(index, updatedElement),
              openJson: widget.openJson,
              keyPrefix: elementKeyPrefix,
            ),
          ],
        ),
      ),
    );
  }
}

class _JsonFieldWidget extends StatelessWidget {
  const _JsonFieldWidget({
    required this.field,
    required this.record,
    required this.onChanged,
    required this.openJson,
    required this.fieldKeyStr,
  });

  final FieldSpec field;
  final Map<String, dynamic> record;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final Future<dynamic> Function(String title, dynamic value) openJson;
  final String fieldKeyStr;

  String _summaryText(dynamic val) {
    if (val == null) return 'Not set';
    if (val is List) {
      if (val.isEmpty) return 'Not set';
      return val.length == 1 ? '1 entry' : '${val.length} entries';
    }
    if (val is Map) {
      if (val.isEmpty) return 'Not set';
      return val.length == 1 ? '1 entry' : '${val.length} entries';
    }
    if (val is String && val.isEmpty) return 'Not set';
    return '1 entry';
  }

  Future<void> _openEditor() async {
    final hasKey = record.containsKey(field.key) && record[field.key] != null;
    final dynamic initialValue;
    if (hasKey) {
      initialValue = _deepCopy(record[field.key]);
    } else if (field.defaultValue is List) {
      initialValue = <dynamic>[];
    } else {
      initialValue = <String, dynamic>{};
    }

    final result = await openJson(field.label, initialValue);
    if (result != null) {
      onChanged(_setFieldKey(record, field.key, result));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentVal = record[field.key];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _FieldHeader(label: field.label),
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: OutlinedButton.icon(
              key: ValueKey(fieldKeyStr),
              style: OutlinedButton.styleFrom(
                foregroundColor: StudioColors.ink,
                backgroundColor: StudioColors.panel,
                side: const BorderSide(
                  color: StudioColors.panelBorder,
                  width: 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onPressed: _openEditor,
              icon: const Icon(
                Icons.edit_outlined,
                size: 18,
                color: StudioColors.accentDark,
              ),
              label: Text(
                'Edit ${field.label} (advanced)',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _summaryText(currentVal),
          style: const TextStyle(
            color: StudioColors.inkSoft,
            fontSize: 13,
          ),
        ),
        _FieldHelp(help: field.help),
      ],
    );
  }
}
