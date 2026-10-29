import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_studio/home_screen.dart';
import 'package:pack_studio/theme.dart';

void main() {
  void setPhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('empty state shows title, primary actions, and empty message',
      (WidgetTester tester) async {
    setPhoneSurface(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: HomeScreen(
          onNewPack: () {},
          onOpenPack: () {},
          onSettings: () {},
          onDeleteRecent: (_) {},
          onOpenRecent: (_) {},
        ),
      ),
    );

    expect(find.text('Pack Studio'), findsOneWidget);
    expect(find.text('New pack'), findsOneWidget);
    expect(find.text('Open pack'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.text('Recent packs'), findsOneWidget);
    expect(
      find.text('No packs yet. Create or open one to get started.'),
      findsOneWidget,
    );
  });

  testWidgets('tapping New pack, Open pack, and Settings invokes callbacks',
      (WidgetTester tester) async {
    setPhoneSurface(tester);

    var newPackCalls = 0;
    var openPackCalls = 0;
    var settingsCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: HomeScreen(
          onNewPack: () => newPackCalls++,
          onOpenPack: () => openPackCalls++,
          onSettings: () => settingsCalls++,
          onDeleteRecent: (_) {},
          onOpenRecent: (_) {},
        ),
      ),
    );

    final newPackFinder = find.text('New pack');
    await tester.ensureVisible(newPackFinder);
    await tester.pumpAndSettle();
    await tester.tap(newPackFinder);
    await tester.pump();
    expect(newPackCalls, 1);

    final openPackFinder = find.text('Open pack');
    await tester.ensureVisible(openPackFinder);
    await tester.pumpAndSettle();
    await tester.tap(openPackFinder);
    await tester.pump();
    expect(openPackCalls, 1);

    final settingsFinder = find.byTooltip('Settings');
    await tester.ensureVisible(settingsFinder);
    await tester.pumpAndSettle();
    await tester.tap(settingsFinder);
    await tester.pump();
    expect(settingsCalls, 1);
  });

  testWidgets('displays recent pack and tapping it calls onOpenRecent',
      (WidgetTester tester) async {
    setPhoneSurface(tester);

    final pack = RecentPack(
      name: 'Lantern',
      path: 'C:/packs/lantern',
      lastOpened: DateTime.now(),
    );
    RecentPack? openedPack;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: HomeScreen(
          onNewPack: () {},
          onOpenPack: () {},
          onSettings: () {},
          onDeleteRecent: (_) {},
          onOpenRecent: (recent) => openedPack = recent,
          recent: [pack],
        ),
      ),
    );

    final lanternFinder = find.text('Lantern');
    expect(lanternFinder, findsOneWidget);
    expect(
      find.text('No packs yet. Create or open one to get started.'),
      findsNothing,
    );

    await tester.ensureVisible(lanternFinder);
    await tester.pumpAndSettle();
    await tester.tap(lanternFinder);
    await tester.pump();

    expect(openedPack, same(pack));
  });
}
