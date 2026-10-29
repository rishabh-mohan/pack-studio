import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pack_studio/book_generation.dart';
import 'package:pack_studio/pack_storage.dart';

List<Map<String, dynamic>> booksOf(Map<String, dynamic> root) => [
  for (final b in root['books'] as List) b as Map<String, dynamic>,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every subject gets one book per tier E..S with the kss16 numbers', () {
    final (root, added) = ensureSubjectBooks({}, ['craft', 'design']);
    expect(added, 12);
    final books = booksOf(root);
    expect(books.map((b) => b['id']).toSet().length, 12); // unique ids
    final craft = books.where((b) => b['subject'] == 'craft').toList();
    expect(craft.map((b) => b['name']), [
      'Book E',
      'Book D',
      'Book C',
      'Book B',
      'Book A',
      'Book S',
    ]);
    expect(craft.map((b) => b['bookRank']), ['1', '2', '3', '4', '5', '6']);
    expect(craft.map((b) => b['power']), [5, 7, 10, 15, 22, 35]);
    expect(craft.map((b) => b['doneCount']), [8, 11, 13, 16, 21, 31]);
  });

  test('running it again adds nothing and changes nothing', () {
    final (first, _) = ensureSubjectBooks({}, ['craft']);
    final (second, added) = ensureSubjectBooks(first, ['craft']);
    expect(added, 0);
    expect(identical(second, first), isTrue);
  });

  test('a new subject gets only its own books; renamed and retuned books stay as they are', () {
    var (root, _) = ensureSubjectBooks({'note': 'keep me'}, ['craft']);
    final books = booksOf(root);
    books[0]['name'] = 'The Maker\'s Handbook';
    books[0]['power'] = 99;
    books[0]['myField'] = true;
    root = {...root, 'books': books};

    final (updated, added) = ensureSubjectBooks(root, ['craft', 'music']);
    expect(added, 6);
    final after = booksOf(updated);
    expect(after.length, 12);
    expect(after.first, {
      ...books[0],
    }); // untouched, including the unknown field
    expect(after.where((b) => b['subject'] == 'music').length, 6);
    expect(updated['note'], 'keep me');
    expect(after.map((b) => b['id']).toSet().length, 12);
  });

  test('new ids continue after the highest existing id, never reusing one', () {
    final start = {
      'books': [
        {
          'id': 40,
          'name': 'Mine',
          'subject': 'craft',
          'power': 1,
          'doneCount': 1,
          'bookRank': '1',
        },
      ],
    };
    final (root, added) = ensureSubjectBooks(start, ['craft']);
    expect(added, 5); // tier E already exists for craft
    expect(
      booksOf(root)
          .map((b) => b['id'])
          .where((id) => id != 40)
          .reduce((a, b) => a < b ? a : b),
      41,
    );
  });

  test(
    'removed subjects lose all their books while retained custom books survive',
    () {
      final (root, _) = ensureSubjectBooks(
        {'note': 'keep me'},
        ['craft', 'design'],
      );
      final books = booksOf(root);
      books.first['name'] = 'Custom craft book';
      books.first['power'] = 99;
      books.first['custom'] = true;
      books.last['name'] = 'Custom design book';
      final (updated, added) = ensureSubjectBooks(root, ['craft']);
      expect(added, 0);
      expect(booksOf(updated).length, 6);
      expect(
        booksOf(updated).every((book) => book['subject'] == 'craft'),
        isTrue,
      );
      expect(booksOf(updated).first, books.first);
      expect(updated['note'], 'keep me');
      expect(booksOf(root).length, 12); // input document was not mutated
      final (again, _) = ensureSubjectBooks(updated, ['craft']);
      expect(identical(again, updated), isTrue);
    },
  );

  test(
    'removing and adding subjects together does not recycle removed IDs',
    () {
      final root = {
        'books': [
          {'id': 100, 'subject': 'removed', 'bookRank': '1'},
        ],
      };
      final (updated, added) = ensureSubjectBooks(root, ['music', 'music']);
      expect(added, 6);
      expect(booksOf(updated).map((book) => book['id']), [
        101,
        102,
        103,
        104,
        105,
        106,
      ]);
      expect(
        booksOf(updated).every((book) => book['subject'] == 'music'),
        isTrue,
      );
      final (empty, count) = ensureSubjectBooks(updated, []);
      expect(count, 0);
      expect(booksOf(empty), isEmpty);
    },
  );

  test('a new pack gets its books, loads, and later subjects add only the missing ones', () async {
    final tmp = await Directory.systemTemp.createTemp('pack_studio_books');
    addTearDown(() => tmp.delete(recursive: true));
    final storage = PackStorage(
      root: '${tmp.path}/packs'.replaceAll(r'\', '/'),
    );
    final pack = await storage.createFromTemplate('Books');

    var books =
        (jsonDecode(await storage.read(pack, 'books.json')) as Map)['books']
            as List;
    expect(
      books.length,
      12,
    ); // the Workshop template has two subjects: craft and design
    expect(
      await storage.check(pack),
      isNull,
    ); // the engine loads the generated books

    // The author renames one, then adds a subject.
    final edited = (jsonDecode(
      await storage.read(pack, 'books.json'),
    ) as Map<String, dynamic>);
    (edited['books'] as List).first['name'] = 'Custom name';
    await storage.write(pack, 'books.json', jsonEncode(edited));
    final manifest = jsonDecode(
      await storage.read(pack, 'pack.json'),
    ) as Map<String, dynamic>;
    manifest['subjects'] = [...manifest['subjects'] as List, 'music'];
    await storage.write(pack, 'pack.json', jsonEncode(manifest));

    expect(await storage.ensureBooks(pack), 6);
    expect(await storage.ensureBooks(pack), 0); // repeating adds nothing
    books =
        (jsonDecode(await storage.read(pack, 'books.json')) as Map)['books']
            as List;
    expect(books.length, 18);
    expect(books.first['name'], 'Custom name'); // not overwritten
    expect(await storage.check(pack), isNull);

    // Removing a subject must write books.json even though nothing is added.
    manifest['subjects'] = ['craft', 'music'];
    await storage.write(pack, 'pack.json', jsonEncode(manifest));
    expect(await storage.ensureBooks(pack), 0);
    books =
        (jsonDecode(await storage.read(pack, 'books.json')) as Map)['books']
            as List;
    expect(books.length, 12);
    expect(books.every((book) => book['subject'] != 'design'), isTrue);
    expect(books.first['name'], 'Custom name');
    expect(await storage.check(pack), isNull);
  });
}
