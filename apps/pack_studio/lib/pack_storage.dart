import 'dart:convert';
import 'dart:io';

import 'package:d30_engine/d30_engine.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'book_generation.dart';
import 'study_levels.dart' as levels;

/// The packs folder shared with d30mode: d30mode's own Android/media folder.
/// Unlike Android/data it can be reached by another app that holds "All files
/// access", and d30mode reads it as an extra editable pack root.
const d30modePacksDir = '/sdcard/Android/media/dev.d30mode.d30mode/packs';

/// IDs d30mode seeds from its APK; a copy under one of these is overwritten.
const _bundledIds = {'kss16', 'kss20'};

const _templateDir = 'assets/workshop/';

/// Picture types d30mode can load.
const imageExtensions = {'png', 'jpg', 'jpeg', 'webp'};

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

  /// Deletes [pack]'s folder and everything in it. Refuses anything that is not a direct child of [root].
  Future<void> delete(PackEntry pack) async {
    final parent = Directory(pack.path).parent.path.replaceAll(r'\', '/');
    if (parent != root.replaceAll(r'\', '/')) {
      throw PackStorageException('${pack.path} is not inside the packs folder.');
    }
    try {
      await Directory(pack.path).delete(recursive: true);
    } on FileSystemException catch (e) {
      throw PackStorageException('Could not delete ${pack.name}: ${e.osError?.message ?? e.message}');
    }
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
    final pack = (await list()).firstWhere((p) => p.id == id);
    await ensureBooks(pack);
    return pack;
  }

  /// Copies a picture the author chose into the pack's `images/<folder>/` and
  /// returns the path to store (relative to `images/`, which is what d30mode
  /// resolves). An existing file with the same name is never overwritten.
  Future<String> importImage(PackEntry pack, String sourcePath, String folder) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw PackStorageException('That picture could not be found. Choose it again.');
    }
    final fileName = sourcePath.split(RegExp(r'[/\\]')).last;
    final dot = fileName.lastIndexOf('.');
    final extension = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
    if (!imageExtensions.contains(extension)) {
      throw PackStorageException(
        'Choose a PNG, JPG or WebP picture. "$fileName" is not one of those.',
      );
    }
    var base = (dot < 0 ? fileName : fileName.substring(0, dot))
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (base.isEmpty) base = 'image';

    try {
      final dir = Directory('${pack.path}/images/$folder');
      await dir.create(recursive: true);
      var name = '$base.$extension';
      for (var n = 2; await File('${dir.path}/$name').exists(); n++) {
        name = '$base-$n.$extension';
      }
      await source.copy('${dir.path}/$name');
      return '$folder/$name';
    } on FileSystemException catch (e) {
      throw PackStorageException('Could not copy that picture into the pack: ${e.osError?.message ?? e.message}');
    }
  }

  /// Gives a pack with no student level table the default one (see
  /// study_levels.dart), keeping any other tables and a table it already has.
  /// Returns whether `levels.json` was written.
  Future<bool> ensureStudyLevels(PackEntry pack) async {
    var doc = <String, dynamic>{};
    try {
      final decoded = jsonDecode(await read(pack, 'levels.json'));
      if (decoded is Map<String, dynamic>) doc = decoded;
    } on PathNotFoundException {
      // No levels file yet: start from an empty document.
    }
    final (updated, changed) = levels.ensureStudyLevels(doc);
    if (changed) await write(pack, 'levels.json', '${const JsonEncoder.withIndent('  ').convert(updated)}\n');
    return changed;
  }

  /// Gives every subject in pack.json a book for each tier it is missing
  /// and removes books belonging to deleted subjects. Retained books keep their
  /// IDs, edits and extra fields. Returns how many books were added.
  Future<int> ensureBooks(PackEntry pack) async {
    final manifest = jsonDecode(await read(pack, 'pack.json'));
    final subjects = [
      for (final s in (manifest is Map ? manifest['subjects'] as List? : null) ?? const []) '$s',
    ];
    var doc = <String, dynamic>{};
    try {
      final decoded = jsonDecode(await read(pack, 'books.json'));
      if (decoded is Map<String, dynamic>) doc = decoded;
    } on PathNotFoundException {
      // No books yet: start from an empty document.
    }
    final (updated, added) = ensureSubjectBooks(doc, subjects);
    if (!identical(updated, doc)) await write(pack, 'books.json', '${const JsonEncoder.withIndent('  ').convert(updated)}\n');
    return added;
  }
}
