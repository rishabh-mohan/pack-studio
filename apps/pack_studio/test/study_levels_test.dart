import 'dart:convert';
import 'dart:io';

import 'package:d30_engine/d30_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_studio/pack_storage.dart';
import 'package:pack_studio/study_levels.dart';

Map<String, String> workshopFiles() {
  final dir = Directory('assets/workshop');
  return {
    for (final f in dir.listSync(recursive: true).whereType<File>())
      f.path.substring(dir.path.length + 1).replaceAll(r'\', '/'): f.readAsStringSync(),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a new pack has ten student levels, each +1 study efficiency over the last', () {
    final pack = ContentPack.fromFiles(workshopFiles());
    final tiers = pack.studyLevels.tiers;
    expect(tiers.map((t) => t.level), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    expect([for (var i = 1; i < tiers.length; i++) tiers[i].plusStat - tiers[i - 1].plusStat], everyElement(1));
    expect(tiers.first.plusStat, 0);
    expect(tiers.map((t) => t.exp).toList(), orderedEquals([...tiers.map((t) => t.exp)]..sort()));
    expect(tiers.map((t) => t.exp).toSet().length, 10); // strictly rising
    expect(tiers.every((t) => t.name.isNotEmpty), isTrue);
    expect(pack.studyLevels.maxLevel, 10);
  });

  test('the level box has something to show: LV 1 at the start, a real next threshold', () {
    final pack = ContentPack.fromFiles(workshopFiles());
    expect(pack.studyLevels.tierFor(0).level, 1);
    expect(pack.studyLevels.nextThresholdAfter(0), 500);
    expect(pack.studyLevels.tierFor(500).level, 2);
    expect(pack.studyLevels.tierFor(23000).level, 10);
    expect(pack.studyLevels.nextThresholdAfter(23000), isNull); // the top
  });

  test('the template file and the fixture agree, and match the generated default', () {
    final template = jsonDecode(File('assets/workshop/levels.json').readAsStringSync());
    final fixture = jsonDecode(File('../../fixtures/workshop/levels.json').readAsStringSync());
    expect(template, fixture);
    expect(template['study'], defaultStudyLevels());
  });

  test('a levels document with no study table gets one; others are left as they are', () {
    final (added, changed) = ensureStudyLevels({'exercise': [{'level': 1}]});
    expect(changed, isTrue);
    expect(added['study'], defaultStudyLevels());
    expect(added['exercise'], [{'level': 1}]); // another table is kept

    final own = {'study': [{'level': 1, 'name': 'Mine', 'exp': 0, 'plusStat': 0}]};
    final (same, changedAgain) = ensureStudyLevels(own);
    expect(changedAgain, isFalse);
    expect(identical(same, own), isTrue);

    final (keyed, changedKeyed) = ensureStudyLevels({'study': {'levels': [{'level': 1}]}});
    expect(changedKeyed, isFalse);
    expect(keyed['study'], isA<Map>());
    expect(ensureStudyLevels({'study': <Object>[]}).$2, isTrue); // an empty table is no table
  });

  test('opening an older pack with no levels.json writes the default; a second time changes nothing', () async {
    final tmp = await Directory.systemTemp.createTemp('pack_studio_levels');
    addTearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } on FileSystemException {
        // The temp folder is disposable.
      }
    });
    final storage = PackStorage(root: '${tmp.path}/packs'.replaceAll(r'\', '/'));
    final pack = await storage.createFromTemplate('Older pack');
    File('${pack.path}/levels.json').deleteSync(); // as packs made before the table existed
    expect(await storage.ensureStudyLevels(pack), isTrue);
    final written = jsonDecode(await storage.read(pack, 'levels.json')) as Map;
    expect(written['study'], defaultStudyLevels());
    final before = await storage.read(pack, 'levels.json');
    expect(await storage.ensureStudyLevels(pack), isFalse);
    expect(await storage.read(pack, 'levels.json'), before);
    expect(await storage.check(pack), isNull); // the pack still loads
  });
}
