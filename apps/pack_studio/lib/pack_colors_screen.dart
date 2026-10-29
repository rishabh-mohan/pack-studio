import 'package:d30_engine/d30_engine.dart';
import 'package:flutter/material.dart';

import 'pack_doc.dart';
import 'pack_storage.dart';
import 'theme.dart';

/// Saves only this pack's colorScheme; all other manifest fields are preserved.
class PackColorsScreen extends StatefulWidget {
  const PackColorsScreen({
    super.key,
    required this.pack,
    required this.storage,
  });
  final PackEntry pack;
  final PackStorage storage;
  @override
  State<PackColorsScreen> createState() => _PackColorsScreenState();
}

class _PackColorsScreenState extends State<PackColorsScreen> {
  late final _doc = PackDoc(widget.pack, widget.storage, 'pack.json');
  bool _loaded = false, _leaving = false;
  String? _loadError;
  int _reset = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final error = await _doc.load();
    if (mounted) {
      setState(() {
        _loadError = error;
        _loaded = true;
      });
    }
  }

  @override
  void dispose() {
    _doc.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _raw {
    final value = _doc.root['colorScheme'];
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  Map<String, dynamic> get _overrides {
    final value = _raw['colors'];
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  PackColorScheme get _scheme {
    try {
      return PackColorScheme.fromJson(_doc.root['colorScheme']);
    } on FormatException {
      return const PackColorScheme();
    }
  }

  String? get _schemeError {
    try {
      PackColorScheme.fromJson(_doc.root['colorScheme']);
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  void _preset(String preset) => setState(() {
    final extraColors = _overrides
      ..removeWhere((key, value) => PackColorScheme.roles.containsKey(key));
    final value = _raw..['preset'] = preset;
    value.remove('colors');
    if (extraColors.isNotEmpty) value['colors'] = extraColors;
    _doc.root['colorScheme'] = value;
    _reset++;
    _doc.changed();
  });
  void _color(String role, String hex) => setState(() {
    _doc.root['colorScheme'] = {
      ..._raw,
      'colors': {..._overrides, role: hex.toUpperCase()},
    };
    _doc.changed();
  });
  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    await _doc.flush();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = _scheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _leave),
          title: const Text('Color scheme'),
          backgroundColor: StudioColors.accent,
          foregroundColor: Colors.white,
        ),
        body: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? Center(child: Text(_loadError!))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    widget.pack.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Saved with this pack. d30mode uses these colors for its mode card, pack icon, and game interface.',
                  ),
                  const SizedBox(height: 16),
                  PackColorPreview(scheme: scheme, name: widget.pack.name),
                  const SizedBox(height: 16),
                  const Text(
                    'Presets',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const Text(
                    'Choosing a preset resets the custom colors below.',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in PackColorScheme.presetNames.entries)
                        ChoiceChip(
                          key: ValueKey('palette:${entry.key}'),
                          label: Text(entry.value),
                          avatar: CircleAvatar(
                            backgroundColor: Color(
                              PackColorScheme(preset: entry.key)
                                  .color('accent'),
                            ),
                            radius: 9,
                          ),
                          selected: scheme.preset == entry.key,
                          onSelected: (_) => _preset(entry.key),
                        ),
                    ],
                  ),
                  if (_schemeError case final error?)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  const Text(
                    'Custom colors',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const Text(
                    'Enter #RRGGBB. Invalid or incomplete colors are not saved.',
                  ),
                  const SizedBox(height: 12),
                  for (final role in PackColorScheme.roles.entries)
                    _ColorField(
                      key: ValueKey('color:$_reset:${role.key}'),
                      role: role.key,
                      label: role.value,
                      value: PackColorScheme.hex(scheme.color(role.key)),
                      onChanged: (hex) => _color(role.key, hex),
                    ),
                  ValueListenableBuilder(
                    valueListenable: _doc.status,
                    builder: (context, status, child) => Text(
                      status,
                      key: const ValueKey('palette-save-status'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
      ),
    );
  }
}

class _ColorField extends StatefulWidget {
  const _ColorField({
    super.key,
    required this.role,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String role, label, value;
  final ValueChanged<String> onChanged;
  @override
  State<_ColorField> createState() => _ColorFieldState();
}

class _ColorFieldState extends State<_ColorField> {
  late final _text = TextEditingController(text: widget.value);
  String? _error;
  @override
  void didUpdateWidget(covariant _ColorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        _error == null &&
        _text.text.toUpperCase() != widget.value) {
      _text.text = widget.value;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      key: ValueKey('hex:${widget.role}'),
      controller: _text,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: _error,
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(
                0xFF000000 | int.parse(widget.value.substring(1), radix: 16),
              ),
              border: Border.all(color: Colors.black26),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const SizedBox(width: 24, height: 24),
          ),
        ),
        border: const OutlineInputBorder(),
      ),
      onChanged: (value) {
        final valid = PackColorScheme.isHex(value);
        setState(() => _error = valid ? null : 'Use a color such as #367EB3');
        if (valid) widget.onChanged(value);
      },
    ),
  );
}

class PackColorPreview extends StatelessWidget {
  const PackColorPreview({super.key, required this.scheme, required this.name});
  final PackColorScheme scheme;
  final String name;
  @override
  Widget build(BuildContext context) {
    Color color(String role) => Color(scheme.color(role));
    return Container(
      key: const ValueKey('palette-preview'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color('page'),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color('panelBorder'), width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color('iconBackground'),
                foregroundColor: color('iconForeground'),
                child: const Icon(Icons.extension),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: color('ink'),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color('panel'),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color('panelBorder')),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Game preview',
                  style: TextStyle(
                    color: color('ink'),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Panels, text and controls',
                  style: TextStyle(color: color('inkSoft')),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: color('accent'),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color('accentDark'), width: 2),
                  ),
                  child: Text(
                    'Study',
                    style: TextStyle(color: color('onAccent')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
