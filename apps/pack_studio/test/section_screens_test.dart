import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_studio/pack_storage.dart';
import 'package:pack_studio/schema.dart';
import 'package:pack_studio/section_screens.dart';
import 'package:pack_studio/theme.dart';

/// Real file IO needs real time; the widgets need pumps to see each result.
Future<void> settleIo(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump();
  }
}

void main() {
  testWidgets('Locations shows each place as a button; adding one is saved to the file', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late Directory tmp;
    late PackStorage storage;
    late PackEntry pack;
    await tester.runAsync(() async {
      tmp = await Directory.systemTemp.createTemp('pack_studio_ui');
      storage = PackStorage(root: '${tmp.path}/packs'.replaceAll(r'\', '/'));
      pack = await storage.createFromTemplate('UI test');
    });
    addTearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows may still hold a file for a moment; the temp folder is disposable.
      }
    });

    final locations = packSections.firstWhere((s) => s.label == 'Locations');
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: SectionListScreen(pack: pack, storage: storage, section: locations),
    ));
    await settleIo(tester);
    await tester.pumpAndSettle(); // let the add button finish appearing

    expect(find.text('Workshop'), findsOneWidget);
    expect(find.text('2 actions'), findsOneWidget);
    expect(find.byKey(const ValueKey('entry:0')), findsOneWidget);

    await tester.tap(find.text('Add location'));
    await tester.pumpAndSettle();
    expect(find.text('New location'), findsWidgets); // the editor for the new place
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('entry:1')), findsOneWidget);

    await tester.pump(const Duration(seconds: 1)); // the save fires shortly after an edit
    await settleIo(tester);
    final saved = await tester.runAsync(() => storage.read(pack, 'locations.json'));
    final list = (jsonDecode(saved!) as Map)['locations'] as List;
    expect(list.length, 2);
    expect((list.last as Map)['id'], 802);
    expect((list.last as Map)['name'], 'New location');
  });
}
