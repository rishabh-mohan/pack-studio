import 'dart:convert';

import 'package:flutter/material.dart';

import 'file_editor_screen.dart';
import 'pack_storage.dart';
import 'schema.dart';
import 'section_screens.dart';
import 'theme.dart';

/// Inside a pack: a button for each kind of content (locations, traits...),
/// and under Advanced the remaining files for anything the forms don't cover.
class PackScreen extends StatefulWidget {
  const PackScreen({super.key, required this.pack, required this.storage});

  final PackEntry pack;
  final PackStorage storage;

  @override
  State<PackScreen> createState() => _PackScreenState();
}

class _PackScreenState extends State<PackScreen> {
  late Future<_PackOverview> _overview = _load();

  Future<_PackOverview> _load() async {
    final files = await widget.storage.files(widget.pack);
    final sections = packSectionsFor(await _tuning(files));
    final summaries = <String, String>{};
    for (final s in sections) {
      summaries[s.file] = await _summary(s, files.contains(s.file));
    }
    final covered = {for (final s in sections) s.file};
    return _PackOverview(
      sections: sections,
      summaries: summaries,
      otherFiles: [for (final f in files) if (f.endsWith('.json') && !covered.contains(f)) f],
    );
  }

  /// The pack's own rules decide what some labels say (e.g. the Rest bonus).
  Future<PackTuning> _tuning(List<String> files) async {
    try {
      final rules = files.contains('rules.json') ? jsonDecode(await widget.storage.read(widget.pack, 'rules.json')) : <String, dynamic>{};
      final manifest = files.contains('pack.json') ? jsonDecode(await widget.storage.read(widget.pack, 'pack.json')) : <String, dynamic>{};
      final subjects = [for (final s in (manifest is Map ? manifest['subjects'] as List? : null) ?? const []) '$s'];
      return PackTuning.fromRules(rules is Map<String, dynamic> ? rules : {}, subjects: subjects);
    } on Object {
      return const PackTuning();
    }
  }

  Future<String> _summary(SectionSpec s, bool exists) async {
    if (!exists) return s.listKey == null ? s.blurb : 'None yet';
    try {
      final json = jsonDecode(await widget.storage.read(widget.pack, s.file));
      if (s.listKey == null) return s.blurb;
      final n = ((json as Map)[s.listKey] as List?)?.length ?? 0;
      return n == 1 ? '1 ${s.record.noun}' : '$n ${s.record.noun}s';
    } on Object {
      return s.blurb;
    }
  }

  void _reload() => setState(() => _overview = _load());

  void _say(String text, {int seconds = 4}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), duration: Duration(seconds: seconds)));

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) _reload();
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
            const ListTile(title: Text('Add an advanced file', style: TextStyle(fontWeight: FontWeight.w600))),
            for (final f in missing) ListTile(title: Text(f), onTap: () => Navigator.pop(context, f)),
          ],
        ),
      ),
    );
    if (name == null || !mounted) return;
    try {
      await widget.storage.write(widget.pack, name, '{}\n');
      if (mounted) _open(FileEditorScreen(pack: widget.pack, storage: widget.storage, relative: name));
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
          IconButton(tooltip: 'Check that the pack loads', icon: const Icon(Icons.fact_check_outlined), onPressed: _check),
        ],
      ),
      body: FutureBuilder<_PackOverview>(
        future: _overview,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('${snapshot.error}', style: const TextStyle(color: StudioColors.ink))));
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final overview = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              for (final s in overview.sections)
                _SectionButton(
                  key: ValueKey('section:${s.label}'),
                  section: s,
                  summary: overview.summaries[s.file] ?? s.blurb,
                  onTap: () => _open(s.listKey == null
                      ? SingleRecordScreen(pack: widget.pack, storage: widget.storage, section: s)
                      : SectionListScreen(pack: widget.pack, storage: widget.storage, section: s)),
                ),
              const SizedBox(height: 12),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: const ValueKey('advanced'),
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Advanced', style: TextStyle(fontWeight: FontWeight.w600, color: StudioColors.ink)),
                  subtitle: const Text('Events, rules and other files, edited as raw data', style: TextStyle(fontSize: 12, color: StudioColors.inkSoft)),
                  children: [
                    for (final f in overview.otherFiles)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.data_object, color: StudioColors.accent),
                        title: Text(f, style: const TextStyle(color: StudioColors.ink)),
                        onTap: () => _open(FileEditorScreen(pack: widget.pack, storage: widget.storage, relative: f)),
                      ),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.note_add_outlined, color: StudioColors.accent),
                      title: const Text('Add another file…', style: TextStyle(color: StudioColors.ink)),
                      onTap: _addFile,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PackOverview {
  const _PackOverview({required this.sections, required this.summaries, required this.otherFiles});

  final List<SectionSpec> sections;
  final Map<String, String> summaries;
  final List<String> otherFiles;
}

class _SectionButton extends StatelessWidget {
  const _SectionButton({super.key, required this.section, required this.summary, required this.onTap});

  final SectionSpec section;
  final String summary;
  final VoidCallback onTap;

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
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(section.icon, color: StudioColors.accent, size: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(section.label, style: const TextStyle(fontSize: 18, color: StudioColors.ink, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(summary, style: const TextStyle(fontSize: 13, color: StudioColors.inkSoft)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: StudioColors.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
