import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'pack_screen.dart';
import 'pack_storage.dart';
import 'theme.dart';

void main() => runApp(const PackStudioApp());

class PackStudioApp extends StatelessWidget {
  const PackStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pack Studio',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const _Home(),
    );
  }
}

/// Owns the pack list and the New / Open flows around [HomeScreen].
class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> with WidgetsBindingObserver {
  final _storage = PackStorage();
  List<PackEntry> _packs = const [];
  String? _notice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from Android's "All files access" settings page: pick up the new permission.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (!await _storage.hasAccess()) {
      if (mounted) {
        setState(() {
          _packs = const [];
          _notice = 'Pack Studio needs "All files access" to share packs with d30mode. '
              'Tap New pack or Open pack to allow it.';
        });
      }
      return;
    }
    try {
      final packs = await _storage.list();
      if (mounted) setState(() { _packs = packs; _notice = null; });
    } on PackStorageException catch (e) {
      if (mounted) setState(() => _notice = e.message);
    }
  }

  void _say(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _show(PackEntry pack) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => PackScreen(pack: pack, storage: _storage)),
  );

  Future<void> _newPack() async {
    if (!await _storage.hasAccess(request: true)) return;
    if (!mounted) return;
    final name = await showDialog<String>(context: context, builder: (_) => const _NamePackDialog());
    if (name == null || !mounted) return;
    try {
      final pack = await _storage.createFromTemplate(name);
      await _refresh();
      if (mounted) _show(pack);
    } on PackStorageException catch (e) {
      if (mounted) _say(e.message);
    }
  }

  Future<void> _openPack() async {
    if (!await _storage.hasAccess(request: true)) return;
    await _refresh();
    if (!mounted) return;
    if (_packs.isEmpty) return _say(_notice ?? 'No packs in the folder yet.');
    final pack = await showModalBottomSheet<PackEntry>(
      context: context,
      backgroundColor: StudioColors.panel,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final p in _packs)
              ListTile(
                title: Text(p.name),
                subtitle: Text(p.id),
                onTap: () => Navigator.pop(context, p),
              ),
          ],
        ),
      ),
    );
    if (pack != null && mounted) _show(pack);
  }

  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      onNewPack: _newPack,
      onOpenPack: _openPack,
      onSettings: () => _say('Settings is not built yet'),
      onOpenRecent: (r) => _show(_packs.firstWhere((p) => p.path == r.path)),
      notice: _notice,
      recent: [
        for (final p in _packs) RecentPack(name: p.name, path: p.path, lastOpened: p.modified),
      ],
    );
  }
}

class _NamePackDialog extends StatefulWidget {
  const _NamePackDialog();

  @override
  State<_NamePackDialog> createState() => _NamePackDialogState();
}

class _NamePackDialogState extends State<_NamePackDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New pack'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Pack name', helperText: 'Starts from the Workshop template'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}
