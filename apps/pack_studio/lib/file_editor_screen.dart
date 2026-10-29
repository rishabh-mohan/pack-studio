import 'dart:convert';

import 'package:flutter/material.dart';

import 'json_tree_editor.dart';
import 'pack_storage.dart';
import 'theme.dart';

const _encoder = JsonEncoder.withIndent('  ');

/// Edits one JSON file of a pack: a lossless tree (key order kept) or the raw text.
class FileEditorScreen extends StatefulWidget {
  const FileEditorScreen({super.key, required this.pack, required this.storage, required this.relative});

  final PackEntry pack;
  final PackStorage storage;
  final String relative;

  @override
  State<FileEditorScreen> createState() => _FileEditorScreenState();
}

class _FileEditorScreenState extends State<FileEditorScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)..addListener(_tabChanged);
  final _raw = TextEditingController();
  dynamic _json;
  String? _error; // why the current text is not valid JSON
  bool _loaded = false;
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _raw.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final text = await widget.storage.read(widget.pack, widget.relative);
    _raw.text = text;
    try {
      _json = jsonDecode(text);
    } on FormatException catch (e) {
      _error = e.message;
      _tabs.index = 1; // fix it in the text view
    }
    if (mounted) setState(() => _loaded = true);
  }

  // Keep the two views in step when switching between them.
  void _tabChanged() {
    if (_tabs.indexIsChanging) return;
    setState(() {
      if (_tabs.index == 1 && _error == null) {
        _raw.text = _encoder.convert(_json);
      }
    });
  }

  void _treeChanged(dynamic value) {
    _json = value;
    _error = null;
    setState(() => _dirty = true);
  }

  void _textChanged(String text) {
    try {
      _json = jsonDecode(text);
      _error = null;
    } on FormatException catch (e) {
      _error = e.message;
    }
    setState(() => _dirty = true);
  }

  Future<void> _save() async {
    if (_error != null) return;
    setState(() => _saving = true);
    try {
      await widget.storage.write(widget.pack, widget.relative, '${_encoder.convert(_json)}\n');
      if (widget.relative == 'pack.json') await widget.storage.ensureBooks(widget.pack);
      final problem = await widget.storage.check(widget.pack);
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(problem == null ? 'Saved. The pack loads.' : 'Saved, but the pack does not load: $problem'),
        duration: Duration(seconds: problem == null ? 3 : 8),
      ));
    } on PackStorageException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard changes?'),
            content: Text('${widget.relative} has unsaved changes.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep editing')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Discard')),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: StudioColors.accent,
          foregroundColor: Colors.white,
          title: Text(widget.relative, style: const TextStyle(fontSize: 18)),
          actions: [
            IconButton(
              tooltip: 'Save',
              icon: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              onPressed: _loaded && _dirty && _error == null && !_saving ? _save : null,
            ),
          ],
          bottom: TabBar(
            controller: _tabs,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: const [Tab(text: 'Tree'), Tab(text: 'Text')],
          ),
        ),
        body: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabs,
                physics: const NeverScrollableScrollPhysics(), // swiping would fight the tree's scrolling
                children: [
                  _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text('Not valid JSON yet: $_error\nFix it in the Text tab.',
                                style: const TextStyle(color: Color(0xFFE8463C))),
                          ),
                        )
                      : JsonTreeEditor(value: _json, onChanged: _treeChanged),
                  Column(
                    children: [
                      if (_error != null)
                        Container(
                          width: double.infinity,
                          color: const Color(0xFFFFE3DF),
                          padding: const EdgeInsets.all(10),
                          child: Text(_error!, style: const TextStyle(color: Color(0xFFB3261E), fontSize: 12)),
                        ),
                      Expanded(
                        child: TextField(
                          controller: _raw,
                          onChanged: _textChanged,
                          expands: true,
                          maxLines: null,
                          minLines: null,
                          keyboardType: TextInputType.multiline,
                          textAlignVertical: TextAlignVertical.top,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: StudioColors.ink),
                          decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
