import 'package:flutter/material.dart';

import 'pack_storage.dart';
import 'theme.dart';

/// First look inside a pack: where it lives, its files and its manifest.
class PackScreen extends StatelessWidget {
  const PackScreen({super.key, required this.pack, required this.storage});

  final PackEntry pack;
  final PackStorage storage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: StudioColors.accent,
        foregroundColor: Colors.white,
        title: Text(pack.name),
      ),
      body: FutureBuilder<(List<String>, String)>(
        future: Future(() async => (await storage.files(pack), await storage.read(pack, 'pack.json'))),
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
          final (files, manifest) = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(pack.path, style: const TextStyle(fontSize: 12, color: StudioColors.inkSoft)),
              const SizedBox(height: 16),
              const Text('Files', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: StudioColors.ink)),
              const SizedBox(height: 6),
              for (final f in files) Text(f, style: const TextStyle(color: StudioColors.ink)),
              const SizedBox(height: 20),
              const Text('pack.json', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: StudioColors.ink)),
              const SizedBox(height: 6),
              SelectableText(manifest, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: StudioColors.ink)),
            ],
          );
        },
      ),
    );
  }
}
