import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_studio/json_ops.dart';

Map<String, dynamic> _sampleRoot() {
  return jsonDecode('''
{
  "name": "pack_alpha",
  "version": 1,
  "ratio": 0.75,
  "active": true,
  "extra": null,
  "meta": {
    "first": "a",
    "second": "b",
    "third": "c"
  },
  "items": [
    {"id": 10, "tags": ["x", "y"]},
    {"id": 20, "tags": ["z"]},
    {"id": 30, "tags": []}
  ]
}
''') as Map<String, dynamic>;
}

String _snapshot(dynamic v) => jsonEncode(v);

void main() {
  group('jsonTypeName', () {
    test('identifies all JSON types accurately', () {
      expect(jsonTypeName(<String, dynamic>{}), 'object');
      expect(jsonTypeName(<dynamic>[]), 'array');
      expect(jsonTypeName('hello'), 'string');
      expect(jsonTypeName(42), 'number');
      expect(jsonTypeName(3.14), 'number');
      expect(jsonTypeName(true), 'boolean');
      expect(jsonTypeName(false), 'boolean');
      expect(jsonTypeName(null), 'null');
    });
  });

  group('parseJsonNumber', () {
    test('parses ints, doubles, scientific notation, and rejects invalid text', () {
      final intVal = parseJsonNumber('801');
      expect(intVal, isA<int>());
      expect(intVal, 801);

      final negInt = parseJsonNumber('-42');
      expect(negInt, isA<int>());
      expect(negInt, -42);

      final dblVal = parseJsonNumber('1.5');
      expect(dblVal, isA<double>());
      expect(dblVal, 1.5);

      final sciLower = parseJsonNumber('1e3');
      expect(sciLower, isA<double>());
      expect(sciLower, 1000.0);

      final sciUpper = parseJsonNumber('2.5E-2');
      expect(sciUpper, isA<double>());
      expect(sciUpper, 0.025);

      final dotZero = parseJsonNumber('10.0');
      expect(dotZero, isA<double>());
      expect(dotZero, 10.0);

      expect(parseJsonNumber('abc'), isNull);
      expect(parseJsonNumber(''), isNull);
      expect(parseJsonNumber('   '), isNull);
      expect(parseJsonNumber('12.34.56'), isNull);
      expect(parseJsonNumber('NaN'), isNull);
      expect(parseJsonNumber('Infinity'), isNull);
    });
  });

  group('jsonGet', () {
    test('retrieves root and deeply nested values', () {
      final root = _sampleRoot();
      expect(jsonGet(root, const []), same(root));
      expect(jsonGet(root, const ['name']), 'pack_alpha');
      expect(jsonGet(root, const ['version']), 1);
      expect(jsonGet(root, const ['meta', 'second']), 'b');
      expect(jsonGet(root, const ['items', 0, 'id']), 10);
      expect(jsonGet(root, const ['items', 0, 'tags', 1]), 'y');
      expect(jsonGet(root, const ['extra']), isNull);
    });

    test('throws ArgumentError on invalid paths', () {
      final root = _sampleRoot();
      expect(() => jsonGet(root, const ['missing']), throwsArgumentError);
      expect(() => jsonGet(root, const [0]), throwsArgumentError);
      expect(() => jsonGet(root, const ['items', '0']), throwsArgumentError);
      expect(() => jsonGet(root, const ['items', -1]), throwsArgumentError);
      expect(() => jsonGet(root, const ['items', 99]), throwsArgumentError);
      expect(() => jsonGet(root, const ['name', 'sub']), throwsArgumentError);
      expect(() => jsonGet(root, const ['extra', 'sub']), throwsArgumentError);
    });
  });

  group('jsonSet', () {
    test('returns value directly when path is empty', () {
      final root = _sampleRoot();
      final before = _snapshot(root);
      final replaced = jsonSet(root, const [], {'replaced': true});
      expect(replaced, {'replaced': true});
      expect(_snapshot(root), before);
    });

    test('updates map entry and preserves insertion key order', () {
      final root = _sampleRoot();
      final before = _snapshot(root);

      final updated = jsonSet(root, const ['meta', 'second'], 'B_NEW')
          as Map<String, dynamic>;

      expect(_snapshot(root), before);
      final meta = updated['meta'] as Map<String, dynamic>;
      expect(meta.keys.toList(), ['first', 'second', 'third']);
      expect(meta['second'], 'B_NEW');
      expect(identical(root['items'], updated['items']), isTrue);
    });

    test('updates list element without mutating original', () {
      final root = _sampleRoot();
      final before = _snapshot(root);

      final updated = jsonSet(root, const ['items', 1, 'tags', 0], 'z_updated');
      expect(_snapshot(root), before);
      expect(jsonGet(updated, const ['items', 1, 'tags', 0]), 'z_updated');
      expect(jsonGet(root, const ['items', 1, 'tags', 0]), 'z');
    });

    test('throws ArgumentError on invalid path or out-of-range index', () {
      final root = _sampleRoot();
      expect(() => jsonSet(root, const ['items', 5], 'x'), throwsArgumentError);
      expect(() => jsonSet(root, const ['items', -1], 'x'), throwsArgumentError);
      expect(() => jsonSet(root, const ['items', 'bad'], 'x'), throwsArgumentError);
      expect(() => jsonSet(root, const ['meta', 0], 'x'), throwsArgumentError);
      expect(() => jsonSet(root, const ['name', 'child'], 'x'), throwsArgumentError);
    });
  });

  group('jsonRemove', () {
    test('removes map key and preserves remaining key order', () {
      final root = _sampleRoot();
      final before = _snapshot(root);

      final updated =
          jsonRemove(root, const ['meta', 'second']) as Map<String, dynamic>;

      expect(_snapshot(root), before);
      final meta = updated['meta'] as Map<String, dynamic>;
      expect(meta.keys.toList(), ['first', 'third']);
      expect(meta.containsKey('second'), isFalse);
    });

    test('removes list element and shifts subsequent items', () {
      final root = _sampleRoot();
      final before = _snapshot(root);

      final updated = jsonRemove(root, const ['items', 1]);

      expect(_snapshot(root), before);
      final items = jsonGet(updated, const ['items']) as List<dynamic>;
      expect(items.length, 2);
      expect((items[0] as Map)['id'], 10);
      expect((items[1] as Map)['id'], 30);
    });

    test('throws ArgumentError on empty path or nonexistent target', () {
      final root = _sampleRoot();
      expect(() => jsonRemove(root, const []), throwsArgumentError);
      expect(() => jsonRemove(root, const ['nope']), throwsArgumentError);
      expect(() => jsonRemove(root, const ['items', 10]), throwsArgumentError);
      expect(() => jsonRemove(root, const ['items', -1]), throwsArgumentError);
      expect(() => jsonRemove(root, const ['meta', 0]), throwsArgumentError);
    });
  });

  group('jsonInsert', () {
    test('inserts new key into map preserving existing key order', () {
      final root = _sampleRoot();
      final before = _snapshot(root);

      final updated = jsonInsert(root, const ['meta'], 'fourth', 'd')
          as Map<String, dynamic>;

      expect(_snapshot(root), before);
      final meta = updated['meta'] as Map<String, dynamic>;
      expect(meta.keys.toList(), ['first', 'second', 'third', 'fourth']);
      expect(meta['fourth'], 'd');
    });

    test('throws ArgumentError when inserting existing key or non-String key into map', () {
      final root = _sampleRoot();
      expect(
        () => jsonInsert(root, const ['meta'], 'second', 'dup'),
        throwsArgumentError,
      );
      expect(
        () => jsonInsert(root, const ['meta'], null, 'bad'),
        throwsArgumentError,
      );
      expect(
        () => jsonInsert(root, const ['meta'], 1, 'bad'),
        throwsArgumentError,
      );
    });

    test('appends to list when key is null and inserts at index when key is int', () {
      final root = _sampleRoot();
      final before = _snapshot(root);

      final appended =
          jsonInsert(root, const ['items', 0, 'tags'], null, 'w');
      expect(_snapshot(root), before);
      expect(
        jsonGet(appended, const ['items', 0, 'tags']),
        ['x', 'y', 'w'],
      );

      final insertedAtStart =
          jsonInsert(appended, const ['items', 0, 'tags'], 0, 'start');
      expect(
        jsonGet(insertedAtStart, const ['items', 0, 'tags']),
        ['start', 'x', 'y', 'w'],
      );

      final insertedAtMiddle =
          jsonInsert(insertedAtStart, const ['items', 0, 'tags'], 2, 'mid');
      expect(
        jsonGet(insertedAtMiddle, const ['items', 0, 'tags']),
        ['start', 'x', 'mid', 'y', 'w'],
      );

      final insertedAtEnd =
          jsonInsert(insertedAtMiddle, const ['items', 0, 'tags'], 5, 'end');
      expect(
        jsonGet(insertedAtEnd, const ['items', 0, 'tags']),
        ['start', 'x', 'mid', 'y', 'w', 'end'],
      );
    });

    test('throws ArgumentError on invalid list index or non-container target', () {
      final root = _sampleRoot();
      expect(
        () => jsonInsert(root, const ['items', 0, 'tags'], -1, 'bad'),
        throwsArgumentError,
      );
      expect(
        () => jsonInsert(root, const ['items', 0, 'tags'], 99, 'bad'),
        throwsArgumentError,
      );
      expect(
        () => jsonInsert(root, const ['items', 0, 'tags'], 'key', 'bad'),
        throwsArgumentError,
      );
      expect(
        () => jsonInsert(root, const ['name'], 'k', 'v'),
        throwsArgumentError,
      );
    });
  });

  group('jsonRename', () {
    test('renames map key while keeping exact position in iteration order', () {
      final root = _sampleRoot();
      final before = _snapshot(root);

      final updated = jsonRename(root, const ['meta', 'second'], 'second_renamed')
          as Map<String, dynamic>;

      expect(_snapshot(root), before);
      final meta = updated['meta'] as Map<String, dynamic>;
      expect(meta.keys.toList(), ['first', 'second_renamed', 'third']);
      expect(meta['second_renamed'], 'b');
      expect(meta.containsKey('second'), isFalse);

      // Top-level key rename also keeps exact order
      final topRenamed = jsonRename(root, const ['version'], 'ver')
          as Map<String, dynamic>;
      expect(
        topRenamed.keys.toList(),
        ['name', 'ver', 'ratio', 'active', 'extra', 'meta', 'items'],
      );
      expect(topRenamed['ver'], 1);
    });

    test('throws ArgumentError if newKey already exists or path is not a map key', () {
      final root = _sampleRoot();
      expect(
        () => jsonRename(root, const ['meta', 'second'], 'third'),
        throwsArgumentError,
      );
      expect(
        () => jsonRename(root, const ['meta', 'nonexistent'], 'newKey'),
        throwsArgumentError,
      );
      expect(
        () => jsonRename(root, const ['items', 0], 'newKey'),
        throwsArgumentError,
      );
      expect(
        () => jsonRename(root, const [], 'newKey'),
        throwsArgumentError,
      );
    });
  });

  group('jsonMove', () {
    test('moves list item by delta and clamps to list bounds without mutating input', () {
      final root = _sampleRoot();
      final before = _snapshot(root);

      // Move index 0 down by 1 -> [20, 10, 30]
      final movedDown = jsonMove(root, const ['items', 0], 1);
      expect(_snapshot(root), before);
      expect(
        (jsonGet(movedDown, const ['items']) as List)
            .map((e) => (e as Map)['id'])
            .toList(),
        [20, 10, 30],
      );

      // Move index 2 up by 1 -> [10, 30, 20]
      final movedUp = jsonMove(root, const ['items', 2], -1);
      expect(
        (jsonGet(movedUp, const ['items']) as List)
            .map((e) => (e as Map)['id'])
            .toList(),
        [10, 30, 20],
      );

      // Clamp negative delta beyond 0
      final clampedStart = jsonMove(root, const ['items', 1], -100);
      expect(
        (jsonGet(clampedStart, const ['items']) as List)
            .map((e) => (e as Map)['id'])
            .toList(),
        [20, 10, 30],
      );

      // Clamp positive delta beyond length - 1
      final clampedEnd = jsonMove(root, const ['items', 0], 100);
      expect(
        (jsonGet(clampedEnd, const ['items']) as List)
            .map((e) => (e as Map)['id'])
            .toList(),
        [20, 30, 10],
      );

      // Moving index 0 by -1 stays at 0
      final stayStart = jsonMove(root, const ['items', 0], -1);
      expect(
        (jsonGet(stayStart, const ['items']) as List)
            .map((e) => (e as Map)['id'])
            .toList(),
        [10, 20, 30],
      );
    });

    test('throws ArgumentError when path does not target a valid list element', () {
      final root = _sampleRoot();
      expect(() => jsonMove(root, const [], 1), throwsArgumentError);
      expect(() => jsonMove(root, const ['meta', 'first'], 1), throwsArgumentError);
      expect(() => jsonMove(root, const ['items', -1], 1), throwsArgumentError);
      expect(() => jsonMove(root, const ['items', 3], 1), throwsArgumentError);
    });
  });
}
