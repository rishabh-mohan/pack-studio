import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pack_studio/pack_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('packIdFromName gives a d30mode-safe directory name', () {
    expect(packIdFromName('My Lantern Pack!'), 'my-lantern-pack');
    expect(packIdFromName('  Café 2024  '), 'caf-2024');
    expect(packIdFromName('???'), 'pack');
    expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(packIdFromName('a b_c-d')), isTrue);
  });

  test('templatePackJson sets id and name and keeps the rest', () {
    const source = '{"id":"workshop","name":"Workshop example","subjects":["craft"],"start":{"locationId":801}}';
    final out = jsonDecode(templatePackJson(source, id: 'lantern', name: 'Lantern')) as Map<String, dynamic>;
    expect(out['id'], 'lantern');
    expect(out['name'], 'Lantern');
    expect(out['subjects'], ['craft']);
    expect(out['start'], {'locationId': 801});
  });

  test('createFromTemplate writes the Workshop pack and list() finds it', () async {
    final tmp = await Directory.systemTemp.createTemp('pack_studio_test');
    addTearDown(() => tmp.delete(recursive: true));
    final storage = PackStorage(root: '${tmp.path}/packs'.replaceAll(r'\', '/'));

    expect(await storage.list(), isEmpty); // root does not exist yet

    final first = await storage.createFromTemplate('My Lantern');
    expect(first.id, 'my-lantern');
    expect(first.name, 'My Lantern');
    final manifest = jsonDecode(await storage.read(first, 'pack.json')) as Map<String, dynamic>;
    expect(manifest['id'], 'my-lantern');
    expect(await storage.files(first), containsAll(['pack.json', 'rules.json', 'events/events.json']));

    final second = await storage.createFromTemplate('My Lantern'); // same name: new id
    expect(second.id, 'my-lantern-2');
    expect((await storage.list()).map((p) => p.id), unorderedEquals(['my-lantern', 'my-lantern-2']));

    final reserved = await storage.createFromTemplate('KSS16'); // d30mode's bundled id is off limits
    expect(reserved.id, 'kss16-2');
  });

  test('check loads the Workshop pack and reports a broken file; write and missingFiles work', () async {
    final tmp = await Directory.systemTemp.createTemp('pack_studio_check');
    addTearDown(() => tmp.delete(recursive: true));
    final storage = PackStorage(root: '${tmp.path}/packs'.replaceAll(r'\', '/'));
    final pack = await storage.createFromTemplate('Checked');

    expect(await storage.check(pack), isNull);
    expect(await storage.missingFiles(pack), contains('items.json'));
    expect(await storage.missingFiles(pack), isNot(contains('rules.json')));

    await storage.write(pack, 'rules.json', '[1, 2, 3]'); // valid JSON, wrong shape
    expect(await storage.check(pack), isNotNull);

    await storage.write(pack, 'items.json', '{}\n');
    expect(await storage.missingFiles(pack), isNot(contains('items.json')));
  });
}
