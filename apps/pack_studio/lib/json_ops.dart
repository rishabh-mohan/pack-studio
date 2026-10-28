// lib/json_ops.dart

/// A path through a JSON value.
/// Each element is either a [String] (object key) or an [int] (array index).
typedef JsonPath = List<Object>;

/// Deep-clones a JSON value (Map, List, or primitive) so inserted or duplicated
/// subtrees do not share mutable references with other parts of the tree.
dynamic jsonClone(dynamic value) {
  if (value is Map) {
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      result[entry.key.toString()] = jsonClone(entry.value);
    }
    return result;
  }
  if (value is List) {
    return List<dynamic>.generate(value.length, (i) => jsonClone(value[i]));
  }
  return value;
}

/// Retrieves the value at [path] starting from [root].
///
/// Throws [ArgumentError] if any step along [path] is invalid for the
/// corresponding container, if a map key does not exist, or if a list index is
/// out of range.
dynamic jsonGet(dynamic root, JsonPath path) {
  dynamic current = root;
  for (var i = 0; i < path.length; i++) {
    final step = path[i];
    if (current is Map<String, dynamic>) {
      if (step is! String) {
        throw ArgumentError(
          'Expected String key at path index $i for Map, got ${step.runtimeType} ($step).',
        );
      }
      if (!current.containsKey(step)) {
        throw ArgumentError('Key "$step" not found at path index $i.');
      }
      current = current[step];
    } else if (current is Map) {
      if (step is! String) {
        throw ArgumentError(
          'Expected String key at path index $i for Map, got ${step.runtimeType} ($step).',
        );
      }
      if (!current.containsKey(step)) {
        throw ArgumentError('Key "$step" not found at path index $i.');
      }
      current = current[step];
    } else if (current is List) {
      if (step is! int) {
        throw ArgumentError(
          'Expected int index at path index $i for List, got ${step.runtimeType} ($step).',
        );
      }
      if (step < 0 || step >= current.length) {
        throw ArgumentError(
          'Index $step out of range (0..${current.length - 1}) at path index $i.',
        );
      }
      current = current[step];
    } else {
      throw ArgumentError(
        'Cannot traverse into ${jsonTypeName(current)} at path index $i.',
      );
    }
  }
  return current;
}

/// Returns a new root with the value at [path] replaced by [value].
///
/// If [path] is empty, returns [value] directly.
/// For a [Map] target, the last path element must be an existing or new [String]
/// key? Note: for [jsonSet], if the key already exists in the map, its insertion
/// order position is preserved; if it does not exist in the map, throws
/// [ArgumentError] (use [jsonInsert] to add new keys).
/// Throws [ArgumentError] for any invalid path.
dynamic jsonSet(dynamic root, JsonPath path, dynamic value) {
  if (path.isEmpty) {
    return value;
  }
  return _setRecursive(root, path, 0, value);
}

dynamic _setRecursive(dynamic current, JsonPath path, int depth, dynamic value) {
  final step = path[depth];
  final isLast = depth == path.length - 1;

  if (current is Map) {
    if (step is! String) {
      throw ArgumentError(
        'Expected String key at path index $depth for Map, got ${step.runtimeType}.',
      );
    }
    if (!current.containsKey(step)) {
      throw ArgumentError('Key "$step" does not exist at path index $depth.');
    }
    final nextValue = isLast
        ? value
        : _setRecursive(current[step], path, depth + 1, value);
    final newMap = <String, dynamic>{};
    for (final entry in current.entries) {
      final k = entry.key.toString();
      newMap[k] = (k == step) ? nextValue : entry.value;
    }
    return newMap;
  } else if (current is List) {
    if (step is! int) {
      throw ArgumentError(
        'Expected int index at path index $depth for List, got ${step.runtimeType}.',
      );
    }
    if (step < 0 || step >= current.length) {
      throw ArgumentError(
        'Index $step out of range (0..${current.length - 1}) at path index $depth.',
      );
    }
    final nextValue = isLast
        ? value
        : _setRecursive(current[step], path, depth + 1, value);
    final newList = List<dynamic>.from(current);
    newList[step] = nextValue;
    return newList;
  } else {
    throw ArgumentError(
      'Cannot traverse into ${jsonTypeName(current)} at path index $depth.',
    );
  }
}

/// Removes the map key or list element at [path] and returns a new root.
///
/// Throws [ArgumentError] if [path] is empty or invalid.
dynamic jsonRemove(dynamic root, JsonPath path) {
  if (path.isEmpty) {
    throw ArgumentError('Cannot remove the root value (empty path).');
  }
  return _removeRecursive(root, path, 0);
}

dynamic _removeRecursive(dynamic current, JsonPath path, int depth) {
  final step = path[depth];
  final isLast = depth == path.length - 1;

  if (current is Map) {
    if (step is! String) {
      throw ArgumentError(
        'Expected String key at path index $depth for Map, got ${step.runtimeType}.',
      );
    }
    if (!current.containsKey(step)) {
      throw ArgumentError('Key "$step" not found at path index $depth.');
    }
    if (isLast) {
      final newMap = <String, dynamic>{};
      for (final entry in current.entries) {
        final k = entry.key.toString();
        if (k != step) {
          newMap[k] = entry.value;
        }
      }
      return newMap;
    } else {
      final updatedChild = _removeRecursive(current[step], path, depth + 1);
      final newMap = <String, dynamic>{};
      for (final entry in current.entries) {
        final k = entry.key.toString();
        newMap[k] = (k == step) ? updatedChild : entry.value;
      }
      return newMap;
    }
  } else if (current is List) {
    if (step is! int) {
      throw ArgumentError(
        'Expected int index at path index $depth for List, got ${step.runtimeType}.',
      );
    }
    if (step < 0 || step >= current.length) {
      throw ArgumentError(
        'Index $step out of range (0..${current.length - 1}) at path index $depth.',
      );
    }
    if (isLast) {
      final newList = List<dynamic>.from(current);
      newList.removeAt(step);
      return newList;
    } else {
      final updatedChild = _removeRecursive(current[step], path, depth + 1);
      final newList = List<dynamic>.from(current);
      newList[step] = updatedChild;
      return newList;
    }
  } else {
    throw ArgumentError(
      'Cannot traverse into ${jsonTypeName(current)} at path index $depth.',
    );
  }
}

/// Inserts [value] into the container at [containerPath] and returns a new root.
///
/// - If the container at [containerPath] is a [Map]: [key] must be a [String]
///   that does not already exist in the map (otherwise throws [ArgumentError]).
///   The new entry is added at the end of the map's insertion order.
/// - If the container at [containerPath] is a [List]: [key] must be `null` (to
///   append to the end) or an [int] index in `0..length` (to insert at that
///   index). Otherwise throws [ArgumentError].
dynamic jsonInsert(
  dynamic root,
  JsonPath containerPath,
  Object? key,
  dynamic value,
) {
  return _insertRecursive(root, containerPath, 0, key, value);
}

dynamic _insertRecursive(
  dynamic current,
  JsonPath containerPath,
  int depth,
  Object? key,
  dynamic value,
) {
  if (depth == containerPath.length) {
    if (current is Map) {
      if (key is! String) {
        throw ArgumentError(
          'Expected String key to insert into Map, got ${key.runtimeType}.',
        );
      }
      if (current.containsKey(key)) {
        throw ArgumentError('Key "$key" already exists in Map.');
      }
      final newMap = <String, dynamic>{};
      for (final entry in current.entries) {
        newMap[entry.key.toString()] = entry.value;
      }
      newMap[key] = value;
      return newMap;
    } else if (current is List) {
      final newList = List<dynamic>.from(current);
      if (key == null) {
        newList.add(value);
      } else if (key is int) {
        if (key < 0 || key > current.length) {
          throw ArgumentError(
            'Insert index $key out of range (0..${current.length}).',
          );
        }
        newList.insert(key, value);
      } else {
        throw ArgumentError(
          'Expected null or int index to insert into List, got ${key.runtimeType}.',
        );
      }
      return newList;
    } else {
      throw ArgumentError(
        'Target at containerPath is not a Map or List (got ${jsonTypeName(current)}).',
      );
    }
  }

  final step = containerPath[depth];
  if (current is Map) {
    if (step is! String) {
      throw ArgumentError(
        'Expected String key at path index $depth for Map, got ${step.runtimeType}.',
      );
    }
    if (!current.containsKey(step)) {
      throw ArgumentError('Key "$step" not found at path index $depth.');
    }
    final updatedChild = _insertRecursive(
      current[step],
      containerPath,
      depth + 1,
      key,
      value,
    );
    final newMap = <String, dynamic>{};
    for (final entry in current.entries) {
      final k = entry.key.toString();
      newMap[k] = (k == step) ? updatedChild : entry.value;
    }
    return newMap;
  } else if (current is List) {
    if (step is! int) {
      throw ArgumentError(
        'Expected int index at path index $depth for List, got ${step.runtimeType}.',
      );
    }
    if (step < 0 || step >= current.length) {
      throw ArgumentError(
        'Index $step out of range (0..${current.length - 1}) at path index $depth.',
      );
    }
    final updatedChild = _insertRecursive(
      current[step],
      containerPath,
      depth + 1,
      key,
      value,
    );
    final newList = List<dynamic>.from(current);
    newList[step] = updatedChild;
    return newList;
  } else {
    throw ArgumentError(
      'Cannot traverse into ${jsonTypeName(current)} at path index $depth.',
    );
  }
}

/// Renames the map key identified by [path] to [newKey], keeping its exact
/// position in the map's insertion order, and returns a new root.
///
/// Throws [ArgumentError] if [path] is empty, the last element of [path] is not
/// a [String] key of a [Map], the old key does not exist, or [newKey] already
/// exists in the same map.
dynamic jsonRename(dynamic root, JsonPath path, String newKey) {
  if (path.isEmpty) {
    throw ArgumentError('Cannot rename the root value (empty path).');
  }
  return _renameRecursive(root, path, 0, newKey);
}

dynamic _renameRecursive(
  dynamic current,
  JsonPath path,
  int depth,
  String newKey,
) {
  final step = path[depth];
  final isLast = depth == path.length - 1;

  if (isLast) {
    if (current is! Map) {
      throw ArgumentError(
        'Target parent for jsonRename must be a Map, got ${jsonTypeName(current)}.',
      );
    }
    if (step is! String) {
      throw ArgumentError(
        'Last path element for jsonRename must be a String key, got ${step.runtimeType}.',
      );
    }
    if (!current.containsKey(step)) {
      throw ArgumentError('Key "$step" not found in Map.');
    }
    if (current.containsKey(newKey)) {
      throw ArgumentError('Key "$newKey" already exists in Map.');
    }
    final newMap = <String, dynamic>{};
    for (final entry in current.entries) {
      final k = entry.key.toString();
      if (k == step) {
        newMap[newKey] = entry.value;
      } else {
        newMap[k] = entry.value;
      }
    }
    return newMap;
  }

  if (current is Map) {
    if (step is! String) {
      throw ArgumentError(
        'Expected String key at path index $depth for Map, got ${step.runtimeType}.',
      );
    }
    if (!current.containsKey(step)) {
      throw ArgumentError('Key "$step" not found at path index $depth.');
    }
    final updatedChild = _renameRecursive(
      current[step],
      path,
      depth + 1,
      newKey,
    );
    final newMap = <String, dynamic>{};
    for (final entry in current.entries) {
      final k = entry.key.toString();
      newMap[k] = (k == step) ? updatedChild : entry.value;
    }
    return newMap;
  } else if (current is List) {
    if (step is! int) {
      throw ArgumentError(
        'Expected int index at path index $depth for List, got ${step.runtimeType}.',
      );
    }
    if (step < 0 || step >= current.length) {
      throw ArgumentError(
        'Index $step out of range (0..${current.length - 1}) at path index $depth.',
      );
    }
    final updatedChild = _renameRecursive(
      current[step],
      path,
      depth + 1,
      newKey,
    );
    final newList = List<dynamic>.from(current);
    newList[step] = updatedChild;
    return newList;
  } else {
    throw ArgumentError(
      'Cannot traverse into ${jsonTypeName(current)} at path index $depth.',
    );
  }
}

/// Moves the list element at [path] by [delta] positions (clamped to the list
/// bounds) and returns a new root.
///
/// Throws [ArgumentError] if [path] is empty, the parent container is not a
/// [List], the last element of [path] is not an [int], or the index is out of
/// bounds.
dynamic jsonMove(dynamic root, JsonPath path, int delta) {
  if (path.isEmpty) {
    throw ArgumentError('Cannot move the root value (empty path).');
  }
  return _moveRecursive(root, path, 0, delta);
}

dynamic _moveRecursive(dynamic current, JsonPath path, int depth, int delta) {
  final step = path[depth];
  final isLast = depth == path.length - 1;

  if (isLast) {
    if (current is! List) {
      throw ArgumentError(
        'Target parent for jsonMove must be a List, got ${jsonTypeName(current)}.',
      );
    }
    if (step is! int) {
      throw ArgumentError(
        'Last path element for jsonMove must be an int index, got ${step.runtimeType}.',
      );
    }
    if (step < 0 || step >= current.length) {
      throw ArgumentError(
        'Index $step out of range (0..${current.length - 1}).',
      );
    }
    final newList = List<dynamic>.from(current);
    final targetIndex = (step + delta).clamp(0, current.length - 1);
    if (targetIndex != step) {
      final item = newList.removeAt(step);
      newList.insert(targetIndex, item);
    }
    return newList;
  }

  if (current is Map) {
    if (step is! String) {
      throw ArgumentError(
        'Expected String key at path index $depth for Map, got ${step.runtimeType}.',
      );
    }
    if (!current.containsKey(step)) {
      throw ArgumentError('Key "$step" not found at path index $depth.');
    }
    final updatedChild = _moveRecursive(current[step], path, depth + 1, delta);
    final newMap = <String, dynamic>{};
    for (final entry in current.entries) {
      final k = entry.key.toString();
      newMap[k] = (k == step) ? updatedChild : entry.value;
    }
    return newMap;
  } else if (current is List) {
    if (step is! int) {
      throw ArgumentError(
        'Expected int index at path index $depth for List, got ${step.runtimeType}.',
      );
    }
    if (step < 0 || step >= current.length) {
      throw ArgumentError(
        'Index $step out of range (0..${current.length - 1}) at path index $depth.',
      );
    }
    final updatedChild = _moveRecursive(current[step], path, depth + 1, delta);
    final newList = List<dynamic>.from(current);
    newList[step] = updatedChild;
    return newList;
  } else {
    throw ArgumentError(
      'Cannot traverse into ${jsonTypeName(current)} at path index $depth.',
    );
  }
}

/// Parses [text] into a JSON number ([int] or [double]), or returns `null` if
/// [text] is not a valid number.
///
/// Returns an [int] if [text] contains no `'.'`, `'e'`, or `'E'` and parses via
/// [int.tryParse]; otherwise parses via [double.tryParse] (rejecting NaN and
/// infinite values, which are not valid JSON numbers).
Object? parseJsonNumber(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  if (!trimmed.contains('.') &&
      !trimmed.contains('e') &&
      !trimmed.contains('E')) {
    return int.tryParse(trimmed);
  }
  final d = double.tryParse(trimmed);
  if (d == null || d.isNaN || d.isInfinite) {
    return null;
  }
  return d;
}

/// Returns the JSON type name of [v]:
/// `'object'`, `'array'`, `'string'`, `'number'`, `'boolean'`, or `'null'`.
String jsonTypeName(dynamic v) {
  if (v == null) return 'null';
  if (v is bool) return 'boolean';
  if (v is num) return 'number';
  if (v is String) return 'string';
  if (v is List) return 'array';
  if (v is Map) return 'object';
  throw ArgumentError('Unsupported JSON value type: ${v.runtimeType}');
}
