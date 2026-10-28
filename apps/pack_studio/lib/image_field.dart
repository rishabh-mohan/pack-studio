import 'dart:io';

import 'package:flutter/material.dart';

import 'pack_storage.dart';
import 'schema.dart';
import 'theme.dart';

/// What an image field needs from the screen that hosts the form: where the
/// pack lives (for previews) and a way to let the author choose a picture and
/// copy it into the pack.
class ImageTools {
  const ImageTools({required this.packPath, required this.pick});

  final String packPath;

  /// Opens the system picker and imports the choice into `images/<folder>`.
  /// Returns the pack-relative path, or null when cancelled. Throws a
  /// [PackStorageException] with a plain-language reason when it can't.
  final Future<String?> Function(String folder) pick;
}

class ImageToolsScope extends InheritedWidget {
  const ImageToolsScope({super.key, required this.tools, required super.child});

  final ImageTools tools;

  static ImageTools? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ImageToolsScope>()?.tools;

  @override
  bool updateShouldNotify(ImageToolsScope oldWidget) => tools.packPath != oldWidget.tools.packPath;
}

/// A picture field: preview, choose / replace, remove. Stores a path relative
/// to the pack's `images/` folder, which is what d30mode resolves.
class ImageFieldWidget extends StatefulWidget {
  const ImageFieldWidget({
    super.key,
    required this.field,
    required this.record,
    required this.onChanged,
  });

  final FieldSpec field;
  final Map<String, dynamic> record;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  State<ImageFieldWidget> createState() => _ImageFieldWidgetState();
}

class _ImageFieldWidgetState extends State<ImageFieldWidget> {
  String? _problem;
  bool _busy = false;

  String? get _path {
    final v = widget.record[widget.field.key];
    return v is String && v.isNotEmpty ? v : null;
  }

  Future<void> _choose(ImageTools tools) async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final picked = await tools.pick(widget.field.imageFolder ?? 'misc');
      if (picked != null && mounted) {
        widget.onChanged({...widget.record, widget.field.key: picked});
      }
    } on PackStorageException catch (e) {
      if (mounted) setState(() => _problem = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clear() {
    setState(() => _problem = null);
    widget.onChanged({
      for (final e in widget.record.entries)
        if (e.key != widget.field.key) e.key: e.value,
    });
  }

  @override
  Widget build(BuildContext context) {
    final tools = ImageToolsScope.of(context);
    final path = _path;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(widget.field.label, style: const TextStyle(color: StudioColors.ink, fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        if (path != null)
          Container(
            key: ValueKey('preview:${widget.field.key}'),
            height: 140,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: StudioColors.panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: StudioColors.panelBorder, width: 2),
            ),
            child: tools == null
                ? Text(path, style: const TextStyle(color: StudioColors.inkSoft))
                : Image.file(
                    File('${tools.packPath}/images/$path'),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stack) => Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Picture not found: $path', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFB3261E))),
                    ),
                  ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.tonalIcon(
              key: ValueKey('choose:${widget.field.key}'),
              onPressed: tools == null || _busy ? null : () => _choose(tools),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(path == null ? 'Choose picture' : 'Replace picture'),
            ),
            if (path != null)
              TextButton.icon(
                key: ValueKey('clear:${widget.field.key}'),
                onPressed: _busy ? null : _clear,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove'),
              ),
          ],
        ),
        if (_problem != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_problem!, style: const TextStyle(color: Color(0xFFB3261E), fontSize: 13)),
          ),
        if (widget.field.help != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(widget.field.help!, style: const TextStyle(color: StudioColors.inkSoft, fontSize: 13)),
          ),
      ],
    );
  }
}
