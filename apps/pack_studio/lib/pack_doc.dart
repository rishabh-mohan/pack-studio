import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'pack_storage.dart';

const _encoder = JsonEncoder.withIndent('  ');

/// One JSON file of a pack held in memory and saved as the author edits.
/// After each save it asks the d30mode engine whether the pack still loads.
class PackDoc {
  PackDoc(this.pack, this.storage, this.relative, {this.afterSave});

  /// Runs after each successful write, e.g. to generate books for new subjects.
  final Future<void> Function()? afterSave;

  final PackEntry pack;
  final PackStorage storage;
  final String relative;

  /// Everything in the file; keys the forms don't know about stay in here untouched.
  Map<String, dynamic> root = {};

  /// Shown under the screen title: "All changes saved", "Saving…" or a problem.
  final status = ValueNotifier<String>('');
  final problem = ValueNotifier<bool>(false);

  Timer? _timer;
  bool _dirty = false;
  bool _disposed = false;
  Future<void>? _saving;

  /// Returns null when the file loaded (a missing file counts as empty), or why it can't be edited.
  Future<String?> load() async {
    try {
      final decoded = jsonDecode(await storage.read(pack, relative));
      if (decoded is! Map<String, dynamic>) {
        return '$relative does not hold a set of fields.';
      }
      root = decoded;
    } on PathNotFoundException {
      root = {};
    } on FormatException catch (e) {
      return '$relative is not valid JSON (${e.message}). Fix it under Advanced.';
    }
    return null;
  }

  /// Call after changing [root]; saves shortly after the author stops typing.
  void changed() {
    _dirty = true;
    status.value = 'Saving…';
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 700), flush);
  }

  Future<void> flush() async {
    _timer?.cancel();
    while (_saving != null) {
      await _saving;
    }
    if (!_dirty) return;
    final saving = _save();
    _saving = saving;
    try {
      await saving;
    } finally {
      _saving = null;
    }
    if (_dirty) await flush();
  }

  Future<void> _save() async {
    _dirty = false;
    try {
      await storage.write(pack, relative, '${_encoder.convert(root)}\n');
      await afterSave?.call();
      final why = await storage.check(pack);
      if (!_disposed) {
        problem.value = why != null;
        status.value = _dirty
            ? 'Saving…'
            : why == null
            ? 'All changes saved'
            : 'Saved, but the pack does not load yet: $why';
      }
    } on PackStorageException catch (e) {
      if (!_disposed) {
        problem.value = true;
        status.value = e.message;
      }
    }
  }

  void dispose() {
    flush();
    _disposed = true;
    status.dispose();
    problem.dispose();
  }
}
