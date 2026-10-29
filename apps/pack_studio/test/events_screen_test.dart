import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_studio/base_events.dart';
import 'package:pack_studio/events_screen.dart';
import 'package:pack_studio/own_events.dart';
import 'package:pack_studio/pack_storage.dart';
import 'package:pack_studio/theme.dart';

/// Real file IO needs real time; the widgets need pumps to see each result.
Future<void> settleIo(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// Waits (in real time, up to ~6 s) for [finder] to show up.
Future<void> settleUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  testWidgets('make an event with the form: it is saved, listed and reopens', (tester) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late Directory tmp;
    late PackStorage storage;
    late PackEntry pack;
    await tester.runAsync(() async {
      tmp = await Directory.systemTemp.createTemp('pack_studio_events');
      storage = PackStorage(root: '${tmp.path}/packs'.replaceAll(r'\', '/'));
      pack = await storage.createFromTemplate('Events test');
    });
    addTearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } on FileSystemException {
        // The temp folder is disposable.
      }
    });

    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: EventsScreen(pack: pack, storage: storage)));
    await settleIo(tester);
    expect(find.text('Your events'), findsOneWidget);
    expect(find.textContaining('Nothing here yet'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('new-event')));
    await tester.pump(const Duration(milliseconds: 500));
    await settleUntil(tester, find.byKey(const ValueKey('event-name')));

    await tester.enterText(find.byKey(const ValueKey('event-name')), 'The lost wallet');
    await tester.enterText(find.byType(TextFormField).at(1), 'Is this yours?');
    await tester.tap(find.byKey(const ValueKey('add-reward')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('event-save')));
    await settleUntil(tester, find.textContaining('Saved'));

    final saved = await tester.runAsync(() => storage.read(pack, 'events/events.json'));
    final doc = jsonDecode(saved!) as Map<String, dynamic>;
    final event = (doc['events'] as List).single as Map<String, dynamic>;
    expect(event['name'], 'The lost wallet');
    expect(isOwnEvent(event), isTrue);
    expect(event['isRandomDate'], isTrue);
    expect((doc['nodes'] as List).length, 3); // a line, a reward, the close

    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 500));
    await settleIo(tester);
    await settleUntil(tester, find.text('Any day · 2 steps'));
    expect(find.text('The lost wallet'), findsOneWidget);
    expect(find.text('Any day · 2 steps'), findsOneWidget);

    await tester.tap(find.text('The lost wallet'));
    await tester.pump(const Duration(milliseconds: 500));
    await settleUntil(tester, find.text('Edit event'));
    await settleIo(tester);
    expect(find.text('Edit event'), findsOneWidget);
    expect(find.text('Is this yours?'), findsOneWidget);
  });

  testWidgets('an empty form says what is missing instead of saving', (tester) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late Directory tmp;
    late PackStorage storage;
    late PackEntry pack;
    await tester.runAsync(() async {
      tmp = await Directory.systemTemp.createTemp('pack_studio_events');
      storage = PackStorage(root: '${tmp.path}/packs'.replaceAll(r'\', '/'));
      pack = await storage.createFromTemplate('Events test');
    });
    addTearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } on FileSystemException {
        // The temp folder is disposable.
      }
    });

    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: EventsScreen(pack: pack, storage: storage)));
    await settleIo(tester);
    await tester.tap(find.byKey(const ValueKey('new-event')));
    await tester.pump(const Duration(milliseconds: 500));
    await settleUntil(tester, find.byKey(const ValueKey('event-name')));
    await tester.tap(find.byKey(const ValueKey('event-save')));
    await tester.pump();
    expect(find.text('Give the event a name.'), findsOneWidget);
    final saved = await tester.runAsync(() => storage.read(pack, 'events/events.json'));
    expect((jsonDecode(saved!) as Map)['events'], isEmpty);
  });

  // The catalog is local, gitignored KSS content: without it the dropdown is
  // not offered, and this test has nothing to try.
  final hasCatalog = File('assets/kss16_events/catalog.json').existsSync();
  testWidgets('the base-game dropdown ticks a chain in whole', (tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late Directory tmp;
    late PackStorage storage;
    late PackEntry pack;
    await tester.runAsync(() async {
      tmp = await Directory.systemTemp.createTemp('pack_studio_events');
      storage = PackStorage(root: '${tmp.path}/packs'.replaceAll(r'\', '/'));
      pack = await storage.createFromTemplate('Events test');
    });
    addTearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } on FileSystemException {
        // The temp folder is disposable.
      }
    });

    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: EventsScreen(pack: pack, storage: storage)));
    await settleUntil(tester, find.text('Base-game events'));
    expect(find.text('Base-game events'), findsOneWidget);
    expect(find.byKey(const ValueKey('base-events-search')), findsNothing); // collapsed

    await tester.tap(find.text('Base-game events'));
    await tester.pump(const Duration(milliseconds: 500));
    await settleUntil(tester, find.byKey(const ValueKey('base-events-search')));
    await tester.enterText(find.byKey(const ValueKey('base-events-search')), 'Beggar Begging');
    await tester.pump(const Duration(milliseconds: 300));
    final group = find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('base-event-group:'));
    expect(group, findsOneWidget);
    await tester.tap(group);
    await tester.pump();
    expect(find.textContaining('(4 events)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('base-events-add')));
    await settleIo(tester);

    final saved = await tester.runAsync(() => storage.read(pack, 'events/events.json'));
    final events = ((jsonDecode(saved!) as Map)['events'] as List).cast<Map<String, dynamic>>();
    expect(events.length, 4);
    expect(events.every((e) => e[baseEventIdKey] != null), isTrue);
    await settleUntil(tester, find.text('Already in this pack'));
    expect(find.text('Already in this pack'), findsOneWidget);
    await settleUntil(tester, find.text('4 other events'));
    expect(find.text('4 other events'), findsOneWidget);
  }, skip: !hasCatalog);
}
