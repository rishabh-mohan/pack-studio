import 'dart:convert';
import 'dart:io';

import 'package:d30_engine/d30_engine.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// The packs folder shared with d30mode: d30mode's own Android/media folder.
/// Unlike Android/data it can be reached by another app that holds "All files
/// access", and d30mode reads it as an extra editable pack root.
const d30modePacksDir = '/sdcard/Android/media/dev.d30mode.d30mode/packs';

/// IDs d30mode seeds from its APK; a copy under one of these is overwritten.
const _bundledIds = {'kss16', 'kss20'};

const _templateDir = 'assets/workshop/';

class PackEntry {
  const PackEntry({
    required this.id,
    required this.name,
    required this.path,
    required this.modified,
  });

  final String id;
  final String name;
  final String path;
  final DateTime modified;
}

class PackStorageException implements Exception {
  PackStorageException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The directory name d30mode accepts (`^[A-Za-z0-9_-]+$`) for a pack called [name].
String packIdFromName(String name) {
  final id = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return id.isEmpty ? 'pack' : id;
}

/// The template's pack.json with this pack's id and name (d30mode needs the
/// id to equal the directory name).
String templatePackJson(String source, {required String id, required String name}) {
  final manifest = jsonDecode(source) as Map<String, dynamic>;
  manifest['id'] = id;
  manifest['name'] = name;
  return '${const JsonEncoder.withIndent('  ').convert(manifest)}\n';
}

class PackStorage {
  PackStorage({this.root = d30modePacksDir});

  final String root;

  /// True once "All files access" is granted; asks (opening Android's settings
  /// page, since the user must flip the switch there) when [request] is set.
  Future<bool> hasAccess({bool request = false}) async {
    if (await Permission.manageExternalStorage.isGranted) return true;
    return request && (await Permission.manageExternalStorage.request()).isGranted;
  }

  /// Every pack directory (one holding a pack.json), newest first.
  Future<List<PackEntry>> list() async {
    final dir = Directory(root);
    if (!await dir.exists()) return const [];
    final packs = <PackEntry>[];
    try {
      await for (final entity in dir.list()) {
        final manifest = File('${entity.path}/pack.json');
        if (entity is! Directory || !await manifest.exists()) continue;
        final id = entity.path.split(RegExp(r'[/\\]')).last; // Windows paths use backslashes
        var name = id;
        try {
          name = ((jsonDecode(await manifest.readAsString()) as Map<String, dynamic>)['name'] as String?) ?? id;
        } on Object {
          // An unreadable pack.json still shows up, under its folder name.
        }
        packs.add(PackEntry(id: id, name: name, path: entity.path, modified: (await manifest.stat()).modified));
      }
    } on FileSystemException catch (e) {
      throw PackStorageException('Cannot read $root: ${e.osError?.message ?? e.message}');
    }
    packs.sort((a, b) => b.modified.compareTo(a.modified));
    return packs;
  }

  /// Relative paths of every file in [pack].
  Future<List<String>> files(PackEntry pack) async {
    final out = [
      await for (final e in Directory(pack.path).list(recursive: true))
        if (e is File) e.path.substring(pack.path.length + 1).replaceAll(r'\', '/'),
    ];
    return out..sort();
  }

  Future<String> read(PackEntry pack, String relative) => File('${pack.path}/$relative').readAsString();

  Future<void> write(PackEntry pack, String relative, String text) async {
    try {
      final file = File('${pack.path}/$relative');
      await file.parent.create(recursive: true);
      await file.writeAsString(text);
    } on FileSystemException catch (e) {
      throw PackStorageException('Could not write $relative: ${e.osError?.message ?? e.message}');
    }
  }

  /// Optional pack files d30mode understands that [pack] does not have yet.
  Future<List<String>> missingFiles(PackEntry pack) async {
    final have = await files(pack);
    return [for (final f in ContentPack.optionalFiles) if (!have.contains(f)) f];
  }

  /// Loads the pack with the d30mode engine. Null means it loads; otherwise why not.
  Future<String?> check(PackEntry pack) async {
    final sources = <String, String>{};
    for (final name in ContentPack.allFiles) {
      final file = File('${pack.path}/$name');
      if (await file.exists()) sources[name] = await file.readAsString();
    }
    try {
      ContentPack.fromFiles(sources);
      return null;
    } on PackFormatException catch (e) {
      return '${e.file}: ${e.message}';
    } on Object catch (e) {
      // The engine still raises raw TypeErrors for some malformed input.
      return 'Malformed pack data: $e';
    }
  }

  /// Copies the bundled Workshop template into a new pack folder named after [name].
  Future<PackEntry> createFromTemplate(String name) async {
    final taken = {..._bundledIds, ...(await list()).map((p) => p.id)};
    final base = packIdFromName(name);
    var id = base;
    for (var n = 2; taken.contains(id); n++) {
      id = '$base-$n';
    }

    final assets = (await AssetManifest.loadFromAssetBundle(rootBundle))
        .listAssets()
        .where((a) => a.startsWith(_templateDir));
    try {
      for (final asset in assets) {
        final relative = asset.substring(_templateDir.length);
        var text = await rootBundle.loadString(asset);
        if (relative == 'pack.json') text = templatePackJson(text, id: id, name: name);
        final file = File('$root/$id/$relative');
        await file.parent.create(recursive: true);
        await file.writeAsString(text);
      }
    } on FileSystemException catch (e) {
      throw PackStorageException('Could not write $root/$id: ${e.osError?.message ?? e.message}');
    }
    return (await list()).firstWhere((p) => p.id == id);
  }
}
