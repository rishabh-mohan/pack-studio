import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'image_field.dart';
import 'json_value_screen.dart';
import 'pack_doc.dart';
import 'pack_storage.dart';
import 'record_form.dart';
import 'schema.dart';
import 'theme.dart';

Map<String, dynamic> _deepCopy(Map<String, dynamic> m) => {
  for (final e in m.entries) e.key: _copyValue(e.value),
};

dynamic _copyValue(dynamic v) => switch (v) {
  Map<String, dynamic>() => _deepCopy(v),
  List() => [for (final x in v) _copyValue(x)],
  _ => v,
};

/// "Saving…" / "All changes saved" / a problem, under a screen title.
class _SaveStatus extends StatelessWidget {
  const _SaveStatus(this.doc);

  final PackDoc doc;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: doc.status,
    builder: (context, text, _) => text.isEmpty
        ? const SizedBox.shrink()
        : ValueListenableBuilder<bool>(
            valueListenable: doc.problem,
            builder: (context, bad, _) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(text, style: TextStyle(fontSize: 12, color: bad ? const Color(0xFFB3261E) : StudioColors.inkSoft)),
            ),
          ),
  );
}

/// The entries of one kind of content, each as its own button.
class SectionListScreen extends StatefulWidget {
  const SectionListScreen({super.key, required this.pack, required this.storage, required this.section});

  final PackEntry pack;
  final PackStorage storage;
  final SectionSpec section;

  @override
  State<SectionListScreen> createState() => _SectionListScreenState();
}

class _SectionListScreenState extends State<SectionListScreen> {
  late final PackDoc _doc = PackDoc(widget.pack, widget.storage, widget.section.file);
  String? _error;
  bool _loaded = false;

  SectionSpec get _s => widget.section;
  RecordSpec get _spec => _s.record;

  List<Map<String, dynamic>> get _records =>
      ((_doc.root[_s.listKey] as List?) ?? const []).cast<Map<String, dynamic>>();

  @override
  void initState() {
    super.initState();
    _doc.load().then((error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loaded = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _doc.dispose();
    super.dispose();
  }

  void _setRecords(List<Map<String, dynamic>> records) {
    setState(() => _doc.root = {..._doc.root, _s.listKey!: records});
    _doc.changed();
  }

  int _nextId() {
    final ids = [for (final r in _records) if (r[_s.idKey] is int) r[_s.idKey] as int];
    return ids.isEmpty ? 1 : ids.reduce((a, b) => a > b ? a : b) + 1;
  }

  Future<void> _edit(int index) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => RecordEditorScreen(
        spec: _spec,
        record: _records[index],
        subtitle: 'ID ${_records[index][_s.idKey]}',
        doc: _doc,
        onChanged: (r) => _setRecords([..._records]..[index] = r),
      ),
    ));
    if (mounted) setState(() {});
  }

  Future<void> _add() async {
    final record = {_s.idKey: _nextId(), ..._deepCopy(_spec.blank)};
    _setRecords([..._records, record]);
    await _edit(_records.length - 1);
  }

  void _duplicate(int index) {
    final copy = {..._deepCopy(_records[index]), _s.idKey: _nextId()};
    if (copy['name'] is String) copy['name'] = '${copy['name']} copy';
    _setRecords([..._records, copy]);
  }

  Future<void> _delete(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete this ${_spec.noun}?'),
        content: Text('"${_spec.title(_records[index])}" will be removed from the pack.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) _setRecords([..._records]..removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final records = _loaded && _error == null ? _records : const <Map<String, dynamic>>[];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: StudioColors.accent,
        foregroundColor: Colors.white,
        title: Text(_s.label),
      ),
      floatingActionButton: _loaded && _error == null
          ? FloatingActionButton.extended(
              onPressed: _add,
              backgroundColor: StudioColors.accent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: Text('Add ${_spec.noun}'),
            )
          : null,
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: const TextStyle(color: Color(0xFFB3261E)))))
              : Column(
                  children: [
                    _SaveStatus(_doc),
                    Expanded(
                      child: records.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Text('No ${_spec.noun}s yet.\nTap "Add ${_spec.noun}" to make the first one.',
                                    textAlign: TextAlign.center, style: const TextStyle(color: StudioColors.inkSoft, height: 1.5)),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                              itemCount: records.length,
                              itemBuilder: (context, i) => _EntryButton(
                                key: ValueKey('entry:$i'),
                                icon: _s.icon,
                                title: _spec.title(records[i]),
                                subtitle: _spec.subtitle?.call(records[i]),
                                id: records[i][_s.idKey],
                                onTap: () => _edit(i),
                                onDuplicate: () => _duplicate(i),
                                onDelete: () => _delete(i),
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }
}

class _EntryButton extends StatelessWidget {
  const _EntryButton({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.id,
    required this.onTap,
    required this.onDuplicate,
    required this.onDelete,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Object? id;
  final VoidCallback onTap;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: StudioColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: StudioColors.panelBorder, width: 2),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
            child: Row(
              children: [
                Icon(icon, color: StudioColors.accent, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 17, color: StudioColors.ink, fontWeight: FontWeight.w600)),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Text(subtitle!, style: const TextStyle(fontSize: 13, color: StudioColors.inkSoft)),
                    ],
                  ),
                ),
                if (id != null) Text('#$id', style: const TextStyle(fontSize: 12, color: StudioColors.inkSoft)),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  onSelected: (v) => v == 'copy' ? onDuplicate() : onDelete(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'copy', child: Text('Duplicate')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The form for one entry. Changes are saved as you make them.
class RecordEditorScreen extends StatefulWidget {
  const RecordEditorScreen({
    super.key,
    required this.spec,
    required this.record,
    required this.doc,
    required this.onChanged,
    this.subtitle,
  });

  final RecordSpec spec;
  final Map<String, dynamic> record;
  final PackDoc doc;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final String? subtitle;

  @override
  State<RecordEditorScreen> createState() => _RecordEditorScreenState();
}

class _RecordEditorScreenState extends State<RecordEditorScreen> {
  late Map<String, dynamic> _record = widget.record;

  /// The system picker, then a copy into the pack. Null when the author cancels.
  Future<String?> _pickImage(String folder) async {
    final PlatformFile? picked;
    try {
      picked = await FilePicker.pickFile(type: FileType.image);
    } on Object {
      throw PackStorageException('Android would not open the picture chooser. Try again.');
    }
    if (picked == null) return null;
    final path = picked.path;
    if (path == null) {
      throw PackStorageException('Android did not share that picture with Pack Studio. Pick it from Pictures or Downloads.');
    }
    return widget.doc.storage.importImage(widget.doc.pack, path, folder);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: StudioColors.accent,
        foregroundColor: Colors.white,
        title: Text(widget.spec.title(_record)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SaveStatus(widget.doc),
            if (widget.subtitle != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(widget.subtitle!, style: const TextStyle(fontSize: 12, color: StudioColors.inkSoft)),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ImageToolsScope(
                tools: ImageTools(packPath: widget.doc.pack.path, pick: _pickImage),
                child: RecordForm(
                  spec: widget.spec,
                  value: _record,
                  onChanged: (r) {
                    setState(() => _record = r);
                    widget.onChanged(r);
                  },
                  openJson: (title, value) => editJsonValue(context, title, value),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A file that is one record (pack.json): opens straight into its form.
class SingleRecordScreen extends StatefulWidget {
  const SingleRecordScreen({super.key, required this.pack, required this.storage, required this.section});

  final PackEntry pack;
  final PackStorage storage;
  final SectionSpec section;

  @override
  State<SingleRecordScreen> createState() => _SingleRecordScreenState();
}

class _SingleRecordScreenState extends State<SingleRecordScreen> {
  // New subjects get their tier books as soon as pack.json is saved.
  late final PackDoc _doc = PackDoc(
    widget.pack,
    widget.storage,
    widget.section.file,
    afterSave: widget.section.file == 'pack.json' ? () => widget.storage.ensureBooks(widget.pack) : null,
  );
  String? _error;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _doc.load().then((error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loaded = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _doc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return Scaffold(appBar: AppBar(title: Text(widget.section.label)), body: const Center(child: CircularProgressIndicator()));
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.section.label)),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: const TextStyle(color: Color(0xFFB3261E))))),
      );
    }
    return RecordEditorScreen(
      spec: widget.section.record,
      record: _doc.root,
      doc: _doc,
      onChanged: (r) {
        _doc.root = r;
        _doc.changed();
      },
    );
  }
}
