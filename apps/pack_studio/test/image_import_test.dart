import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_studio/image_field.dart';
import 'package:pack_studio/pack_storage.dart';
import 'package:pack_studio/record_form.dart';
import 'package:pack_studio/schema.dart';
import 'package:pack_studio/theme.dart';

// A real 1x1 PNG.
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('importing a picture into a pack', () {
    late Directory tmp;
    late PackStorage storage;
    late PackEntry pack;
    late File source;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('pack_studio_img');
      storage = PackStorage(root: '${tmp.path}/packs'.replaceAll(r'\', '/'));
      pack = await storage.createFromTemplate('Pics');
      source = File('${tmp.path}/My Hero!!.PNG')..writeAsBytesSync(_png);
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    test('copies into images/<folder> with a portable name and a pack-relative path', () async {
      final path = await storage.importImage(pack, source.path, 'characters');
      expect(path, 'characters/my-hero.png');
      expect(File('${pack.path}/images/$path').readAsBytesSync(), _png);
      expect(source.existsSync(), isTrue); // the original is left alone
    });

    test('a duplicate name never overwrites the first picture', () async {
      final first = await storage.importImage(pack, source.path, 'characters');
      final second = await storage.importImage(pack, source.path, 'characters');
      final third = await storage.importImage(pack, source.path, 'characters');
      expect([first, second, third], ['characters/my-hero.png', 'characters/my-hero-2.png', 'characters/my-hero-3.png']);
    });

    test('files that are not pictures, or are missing, are refused in plain words', () async {
      final notes = File('${tmp.path}/notes.txt')..writeAsStringSync('hi');
      await expectLater(
        storage.importImage(pack, notes.path, 'characters'),
        throwsA(isA<PackStorageException>().having((e) => e.message, 'message', contains('PNG, JPG or WebP'))),
      );
      await expectLater(
        storage.importImage(pack, '${tmp.path}/gone.png', 'characters'),
        throwsA(isA<PackStorageException>().having((e) => e.message, 'message', contains('could not be found'))),
      );
      expect(Directory('${pack.path}/images/characters').existsSync(), isFalse); // nothing half-copied
    });

    test('the stored path is what d30mode resolves (images/<path>), and the pack still loads', () async {
      final path = await storage.importImage(pack, source.path, 'backgrounds');
      expect(path.startsWith('backgrounds/'), isTrue);
      expect(await storage.check(pack), isNull);
    });
  });

  group('the picture field', () {
    Future<void> pump(WidgetTester tester, Map<String, dynamic> record, ImageTools tools, ValueChanged<Map<String, dynamic>> onRecord) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      var value = record;
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: ImageToolsScope(
                tools: tools,
                child: RecordForm(
                  spec: characterRecord,
                  value: value,
                  onChanged: (r) {
                    setState(() => value = r);
                    onRecord(r);
                  },
                  openJson: (title, v) async => null,
                ),
              ),
            ),
          ),
        ),
      ));
    }

    testWidgets('choose stores the imported path; replace and remove work', (tester) async {
      Map<String, dynamic>? latest;
      final picks = <String>['characters/a.png', 'characters/b.png'];
      final tools = ImageTools(packPath: '/nowhere', pick: (folder) async {
        expect(folder, 'characters'); // portraits go in images/characters
        return picks.removeAt(0);
      });
      await pump(tester, {'id': 1, 'name': 'Ann'}, tools, (r) => latest = r);

      expect(find.text('Choose picture'), findsOneWidget);
      expect(find.byKey(const ValueKey('preview:portrait')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('choose:portrait')));
      await tester.pumpAndSettle();
      expect(latest!['portrait'], 'characters/a.png');
      expect(find.byKey(const ValueKey('preview:portrait')), findsOneWidget);

      expect(find.text('Replace picture'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('choose:portrait')));
      await tester.pumpAndSettle();
      expect(latest!['portrait'], 'characters/b.png');

      await tester.tap(find.byKey(const ValueKey('clear:portrait')));
      await tester.pumpAndSettle();
      expect(latest!.containsKey('portrait'), isFalse);
      expect(latest!['name'], 'Ann'); // nothing else touched
    });

    testWidgets('cancelling the picker changes nothing; a failed import explains why', (tester) async {
      Map<String, dynamic>? latest;
      var cancel = true;
      final tools = ImageTools(packPath: '/nowhere', pick: (folder) async {
        if (cancel) return null;
        throw PackStorageException('Choose a PNG, JPG or WebP picture. "a.txt" is not one of those.');
      });
      await pump(tester, {'id': 1, 'name': 'Ann', 'portrait': 'characters/keep.png'}, tools, (r) => latest = r);

      await tester.tap(find.byKey(const ValueKey('choose:portrait')));
      await tester.pumpAndSettle();
      expect(latest, isNull); // cancelled: no change at all

      cancel = false;
      await tester.tap(find.byKey(const ValueKey('choose:portrait')));
      await tester.pumpAndSettle();
      expect(find.textContaining('PNG, JPG or WebP'), findsOneWidget);
      expect(latest, isNull); // the old picture is kept
    });

    testWidgets('a picture file that is missing is flagged in the preview, not hidden', (tester) async {
      final tools = ImageTools(packPath: '/definitely/not/here', pick: (folder) async => null);
      await pump(tester, {'id': 1, 'name': 'Ann', 'portrait': 'characters/gone.png'}, tools, (_) {});
      for (var i = 0; i < 4; i++) {
        // The load failure comes back through real file IO.
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
        await tester.pump();
      }
      expect(find.textContaining('Picture not found'), findsOneWidget);
    });
  });
}
