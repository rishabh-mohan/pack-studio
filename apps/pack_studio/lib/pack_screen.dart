import 'package:flutter/material.dart';

import 'file_editor_screen.dart';
import 'pack_storage.dart';
import 'theme.dart';

/// Inside a pack: its files (tap one to edit it), adding optional files, and
/// a check that the d30mode engine can load the whole pack.
class PackScreen extends StatefulWidget {
  const PackScreen({super.key, required this.pack, required this.storage});

  final PackEntry pack;
  final PackStorage storage;

  @override
  State<PackScreen> createState() => _PackScreenState();
}

class _PackScreenState extends State<PackScreen> {
  late Future<List<String>> _files = widget.storage.files(widget.pack);

  void _reload() => setState(() => _files = widget.storage.files(widget.pack));

  void _say(String text, {int seconds = 4}) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text), duration: Duration(seconds: seconds)));

  Future<void> _edit(String relative) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => FileEditorScreen(pack: widget.pack, storage: widget.storage, relative: relative),
    ));
    _reload();
  }

  Future<void> _check() async {
    final problem = await widget.storage.check(widget.pack);
    if (mounted) _say(problem == null ? 'The pack loads.' : 'The pack does not load: $problem', seconds: problem == null ? 3 : 10);
  }

  Future<void> _addFile() async {
    final missing = await widget.storage.missingFiles(widget.pack);
    if (!mounted) return;
    if (missing.isEmpty) return _say('Every optional file already exists.');
    final name = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: StudioColors.panel,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Add file', style: TextStyle(fontWeight: FontWeight.w600))),
            for (final f in missing) ListTile(title: Text(f), onTap: () => Navigator.pop(context, f)),
          ],
        ),
      ),
    );
    if (name == null || !mounted) return;
    try {
      await widget.storage.write(widget.pack, name, '{}\n');
      _reload();
      if (mounted) _edit(name);
    } on PackStorageException catch (e) {
      if (mounted) _say(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: StudioColors.accent,
        foregroundColor: Colors.white,
        title: Text(widget.pack.name),
        actions: [
          IconButton(tooltip: 'Check pack', icon: const Icon(Icons.fact_check_outlined), onPressed: _check),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addFile,
        backgroundColor: StudioColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('Add file'),
      ),
      body: FutureBuilder<List<String>>(
        future: _files,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${snapshot.error}', style: const TextStyle(color: StudioColors.ink)),
              ),
            );
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final files = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(widget.pack.path, style: const TextStyle(fontSize: 12, color: StudioColors.inkSoft)),
              ),
              for (final f in files)
                ListTile(
                  leading: Icon(f.endsWith('.json') ? Icons.data_object : Icons.insert_drive_file_outlined, color: StudioColors.accent),
                  title: Text(f, style: const TextStyle(color: StudioColors.ink)),
                  // Images and other non-JSON files are not editable here.
                  onTap: f.endsWith('.json') ? () => _edit(f) : null,
                ),
            ],
          );
        },
      ),
    );
  }
}
