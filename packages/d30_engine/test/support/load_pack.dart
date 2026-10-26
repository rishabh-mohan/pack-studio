import 'dart:io';

import 'package:d30_engine/d30_engine.dart';

/// Reads a pack directory into [ContentPack.fromFiles]; mirrors d30mode's
/// ContentSource.loadFromDirectory without its Flutter dependencies.
ContentPack loadPackDirectory(String path) {
  final files = <String, String>{};
  for (final name in ContentPack.allFiles) {
    final file = File('$path/$name');
    if (file.existsSync()) files[name] = file.readAsStringSync();
  }
  return ContentPack.fromFiles(files);
}
