import 'package:flutter/material.dart';

import 'pack_storage.dart';

/// Where packs live and whether Pack Studio may reach them.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.storage});

  final PackStorage storage;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool? _access;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check({bool request = false}) async {
    final granted = await widget.storage.hasAccess(request: request);
    if (mounted) setState(() => _access = granted);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Packs folder'),
            subtitle: SelectableText(widget.storage.root),
          ),
          ListTile(
            leading: Icon(_access == true ? Icons.check_circle_outline : Icons.lock_outline),
            title: const Text('All files access'),
            subtitle: Text(_access == null
                ? 'Checking…'
                : _access!
                    ? 'Granted. Packs are shared with d30mode.'
                    : 'Not granted. Needed to share packs with d30mode.'),
            trailing: _access == false ? TextButton(onPressed: () => _check(request: true), child: const Text('Allow')) : null,
          ),
          const ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Deleting packs'),
            subtitle: Text('Use the bin icon on a pack on the home screen.'),
          ),
        ],
      ),
    );
  }
}
